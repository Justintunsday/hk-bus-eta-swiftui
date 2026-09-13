import CoreLocation
import Foundation
import Observation

struct NearbyStop: Identifiable, Sendable {
    var id: String { item.id }
    let item: StopSearchItem
    let distance: CLLocationDistance
}

struct RouteSearchItem: Sendable {
    let key: String
    let routeUpper: String
    let terminalLower: String
    let co: [String]
}

struct StopSearchItem: Sendable {
    let id: String
    let haystack: String
    let nameZh: String
    let nameEn: String
    let location: StopLocation
}

struct StopRouteRef: Sendable, Hashable {
    let routeKey: String
    let seq: Int
}

struct StopAlias: Sendable, Hashable {
    let co: String
    let stopId: String
}

@MainActor
@Observable
final class DataStore {
    private(set) var db: EtaDB?
    private(set) var isLoading = false
    private(set) var isDownloading = false
    private(set) var statusText = ""
    private(set) var lastLoaded: Date?
    var errorMessage: String?

    private(set) var routeSearchItems: [RouteSearchItem] = []
    private(set) var stopSearchItems: [StopSearchItem] = []
    private(set) var stopRouteIndex: [String: [StopRouteRef]] = [:]
    private(set) var directStopCompanies: [String: Set<String>] = [:]

