import Foundation
import Observation
import SwiftUI

struct FavoriteRoute: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(routeKey)#\(seq)" }
    let routeKey: String
    let route: String
    let serviceType: String
    let co: [String]
    let origZh: String
    let origEn: String
    let destZh: String
    let destEn: String
    let stopId: String
    let seq: Int
    let stopNameZh: String
    let stopNameEn: String
    let createdAt: Date
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
}

struct RecentStop: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let nameZh: String
    let nameEn: String
    let lat: Double
    let lng: Double
    let viewedAt: Date
}

@MainActor
@Observable
final class BookmarkStore {
    private(set) var favoriteRoutes: [FavoriteRoute] = []
    private(set) var favoriteStops: [FavoriteStop] = []
    private(set) var recentRoutes: [RecentRoute] = []
    private(set) var recentStops: [RecentStop] = []

    private let maxRecent = 50

    private var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("HKBusETA", isDirectory: true).appendingPathComponent("bookmarks.json")
    }

    init() {
        load()
    }

    // MARK: - Favorites

    func isFavoriteRoute(routeKey: String, seq: Int) -> Bool {
        favoriteRoutes.contains { $0.routeKey == routeKey && $0.seq == seq }
    }

    func toggleFavoriteRoute(entry: RouteEntry, routeKey: String, stopId: String, seq: Int, stopName: Terminal) {
        if let index = favoriteRoutes.firstIndex(where: { $0.routeKey == routeKey && $0.seq == seq }) {
            favoriteRoutes.remove(at: index)
        } else {
            favoriteRoutes.insert(
                FavoriteRoute(
                    routeKey: routeKey,
                    route: entry.route,
                    serviceType: entry.serviceTypeValue,
                    co: entry.co,
                    origZh: entry.orig.zh,
                    origEn: entry.orig.en,
                    destZh: entry.dest.zh,
                    destEn: entry.dest.en,
                    stopId: stopId,
                    seq: seq,
                    stopNameZh: stopName.zh,
                    stopNameEn: stopName.en,
                    createdAt: Date()
                ),
                at: 0
            )
        }
        save()
    }

    func removeFavoriteRoutes(at offsets: IndexSet) {
        favoriteRoutes.remove(atOffsets: offsets)
        save()
    }

    func isFavoriteStop(_ stopId: String) -> Bool {
        favoriteStops.contains { $0.id == stopId }
    }

    func toggleFavoriteStop(id: String, name: Terminal, location: StopLocation) {
        if let index = favoriteStops.firstIndex(where: { $0.id == id }) {
            favoriteStops.remove(at: index)
        } else {
            favoriteStops.insert(
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
        save()
    }

    func removeFavoriteStops(at offsets: IndexSet) {
        favoriteStops.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Recents

    func recordRecentRoute(entry: RouteEntry, routeKey: String, stopId: String, seq: Int, stopName: Terminal) {
        recentRoutes.removeAll { $0.routeKey == routeKey && $0.seq == seq }
        recentRoutes.insert(
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
                viewedAt: Date()
            ),
            at: 0
        )
        if recentRoutes.count > maxRecent {
            recentRoutes = Array(recentRoutes.prefix(maxRecent))
        }
        save()
    }

    func recordRecentStop(id: String, name: Terminal, location: StopLocation) {
        recentStops.removeAll { $0.id == id }
        recentStops.insert(
            RecentStop(id: id, nameZh: name.zh, nameEn: name.en, lat: location.lat, lng: location.lng, viewedAt: Date()),
            at: 0
        )
        if recentStops.count > maxRecent {
            recentStops = Array(recentStops.prefix(maxRecent))
        }
        save()
    }

    func clearRecents() {
        recentRoutes = []
        recentStops = []
        save()
    }

    // MARK: - Storage

    private struct Payload: Codable {
        var favoriteRoutes: [FavoriteRoute] = []
        var favoriteStops: [FavoriteStop] = []
        var recentRoutes: [RecentRoute] = []
        var recentStops: [RecentStop] = []
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        favoriteRoutes = payload.favoriteRoutes
        favoriteStops = payload.favoriteStops
        recentRoutes = payload.recentRoutes
        recentStops = payload.recentStops
    }

    private func save() {
        let payload = Payload(
            favoriteRoutes: favoriteRoutes,
            favoriteStops: favoriteStops,
            recentRoutes: recentRoutes,
            recentStops: recentStops
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storageURL, options: .atomic)
    }
}
