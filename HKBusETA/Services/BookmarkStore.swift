import Foundation
import Observation
import SwiftUI

struct FavoriteRoute: Codable, Identifiable, Hashable, Sendable {
    var id: String { routeKey }
    let routeKey: String
    let route: String
    let serviceType: String
    let co: [String]
    let origZh: String
    let origEn: String
    let destZh: String
    let destEn: String
    let createdAt: Date
    /// Query-mode mainland routes are recreated after launch from this ID.
    let lineID: String?
    let modeRawValue: String?

    init(
        routeKey: String,
        route: String,
        serviceType: String,
        co: [String],
        origZh: String,
        origEn: String,
        destZh: String,
        destEn: String,
        createdAt: Date,
        lineID: String? = nil,
        modeRawValue: String? = nil
    ) {
        self.routeKey = routeKey
        self.route = route
        self.serviceType = serviceType
        self.co = co
        self.origZh = origZh
        self.origEn = origEn
        self.destZh = destZh
        self.destEn = destEn
        self.createdAt = createdAt
        self.lineID = lineID
        self.modeRawValue = modeRawValue
    }
}

struct FavoriteStop: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let nameZh: String
    let nameEn: String
    let lat: Double
    let lng: Double
    let createdAt: Date
}

struct RecentRoute: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(routeKey)#\(seq)" }
    let routeKey: String
    let route: String
    let co: [String]
    let origZh: String
    let origEn: String
    let destZh: String
    let destEn: String
    let stopId: String
    let seq: Int
    let stopNameZh: String
    let stopNameEn: String
    let viewedAt: Date
    let lineID: String?
    let modeRawValue: String?

    init(
        routeKey: String,
        route: String,
        co: [String],
        origZh: String,
        origEn: String,
        destZh: String,
        destEn: String,
        stopId: String,
        seq: Int,
        stopNameZh: String,
        stopNameEn: String,
        viewedAt: Date,
        lineID: String? = nil,
        modeRawValue: String? = nil
    ) {
        self.routeKey = routeKey
        self.route = route
        self.co = co
        self.origZh = origZh
        self.origEn = origEn
        self.destZh = destZh
        self.destEn = destEn
        self.stopId = stopId
        self.seq = seq
        self.stopNameZh = stopNameZh
        self.stopNameEn = stopNameEn
        self.viewedAt = viewedAt
        self.lineID = lineID
        self.modeRawValue = modeRawValue
    }
}

struct RecentStop: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let nameZh: String
    let nameEn: String
    let lat: Double
    let lng: Double
    let viewedAt: Date
}

struct RegionalFavoriteRoute: Identifiable, Hashable, Sendable {
    var id: String { "\(regionID)#\(favorite.routeKey)" }
    let regionID: String
    let favorite: FavoriteRoute
}

struct RegionalFavoriteStop: Identifiable, Hashable, Sendable {
    var id: String { "\(regionID)#\(favorite.id)" }
    let regionID: String
    let favorite: FavoriteStop
}

@MainActor
@Observable
final class BookmarkStore {
    private static let legacyRegionID = "hk"

    /// Region namespace currently exposed to the UI. Region IDs come from
    /// TransitRegion.id (for example hk, cl-014, cl-040).
    private(set) var activeRegionID: String
    private var regions: [String: RegionPayload] = [:]

    var favoriteRoutes: [FavoriteRoute] { current.favoriteRoutes }
    var favoriteStops: [FavoriteStop] { current.favoriteStops }
    var recentRoutes: [RecentRoute] { current.recentRoutes }
    var recentStops: [RecentStop] { current.recentStops }

    func recentRoute(routeKey: String, regionID: String) -> RecentRoute? {
        regions[regionID]?.recentRoutes.first { $0.routeKey == routeKey }
    }

    /// Favorites are displayed globally while writes and identity checks stay
    /// isolated in their original transit-region namespace.
    var allFavoriteRoutes: [RegionalFavoriteRoute] {
        regions.flatMap { regionID, payload in
            payload.favoriteRoutes.map { RegionalFavoriteRoute(regionID: regionID, favorite: $0) }
        }
        .sorted { $0.favorite.createdAt > $1.favorite.createdAt }
    }

    var allFavoriteStops: [RegionalFavoriteStop] {
        regions.flatMap { regionID, payload in
            payload.favoriteStops.map { RegionalFavoriteStop(regionID: regionID, favorite: $0) }
        }
        .sorted { $0.favorite.createdAt > $1.favorite.createdAt }
    }

    private let maxRecent = 50

    private let storageURL: URL