    static let primaryURL = URL(string: "https://data.hkbus.app/routeFareList.min.json")!
    static let fallbackURL = URL(string: "https://hkbus.github.io/hk-bus-crawling/routeFareList.min.json")!
    static let md5PrimaryURL = URL(string: "https://data.hkbus.app/routeFareList.md5")!
    static let md5FallbackURL = URL(string: "https://hkbus.github.io/hk-bus-crawling/routeFareList.md5")!

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        session = URLSession(configuration: configuration)
    }

    // MARK: - Cache locations

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("HKBusETA", isDirectory: true)
    }

    private var cacheFileURL: URL { cacheDirectory.appendingPathComponent("routeFareList.min.json") }
    private var cacheMd5URL: URL { cacheDirectory.appendingPathComponent("routeFareList.md5") }

    private func ensureCacheDirectory() {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Loading

    func load() async {
        guard db == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let data = try? Data(contentsOf: cacheFileURL),
           let loaded = await Self.parse(data: data) {
            apply(loaded)
        }

        await refreshIfNeeded()
    }

    func refreshIfNeeded() async {
        ensureCacheDirectory()
        isDownloading = true
        statusText = L10n.t("status.checkingUpdate")
        defer {
            isDownloading = false
            statusText = ""
        }

        let remoteMd5 = await fetchText(md5: true)
        let localMd5 = (try? String(contentsOf: cacheMd5URL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)

        let needsDownload = db == nil
            || remoteMd5 == nil
            || localMd5 == nil
            || remoteMd5 != localMd5
            || !FileManager.default.fileExists(atPath: cacheFileURL.path)

        guard needsDownload else { return }

        statusText = L10n.t("status.downloading")
        guard let data = await fetchData() else {
            if db == nil {
                errorMessage = L10n.t("error.dataDownloadFailed")
            }
            return
        }

        statusText = L10n.t("status.processing")
        guard let loaded = await Self.parse(data: data) else {
            errorMessage = L10n.t("error.dataParseFailed")
            return
        }

        try? data.write(to: cacheFileURL, options: .atomic)
        if let remoteMd5 {
            try? remoteMd5.write(to: cacheMd5URL, atomically: true, encoding: .utf8)
        }
        apply(loaded)
        errorMessage = nil
    }

    private func fetchData() async -> Data? {
        for url in [Self.primaryURL, Self.fallbackURL] {
            if let data = try? await session.data(from: url).0, !data.isEmpty {
                return data
            }
        }
        return nil
    }

    private func fetchText(md5: Bool) async -> String? {
        let urls = md5 ? [Self.md5PrimaryURL, Self.md5FallbackURL] : [Self.primaryURL, Self.fallbackURL]
        for url in urls {
            if let (data, _) = try? await session.data(from: url),
               let text = String(data: data, encoding: .utf8) {
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    nonisolated private static func parse(data: Data) async -> LoadedData? {
        await Task.detached(priority: .userInitiated) {
            guard let db = try? JSONDecoder().decode(EtaDB.self, from: data) else { return nil }
            return buildLoadedData(db)
        }.value
    }

    nonisolated private static func buildLoadedData(_ db: EtaDB) -> LoadedData {
        var routeItems: [RouteSearchItem] = []
        routeItems.reserveCapacity(db.routeList.count)
        var stopRouteIndex: [String: [StopRouteRef]] = [:]
        var directStopCompanies: [String: Set<String>] = [:]

        for (key, entry) in db.routeList {
            let terminal = "\(entry.orig.en) \(entry.orig.zh) \(entry.dest.en) \(entry.dest.zh)"
            routeItems.append(
                RouteSearchItem(
                    key: key,
                    routeUpper: entry.route.uppercased(),
                    terminalLower: terminal.lowercased(),
                    co: entry.co
                )
            )
            for (co, ids) in entry.stops {
                for (seq, stopId) in ids.enumerated() {
                    stopRouteIndex[stopId, default: []].append(StopRouteRef(routeKey: key, seq: seq))
                    directStopCompanies[stopId, default: []].insert(co)
                }
            }
        }

        var stopItems: [StopSearchItem] = []
        stopItems.reserveCapacity(db.stopList.count)
        for (id, stop) in db.stopList {
            stopItems.append(
                StopSearchItem(
                    id: id,
                    haystack: "\(stop.name.zh) \(stop.name.en)".lowercased(),
                    nameZh: stop.name.zh,
                    nameEn: stop.name.en,
                    location: stop.location
                )
            )
        }

        return LoadedData(
            db: db,
            routeItems: routeItems,
            stopItems: stopItems,
            stopRouteIndex: stopRouteIndex,
            directStopCompanies: directStopCompanies
        )
    }

    private func apply(_ loaded: LoadedData) {
        db = loaded.db
        routeSearchItems = loaded.routeItems
        stopSearchItems = loaded.stopItems
        stopRouteIndex = loaded.stopRouteIndex
        directStopCompanies = loaded.directStopCompanies
        lastLoaded = Date()
    }

    // MARK: - Queries

    func entry(_ key: String) -> RouteEntry? { db?.routeList[key] }

    func stop(_ id: String) -> StopEntry? { db?.stopList[id] }

    func stopName(_ id: String, _ language: AppLanguage) -> String {
        stop(id)?.name.name(language) ?? id
    }

    /// Cross-company aliases of the same physical stop, including itself.
    func aliases(for stopId: String) -> [StopAlias] {
        guard let db else { return [] }
        var result: [StopAlias] = []
        var seen = Set<String>()
        for co in directStopCompanies[stopId] ?? [] {
            let alias = StopAlias(co: co, stopId: stopId)
            if seen.insert("\(co)|\(stopId)").inserted {
                result.append(alias)
            }
        }
        for tuple in db.stopMap[stopId] ?? [] where tuple.count >= 2 {
            let alias = StopAlias(co: tuple[0], stopId: tuple[1])
            if seen.insert("\(alias.co)|\(alias.stopId)").inserted {
                result.append(alias)
            }
        }
        if result.isEmpty {
            result.append(StopAlias(co: "", stopId: stopId))
        }
        return result
    }

    /// Route references (key + stop sequence) serving a physical stop.
    func routesAtStop(_ stopId: String) -> [StopRouteRef] {
        var refs: [StopRouteRef] = []
        var seen = Set<String>()
        for alias in aliases(for: stopId) {
            for ref in stopRouteIndex[alias.stopId] ?? [] {
                let signature = "\(ref.routeKey)|\(ref.seq)"
                if seen.insert(signature).inserted {
                    refs.append(ref)
                }
            }
        }
        return refs
    }

    func searchRoutes(query: String, filter: TransportFilter) -> [RouteSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // The database uses Traditional Chinese only; normalize the input so
        // Simplified Chinese queries still match.
        let normalized = ChineseConverter.traditional(trimmed)
        let upper = normalized.uppercased()
        let lower = normalized.lowercased()
        let allowed = filter.companies

        var scored: [(item: RouteSearchItem, score: Int)] = []
        for item in routeSearchItems {
            guard item.co.contains(where: { allowed.contains($0) }) else { continue }
            let score: Int
            if item.routeUpper == upper {
                score = 0
            } else if item.routeUpper.hasPrefix(upper) {
                score = 1
            } else if item.routeUpper.contains(upper) {
                score = 2
            } else if item.terminalLower.contains(lower) {
                score = 3
            } else {
                continue
            }
            scored.append((item, score))
        }
        scored.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.item.routeUpper < $1.item.routeUpper
        }
        return scored.prefix(80).map(\.item)
    }

    func searchStops(query: String) -> [StopSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = ChineseConverter.traditional(trimmed).lowercased()
        var matches = stopSearchItems.filter { $0.haystack.contains(lower) }
        matches.sort {
            let lhs = $0.nameZh.count + $0.nameEn.count
            let rhs = $1.nameZh.count + $1.nameEn.count
            if lhs != rhs { return lhs < rhs }
            return $0.id < $1.id
        }
        return Array(matches.prefix(40))
    }

    func nearestStops(to location: CLLocation, limit: Int = 40) -> [NearbyStop] {
        var results: [NearbyStop] = []
        results.reserveCapacity(stopSearchItems.count)
        for item in stopSearchItems {
            let distance = location.distance(from: CLLocation(latitude: item.location.lat, longitude: item.location.lng))
            results.append(NearbyStop(item: item, distance: distance))
        }
        results.sort { $0.distance < $1.distance }
        return Array(results.prefix(limit))
    }

    func routeCount(at stopId: String) -> Int {
        routesAtStop(stopId).count
    }

    /// The route entry running the opposite direction, if one exists.
    func oppositeEntry(for entry: RouteEntry) -> (key: String, entry: RouteEntry)? {
        guard let db else { return nil }
        guard entry.orig.en != entry.dest.en else { return nil }
        var fallback: (key: String, entry: RouteEntry)?
        for (key, candidate) in db.routeList {
            guard key != entry.routeKey else { continue }
            guard candidate.route == entry.route else { continue }
            guard !Set(candidate.co).isDisjoint(with: Set(entry.co)) else { continue }
            guard candidate.orig.en == entry.dest.en, candidate.dest.en == entry.orig.en else { continue }
            if candidate.serviceTypeValue == entry.serviceTypeValue {
                return (key, candidate)
            }
            if fallback == nil {
                fallback = (key, candidate)
            }
        }
        return fallback
    }
}

private struct LoadedData: Sendable {
    let db: EtaDB
    let routeItems: [RouteSearchItem]
    let stopItems: [StopSearchItem]
    let stopRouteIndex: [String: [StopRouteRef]]
    let directStopCompanies: [String: Set<String>]
}
