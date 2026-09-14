import Foundation

private struct LegacyBookmarkPayload: Encodable {
    var favoriteRoutes: [FavoriteRoute] = []
    var favoriteStops: [FavoriteStop] = []
    var recentRoutes: [RecentRoute] = []
    var recentStops: [RecentStop] = []
}

@main
struct BookmarkRegionSelfTest {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bookmark-region-self-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storageURL = directory.appendingPathComponent("bookmarks.json")
        let store = BookmarkStore(regionID: "hk", storageURL: storageURL)
        let route = fixtureRoute()
        let stop = StopLocation(lat: 22.3, lng: 114.2)

        store.toggleFavoriteRoute(entry: route, routeKey: route.routeKey)
        store.toggleFavoriteStop(id: "shared-stop", name: Terminal(en: "Stop", zh: "車站"), location: stop)
        precondition(store.favoriteRoutes.count == 1)
        precondition(store.favoriteStops.count == 1)

        store.selectRegion("cl-014")
        precondition(store.favoriteRoutes.isEmpty)
        precondition(store.favoriteStops.isEmpty)
        precondition(!store.isFavoriteRoute(route.routeKey))
        precondition(!store.isFavoriteStop("shared-stop"))

        store.toggleFavoriteRoute(entry: route, routeKey: route.routeKey)
        store.toggleFavoriteStop(id: "shared-stop", name: Terminal(en: "Stop", zh: "车站"), location: stop)
        store.recordRecentRoute(
            entry: route,
            routeKey: route.routeKey,
            stopId: "shared-stop",
            seq: 0,
            stopName: Terminal(en: "Stop", zh: "车站")
        )
        precondition(store.allFavoriteRoutes.count == 2)
        precondition(Set(store.allFavoriteRoutes.map(\.regionID)) == Set(["hk", "cl-014"]))
        precondition(store.allFavoriteStops.count == 2)
        precondition(store.recentRoutes.first?.lineID == "fixture-line")

        store.selectRegion("hk")
        precondition(store.favoriteRoutes.count == 1)
        precondition(store.favoriteStops.count == 1)
        precondition(store.recentRoutes.isEmpty)

        store.toggleFavoriteRoute(entry: route, routeKey: route.routeKey)
        precondition(store.favoriteRoutes.isEmpty)
        store.selectRegion("cl-014")
        precondition(store.favoriteRoutes.count == 1)
        precondition(store.recentRoutes.count == 1)

        let reloaded = BookmarkStore(regionID: "hk", storageURL: storageURL)
        precondition(reloaded.favoriteRoutes.isEmpty)
        reloaded.selectRegion("cl-014")
        precondition(reloaded.favoriteRoutes.count == 1)
        precondition(reloaded.favoriteStops.count == 1)
        precondition(reloaded.allFavoriteRoutes.count == 1)

        let savedStop = reloaded.allFavoriteStops.first!
        reloaded.removeFavoriteStops([savedStop])
        precondition(reloaded.allFavoriteStops.isEmpty)

        try verifyLegacyMigration(in: directory)
        print("BOOKMARK REGION SELF-TEST OK")
    }

    @MainActor
    private static func verifyLegacyMigration(in directory: URL) throws {
        let url = directory.appendingPathComponent("legacy-bookmarks.json")
        let route = fixtureRoute()
        let legacy = LegacyBookmarkPayload(
            favoriteRoutes: [
                FavoriteRoute(
                    routeKey: route.routeKey,
                    route: route.route,
                    serviceType: route.serviceTypeValue,
                    co: route.co,
                    origZh: route.orig.zh,
                    origEn: route.orig.en,
                    destZh: route.dest.zh,
                    destEn: route.dest.en,
                    createdAt: Date()
                )
            ]
        )
        try JSONEncoder().encode(legacy).write(to: url)

        let migrated = BookmarkStore(regionID: "cl-014", storageURL: url)
        precondition(migrated.favoriteRoutes.isEmpty)
        migrated.selectRegion("hk")
        precondition(migrated.favoriteRoutes.count == 1)
    }

    private static func fixtureRoute() -> RouteEntry {
        RouteEntry(
            route: "1",
            co: ["fixture"],
            orig: Terminal(en: "Origin", zh: "起點"),
            dest: Terminal(en: "Destination", zh: "終點"),
            fares: nil,
            faresHoliday: nil,
            freq: nil,
            jt: nil,
            seq: 1,
            serviceType: FlexibleString("1"),
            stops: ["fixture": ["shared-stop"]],
            bound: [:],
            gtfsId: FlexibleString("fixture-line"),
            nlbId: nil
        )
    }
}