    private static var defaultStorageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("HKBusETA", isDirectory: true).appendingPathComponent("bookmarks.json")
    }

    private var current: RegionPayload {
        regions[activeRegionID] ?? RegionPayload()
    }

    init(regionID: String, storageURL: URL? = nil) {
        activeRegionID = regionID
        self.storageURL = storageURL ?? Self.defaultStorageURL
        load()
    }

    /// Switches the visible and writable namespace with the selected region.
    /// No records are copied between transit systems.
    func selectRegion(_ regionID: String) {
        guard !regionID.isEmpty, regionID != activeRegionID else { return }
        activeRegionID = regionID
    }

    // MARK: - Favorites

    func isFavoriteRoute(_ routeKey: String) -> Bool {
        current.favoriteRoutes.contains { $0.routeKey == routeKey }
    }

    func toggleFavoriteRoute(entry: RouteEntry, routeKey: String, modeRawValue: String? = nil) {
        updateCurrent { bucket in
            if let index = bucket.favoriteRoutes.firstIndex(where: { $0.routeKey == routeKey }) {
                bucket.favoriteRoutes.remove(at: index)
            } else {
                bucket.favoriteRoutes.insert(
                    FavoriteRoute(
                        routeKey: routeKey,
                        route: entry.route,
                        serviceType: entry.serviceTypeValue,
                        co: entry.co,
                        origZh: entry.orig.zh,
                        origEn: entry.orig.en,
                        destZh: entry.dest.zh,
                        destEn: entry.dest.en,
                        createdAt: Date(),
                        lineID: entry.gtfsId?.value,
                        modeRawValue: modeRawValue
                    ),
                    at: 0
                )
            }
        }
    }

    func removeFavoriteRoutes(at offsets: IndexSet) {
        updateCurrent { $0.favoriteRoutes.remove(atOffsets: offsets) }
    }

    func removeFavoriteRoutes(_ favorites: [RegionalFavoriteRoute]) {
        for item in favorites {
            guard var payload = regions[item.regionID] else { continue }
            payload.favoriteRoutes.removeAll { $0.routeKey == item.favorite.routeKey }
            regions[item.regionID] = payload
        }
        save()
    }

    func isFavoriteStop(_ stopId: String) -> Bool {
        current.favoriteStops.contains { $0.id == stopId }
    }

    func toggleFavoriteStop(id: String, name: Terminal, location: StopLocation) {
        updateCurrent { bucket in
            if let index = bucket.favoriteStops.firstIndex(where: { $0.id == id }) {
                bucket.favoriteStops.remove(at: index)
            } else {
                bucket.favoriteStops.insert(
                    FavoriteStop(
                        id: id,
                        nameZh: name.zh,
                        nameEn: name.en,
                        lat: location.lat,
                        lng: location.lng,
                        createdAt: Date()
                    ),
                    at: 0
                )
            }
        }
    }

    func removeFavoriteStops(at offsets: IndexSet) {
        updateCurrent { $0.favoriteStops.remove(atOffsets: offsets) }
    }

    func removeFavoriteStops(_ favorites: [RegionalFavoriteStop]) {
        for item in favorites {
            guard var payload = regions[item.regionID] else { continue }
            payload.favoriteStops.removeAll { $0.id == item.favorite.id }
            regions[item.regionID] = payload
        }
        save()
    }

    // MARK: - Recents

    func recordRecentRoute(
        entry: RouteEntry,
        routeKey: String,
        stopId: String,
        seq: Int,
        stopName: Terminal,
        modeRawValue: String? = nil
    ) {
        updateCurrent { bucket in
            bucket.recentRoutes.removeAll { $0.routeKey == routeKey && $0.seq == seq }
            bucket.recentRoutes.insert(
                RecentRoute(
                    routeKey: routeKey,
                    route: entry.route,
                    co: entry.co,
                    origZh: entry.orig.zh,
                    origEn: entry.orig.en,
                    destZh: entry.dest.zh,
                    destEn: entry.dest.en,
                    stopId: stopId,
                    seq: seq,
                    stopNameZh: stopName.zh,
                    stopNameEn: stopName.en,
                    viewedAt: Date(),
                    lineID: entry.gtfsId?.value,
                    modeRawValue: modeRawValue
                ),
                at: 0
            )
            if bucket.recentRoutes.count > maxRecent {
                bucket.recentRoutes = Array(bucket.recentRoutes.prefix(maxRecent))
            }
        }
    }

    func recordRecentStop(id: String, name: Terminal, location: StopLocation) {
        updateCurrent { bucket in
            bucket.recentStops.removeAll { $0.id == id }
            bucket.recentStops.insert(
                RecentStop(
                    id: id,
                    nameZh: name.zh,
                    nameEn: name.en,
                    lat: location.lat,
                    lng: location.lng,
                    viewedAt: Date()
                ),
                at: 0
            )
            if bucket.recentStops.count > maxRecent {
                bucket.recentStops = Array(bucket.recentStops.prefix(maxRecent))
            }
        }
    }

    /// Clears history only for the active region.
    func clearRecents() {
        updateCurrent {
            $0.recentRoutes = []
            $0.recentStops = []
        }
    }

    // MARK: - Storage

    private struct RegionPayload: Codable {
        var favoriteRoutes: [FavoriteRoute] = []
        var favoriteStops: [FavoriteStop] = []
        var recentRoutes: [RecentRoute] = []
        var recentStops: [RecentStop] = []
    }

    private struct Payload: Codable {
        let schemaVersion: Int
        var regions: [String: RegionPayload]
    }

    /// Storage format used through v1.1.0, before region isolation existed.
    private struct LegacyPayload: Codable {
        var favoriteRoutes: [FavoriteRoute] = []
        var favoriteStops: [FavoriteStop] = []
        var recentRoutes: [RecentRoute] = []
        var recentStops: [RecentStop] = []

        var regionPayload: RegionPayload {
            RegionPayload(
                favoriteRoutes: favoriteRoutes,
                favoriteStops: favoriteStops,
                recentRoutes: recentRoutes,
                recentStops: recentStops
            )
        }
    }

    private func updateCurrent(_ mutation: (inout RegionPayload) -> Void) {
        var bucket = current
        mutation(&bucket)
        regions[activeRegionID] = bucket
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }

        if let payload = try? JSONDecoder().decode(Payload.self, from: data),
           payload.schemaVersion == 2 {
            regions = payload.regions
            return
        }

        guard let legacy = try? JSONDecoder().decode(LegacyPayload.self, from: data) else { return }
        // Legacy records carried no city metadata, so their original city
        // cannot be reconstructed safely. Preserve them in the app's original
        // Hong Kong namespace instead of guessing or discarding user data.
        regions = [Self.legacyRegionID: legacy.regionPayload]
        save()
    }

    private func save() {
        let payload = Payload(schemaVersion: 2, regions: regions)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storageURL, options: .atomic)
    }
}
