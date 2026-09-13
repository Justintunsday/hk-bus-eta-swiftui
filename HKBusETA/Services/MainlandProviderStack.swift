import Foundation

/// App-facing mainland provider.
///
/// AMap is the preferred base-data source when its key is configured. The
/// legacy CheLaile provider remains an explicit fallback for missing keys and
/// transient/unsupported AMap operations. ETA calls are routed through the
/// replaceable MainlandRealtimeProvider boundary; until an authorized feed is
/// supplied, the legacy compatibility provider is used as that fallback.
struct MainlandProviderStack: TransitProvider, MainlandTransitProvider {
    private let router: any MainlandTransitProvider
    private let cityIdentifier: MainlandCityIdentifier
    private let stableID: String

    init(
        cityName: String,
        cityCode: String,
        adcode: String?,
        realtime: (any MainlandRealtimeProvider)? = nil,
        client: AMapClient? = nil
    ) {
        let city = MainlandCityIdentifier(
            name: cityName,
            adcode: adcode,
            citycode: cityCode
        )
        let legacy = LegacyCheLaileProvider(cityId: cityCode, cityName: cityName)
        let selectedRealtime: (any MainlandRealtimeProvider)? = realtime ?? legacy
        self.cityIdentifier = city
        self.stableID = "mainland-\(adcode ?? cityCode)"
        self.router = MainlandProviderFactory.amapOrFallback(
            city: city,
            regionName: cityName,
            fallback: legacy,
            realtime: selectedRealtime,
            client: client
        )
    }

    // MARK: Shared TransitProvider surface

    var id: String { stableID }
    var regionName: String { cityIdentifier.name ?? cityIdentifier.preferredCode ?? "Mainland China" }
    var city: MainlandCityIdentifier { cityIdentifier }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    var operators: OperatorRegistry { OperatorRegistry(operators: [:]) }
    var databaseURLs: [URL] { [] }
    var databaseMd5URLs: [URL] { [] }
    var dataSource: MainlandDataSource { router.dataSource }
    var supportsRealtimeETAs: Bool { router.supportsRealtimeETAs }

    func operatorIDs(for filter: TransportFilter) -> Set<String> { [] }
    func isHoliday(_ db: EtaDB, date: Date) -> Bool { false }
    func isServiceAvailable(entry: RouteEntry, db: EtaDB, at date: Date) -> Bool { true }
    func currentHeadway(entry: RouteEntry, db: EtaDB, at date: Date) -> Int? { nil }
    func serviceHoursToday(entry: RouteEntry, db: EtaDB, at date: Date) -> String? { nil }

    func fare(entry: RouteEntry, at index: Int, db: EtaDB, at date: Date) -> String? {
        guard let fares = entry.fares, !fares.isEmpty else { return nil }
        let safeIndex = min(max(index, 0), fares.count - 1)
        let value = fares[safeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func arrivingThreshold(operatorID: String) -> Int { 1 }

    func routeColorHex(entry: RouteEntry) -> UInt32 {
        MainlandProviderPalette.color(for: entry.route)
    }

    // MARK: Mainland capability surface

    func search(keyword: String) async throws -> MainlandSearchResults {
        try await router.search(keyword: keyword)
    }

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] {
        try await router.nearby(latitude: latitude, longitude: longitude, limit: limit)
    }

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        try await router.stopBoard(stopID: stopID, namesakeStopID: namesakeStopID)
    }

    func linePayload(lineID: String) async throws -> MainlandLinePayload? {
        try await router.linePayload(lineID: lineID)
    }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        language: AppLanguage
    ) async throws -> [Eta] {
        try await router.fetchEtas(
            lineID: lineID,
            stopID: stopID,
            stopSequence: stopSequence,
            language: language
        )
    }

    /// Compatibility implementation required by the existing shared ETA
    /// service. Mainland views call the throwing capability above so failures
    /// remain visible instead of being turned into an empty arrival list.
    func fetchEtas(entry: RouteEntry, seq: Int, db: EtaDB, language: AppLanguage) async -> [Eta] {
        guard let stopIDs = entry.stops["mainland"] ?? entry.stops["chelaile"],
              seq >= 0, seq < stopIDs.count,
              let lineID = entry.gtfsId?.value, !lineID.isEmpty
        else { return [] }
        return (try? await fetchEtas(
            lineID: lineID,
            stopID: stopIDs[seq],
            stopSequence: seq,
            language: language
        )) ?? []
    }
}
