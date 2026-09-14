import CoreLocation
import Foundation

struct WidgetRoutePinTarget: Sendable {
    let stopID: String
    let stopName: String
    let sequence: Int
    let etas: [Eta]
}

/// Resolves a route pin to the stop nearest the device, then fetches that
/// stop's current arrivals before the widget snapshot is written.
@MainActor
enum WidgetRoutePinService {
    static func resolve(
        item: RegionalFavoriteRoute,
        app: AppState,
        language: AppLanguage
    ) async -> WidgetRoutePinTarget? {
        guard let region = RegionCatalog.region(for: item.regionID) else { return nil }
        let recent = app.bookmarks.recentRoute(
            routeKey: item.favorite.routeKey,
            regionID: item.regionID
        )
        let deviceLocation = await currentLocation(from: app.location)

        if region.isQueryMode {
            return await resolveMainland(
                item: item,
                region: region,
                recent: recent,
                deviceLocation: deviceLocation,
                app: app,
                language: language
            )
        }
        return await resolveStaticRegion(
            item: item,
            region: region,
            recent: recent,
            deviceLocation: deviceLocation,
            app: app,
            language: language
        )
    }

    private static func resolveStaticRegion(
        item: RegionalFavoriteRoute,
        region: TransitRegion,
        recent: RecentRoute?,
        deviceLocation: CLLocation?,
        app: AppState,
        language: AppLanguage
    ) async -> WidgetRoutePinTarget? {
        let provider: any TransitProvider
        let data: DataStore
        if region.id == app.region.id {
            provider = app.provider
            data = app.data
        } else {
            provider = RegionCatalog.provider(for: region)
            data = DataStore(provider: provider)
        }
        await waitForData(data)
        guard let entry = data.entry(item.favorite.routeKey), let db = data.db,
              let selected = selectStop(
                stopIDs: entry.canonicalStops,
                stop: data.stop,
                deviceLocation: deviceLocation,
                recent: recent,
                language: language
              ) else {
            return nil
        }
        let etas = await provider.fetchEtas(
            entry: entry,
            seq: selected.sequence,
            db: db,
            language: language
        )
        return WidgetRoutePinTarget(
            stopID: selected.stopID,
            stopName: selected.stopName,
            sequence: selected.sequence,
            etas: etas
        )
    }

    private static func resolveMainland(
        item: RegionalFavoriteRoute,
        region: TransitRegion,
        recent: RecentRoute?,
        deviceLocation: CLLocation?,
        app: AppState,
        language: AppLanguage
    ) async -> WidgetRoutePinTarget? {
        let provider: (any MainlandTransitProvider)?
        if region.id == app.region.id {
            provider = app.mainlandProvider
        } else {
            provider = RegionCatalog.provider(for: region) as? any MainlandTransitProvider
        }
        guard let provider, let lineID = item.favorite.lineID, !lineID.isEmpty else {
            return fallback(recent, language: language)
        }
        do {
            guard let payload = try await provider.linePayload(
                lineID: lineID,
                modeHint: item.favorite.modeRawValue.flatMap { MainlandTransitMode(rawValue: $0) }
            ), let shared = MainlandRouteAdapter.makeSharedRoute(from: payload),
            let selected = selectStop(
                stopIDs: shared.entry.canonicalStops,
                stop: { shared.stops[$0] },
                deviceLocation: deviceLocation,
                recent: recent,
                language: language
            ) else {
                return fallback(recent, language: language)
            }

            if region.id == app.region.id {
                app.data.registerSynthetic(
                    entry: shared.entry,
                    stops: shared.stops,
                    mainlandMetadata: shared.metadata
                )
            }
            let stopLocation = shared.stops[selected.stopID]?.location
            let etas: [Eta]
            if MainlandRealtimePolicy.allowsRequest(modeHint: shared.metadata.mode) {
                etas = try await provider.fetchEtas(
                    lineID: lineID,
                    stopID: selected.stopID,
                    stopSequence: selected.sequence,
                    latitude: stopLocation?.coordinateSystem == .wgs84 ? stopLocation?.lat : nil,
                    longitude: stopLocation?.coordinateSystem == .wgs84 ? stopLocation?.lng : nil,
                    source: shared.metadata.source,
                    language: language,
                    modeHint: shared.metadata.mode
                )
            } else {
                etas = []
            }
            return WidgetRoutePinTarget(
                stopID: selected.stopID,
                stopName: selected.stopName,
                sequence: selected.sequence,
                etas: etas
            )
        } catch {
            return fallback(recent, language: language)
        }
    }

    private static func selectStop(
        stopIDs: [String],
        stop: (String) -> StopEntry?,
        deviceLocation: CLLocation?,
        recent: RecentRoute?,
        language: AppLanguage
    ) -> (stopID: String, stopName: String, sequence: Int)? {
        if let deviceLocation {
            let nearest = stopIDs.enumerated().compactMap { sequence, stopID -> (Int, String, StopEntry, CLLocationDistance)? in
                guard let entry = stop(stopID), entry.location.isValid else { return nil }
                let location = CLLocation(latitude: entry.location.lat, longitude: entry.location.lng)
                return (sequence, stopID, entry, deviceLocation.distance(from: location))
            }
            .min { $0.3 < $1.3 }
            if let nearest {
                return (nearest.1, nearest.2.name.name(language), nearest.0)
            }
        }
        if let recent, recent.seq >= 0, recent.seq < stopIDs.count {
            let stopID = stopIDs[recent.seq]
            let name = stop(stopID)?.name.name(language)
                ?? (language.isChinese ? recent.stopNameZh : recent.stopNameEn)
            return (stopID, name, recent.seq)
        }
        return nil
    }

    private static func fallback(
        _ recent: RecentRoute?,
        language: AppLanguage
    ) -> WidgetRoutePinTarget? {
        guard let recent else { return nil }
        return WidgetRoutePinTarget(
            stopID: recent.stopId,
            stopName: language.isChinese
                ? (recent.stopNameZh.isEmpty ? recent.stopNameEn : recent.stopNameZh)
                : (recent.stopNameEn.isEmpty ? recent.stopNameZh : recent.stopNameEn),
            sequence: recent.seq,
            etas: []
        )
    }

    private static func waitForData(_ data: DataStore) async {
        await data.load()
        for _ in 0..<40 where data.db == nil && data.isLoading {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private static func currentLocation(from service: LocationService) async -> CLLocation? {
        if let location = service.location { return location }
        if service.isDenied { return nil }
        if service.authorizationStatus == .notDetermined {
            service.requestAuthorization()
        } else {
            service.startUpdating()
        }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(250))
            if let location = service.location { return location }
            if service.isDenied { return nil }
        }
        return service.location
    }
}
