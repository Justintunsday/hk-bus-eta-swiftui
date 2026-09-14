import Foundation
import WidgetKit

/// Bridges the app's favorites / ETA refreshes into the shared widget
/// snapshot. Reads are cheap and always come from the App Group container.
@MainActor
enum WidgetSnapshotUpdater {
    static let maxItems = 3

    static func isPinned(id: String) -> Bool {
        WidgetSharedStore.load().items.contains { $0.id == id }
    }

    static func routePinID(regionID: String, routeKey: String) -> String {
        "route:\(regionID):\(routeKey)"
    }

    static func stopPinID(regionID: String, stopID: String) -> String {
        "stop:\(regionID):\(stopID)"
    }

    // MARK: Pinning

    static func toggleRoutePin(
        regionID: String,
        favorite: FavoriteRoute,
        target: WidgetRoutePinTarget?,
        language: AppLanguage
    ) {
        var snapshot = WidgetSharedStore.load()
        let id = routePinID(regionID: regionID, routeKey: favorite.routeKey)
        if let index = snapshot.items.firstIndex(where: { $0.id == id }) {
            snapshot.items.remove(at: index)
        } else {
            append(
                WidgetPinnedItem(
                    id: id,
                    kind: .route,
                    regionID: regionID,
                    regionName: RegionCatalog.region(for: regionID)?.name,
                    title: favorite.route,
                    origin: localized(favorite.origZh, favorite.origEn, language),
                    destination: localized(favorite.destZh, favorite.destEn, language),
                    arrivalLabel: target?.stopName,
                    lineID: favorite.lineID,
                    stopID: target?.stopID,
                    targetSequence: target?.sequence,
                    modeRawValue: favorite.modeRawValue,
                    etas: Array((target?.etas ?? []).compactMap(\.date).prefix(3)),
                    updatedAt: target == nil ? nil : Date()
                ),
                to: &snapshot
            )
        }
        snapshot.updatedAt = Date()
        WidgetSharedStore.save(snapshot)
        reload()
    }

    static func toggleStopPin(regionID: String, favorite: FavoriteStop, language: AppLanguage) {
        var snapshot = WidgetSharedStore.load()
        let id = stopPinID(regionID: regionID, stopID: favorite.id)
        if let index = snapshot.items.firstIndex(where: { $0.id == id }) {
            snapshot.items.remove(at: index)
        } else {
            append(
                WidgetPinnedItem(
                    id: id,
                    kind: .stop,
                    regionID: regionID,
                    regionName: RegionCatalog.region(for: regionID)?.name,
                    title: localized(favorite.nameZh, favorite.nameEn, language),
                    origin: "",
                    destination: "",
                    arrivalLabel: nil,
                    lineID: nil,
                    stopID: favorite.id,
                    targetSequence: nil,
                    modeRawValue: nil,
                    etas: [],
                    updatedAt: nil
                ),
                to: &snapshot
            )
        }
        snapshot.updatedAt = Date()
        WidgetSharedStore.save(snapshot)
        reload()
    }

    // MARK: Arrival refreshes

    /// No-op unless this route is pinned. Called from the ETA screens so the
    /// widget always carries the latest arrivals the app has seen.
    static func updateRoute(
        regionID: String,
        routeKey: String,
        stopID: String?,
        seq: Int?,
        etas: [Eta]
    ) {
        var snapshot = WidgetSharedStore.load()
        let id = routePinID(regionID: regionID, routeKey: routeKey)
        guard let index = snapshot.items.firstIndex(where: { $0.id == id }) else { return }
        if let pinnedStopID = snapshot.items[index].stopID,
           let stopID, pinnedStopID != stopID {
            return
        }
        snapshot.items[index].etas = Array(etas.compactMap(\.date).prefix(3))
        snapshot.items[index].updatedAt = Date()
        if let stopID { snapshot.items[index].stopID = stopID }
        if let seq { snapshot.items[index].targetSequence = seq }
        snapshot.updatedAt = Date()
        WidgetSharedStore.save(snapshot)
        reload()
    }

    static func updateStop(
        regionID: String,
        stopID: String,
        arrivalLabel: String?,
        etas: [Date]
    ) {
        var snapshot = WidgetSharedStore.load()
        let id = stopPinID(regionID: regionID, stopID: stopID)
        guard let index = snapshot.items.firstIndex(where: { $0.id == id }) else { return }
        snapshot.items[index].etas = Array(etas.sorted().prefix(3))
        snapshot.items[index].arrivalLabel = arrivalLabel
        snapshot.items[index].updatedAt = Date()
        snapshot.updatedAt = Date()
        WidgetSharedStore.save(snapshot)
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.widgetKind)
    }

    private static func append(_ item: WidgetPinnedItem, to snapshot: inout WidgetSnapshot) {
        snapshot.items.append(item)
        if snapshot.items.count > maxItems {
            snapshot.items.removeFirst(snapshot.items.count - maxItems)
        }
    }

    private static func localized(_ zh: String, _ en: String, _ language: AppLanguage) -> String {
        if language.isChinese {
            return zh.isEmpty ? en : zh
        }
        return en.isEmpty ? zh : en
    }
}
