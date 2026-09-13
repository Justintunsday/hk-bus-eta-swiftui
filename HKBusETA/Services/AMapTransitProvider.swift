import Foundation

/// Official AMap base-data provider for mainland cities.
///
/// This provider owns route/stop search and line detail only.  AMap's bus
/// Web Service does not expose live vehicle arrival predictions, so ETA calls
/// intentionally return a typed unavailability error for a router or an
/// authorized real-time provider to handle.
struct AMapTransitProvider: MainlandTransitProvider {
    let client: AMapClient
    let city: MainlandCityIdentifier
    let regionName: String

    init(
        client: AMapClient,
        city: MainlandCityIdentifier,
        regionName: String? = nil
    ) {
        self.client = client
        self.city = city
        self.regionName = regionName ?? city.name ?? city.preferredCode ?? "Mainland China"
    }

    init(
        apiKey: String? = nil,
        city: MainlandCityIdentifier,
        regionName: String? = nil,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        transport: any AMapTransport = AMapURLSessionTransport(),
        baseURL: URL = AMapClient.defaultBaseURL
    ) throws {
        self.init(
            client: try AMapClient(
                apiKey: apiKey,
                bundle: bundle,
                environment: environment,
                transport: transport,
                baseURL: baseURL
            ),
            city: city,
            regionName: regionName
        )
    }

    var id: String {
        let code = city.preferredCode ?? regionName
        return "amap-\(code)"
    }

    var dataSource: MainlandDataSource { .amapBase }
    var supportsRealtimeETAs: Bool { false }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai") ?? .gmt }

    // MARK: Search

    func search(keyword: String) async throws -> MainlandSearchResults {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .empty }

        async let lineRecords = client.searchLines(keyword: value, city: city)
        async let stopRecords = client.searchStops(keyword: value, city: city)
        let (lines, stops) = try await (lineRecords, stopRecords)

        return MainlandSearchResults(
            lines: lines.map { makeLineSummary($0) },
            stops: stops.map { makeStopSummary($0) }
        )
    }

    // MARK: Nearby and stop board

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] {
        // There is no reliable official AMap bus-nearby endpoint among the
        // four supported Web Service APIs.  Returning an empty list would
        // confuse an upstream failure with "no stops", so the router can use
        // an explicitly supplied fallback instead.
        throw MainlandProviderError.unsupported(.nearby)
    }

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        // `stopid` supplies stop/base line information, not live arrivals.
        // A real-time stop board must be supplied by another provider.
        throw MainlandProviderError.unsupported(.stopBoard)
    }

    // MARK: Line detail

    func linePayload(lineID: String) async throws -> MainlandLinePayload? {
        let records = try await client.lineDetail(lineID: lineID, city: city)
        guard let record = records.first else { return nil }

        let line = makeLineSummary(record)
        let stops = record.stops.enumerated().map { index, stop in
            makeStopSummary(stop, fallbackSequence: index + 1)
        }
        return MainlandLinePayload(
            line: line,
            stops: stops,
            polyline: record.polyline,
            coordinateSystem: .gcj02,
            source: .amapBase
        )
    }

    // MARK: ETA boundary

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        language: AppLanguage
    ) async throws -> [Eta] {
        throw MainlandProviderError.realtimeUnavailable(source: id)
    }

    // MARK: Mapping

    private func makeLineSummary(_ record: AMapLineRecord) -> MainlandLineSummary {
        let lineID = record.id.isEmpty ? record.name : record.id
        return MainlandLineSummary(
            id: lineID,
            lineID: lineID,
            name: record.name.isEmpty ? lineID : record.name,
            origin: record.origin,
            destination: record.destination,
            operatorName: record.operatorName,
            mode: Self.mode(for: record.type),
            serviceStatus: record.serviceStatus,
            firstDeparture: record.firstDeparture,
            lastDeparture: record.lastDeparture,
            fare: record.totalFare ?? record.basicFare,
            city: MainlandCityIdentifier(
                name: city.name,
                adcode: record.adcode ?? city.adcode,
                citycode: record.citycode ?? city.citycode
            ),
            source: .amapBase
        )
    }

    private func makeStopSummary(
        _ record: AMapStopRecord,
        fallbackSequence: Int? = nil
    ) -> MainlandStopSummary {
        let stopID = record.id.isEmpty ? record.name : record.id
        let subtitle: String?
        if let sequence = record.sequence ?? fallbackSequence {
            subtitle = "Stop \(sequence)"
        } else {
            subtitle = nil
        }
        return MainlandStopSummary(
            id: stopID,
            stopID: stopID,
            namesakeStopID: nil,
            name: record.name.isEmpty ? stopID : record.name,
            subtitle: subtitle,
            location: record.location,
            city: MainlandCityIdentifier(
                name: city.name,
                adcode: record.adcode ?? city.adcode,
                citycode: record.citycode ?? city.citycode
            ),
            source: .amapBase
        )
    }

    private static func mode(for type: String?) -> MainlandTransitMode {
        guard let type else { return .bus }
        let lowercased = type.lowercased()
        if lowercased.contains("地铁") || lowercased.contains("metro") || lowercased.contains("subway") {
            return .metro
        }
        return .bus
    }
}
