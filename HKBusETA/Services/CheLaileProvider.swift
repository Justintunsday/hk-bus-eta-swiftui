import Foundation

/// Legacy mainland compatibility provider backed by the unofficial 车来了
/// (CheLaile) H5 API. Production composition is owned by MainlandProvider;
/// this type is deliberately marked legacy and can be replaced by an
/// authorized realtime provider without changing the UI.
///
/// Unlike the Hong Kong provider this one has no static route database: every
/// screen is backed by on-demand queries (search / nearby / stop / line).
struct LegacyCheLaileProvider: TransitProvider, MainlandTransitProvider, MainlandRealtimeProvider {
    let cityId: String
    let cityName: String

    var id: String { "cl-\(cityId)" }
    var regionName: String { cityName }
    var city: MainlandCityIdentifier {
        MainlandCityIdentifier(name: cityName, citycode: cityId)
    }
    var dataSource: MainlandDataSource { .legacyFallback }
    var supportsRealtimeETAs: Bool { true }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    var operators: OperatorRegistry { OperatorRegistry(operators: [:]) }
    var databaseURLs: [URL] { [] }
    var databaseMd5URLs: [URL] { [] }

    // MARK: - Static-database interface (unused for query-mode regions)

    func operatorIDs(for filter: TransportFilter) -> Set<String> { [] }
    func isHoliday(_ db: EtaDB, date: Date) -> Bool { false }
    func isServiceAvailable(entry: RouteEntry, db: EtaDB, at date: Date) -> Bool { true }
    func currentHeadway(entry: RouteEntry, db: EtaDB, at date: Date) -> Int? { nil }
    func serviceHoursToday(entry: RouteEntry, db: EtaDB, at date: Date) -> String? { nil }
    func fare(entry: RouteEntry, at index: Int, db: EtaDB, at date: Date) -> String? { nil }
    func arrivingThreshold(operatorID: String) -> Int { 1 }

    func routeColorHex(entry: RouteEntry) -> UInt32 {
        Self.color(for: entry.route)
    }

    /// Stable pseudo-brand color per line number.
    static func color(for line: String) -> UInt32 {
        let palette: [UInt32] = [0x2F6FED, 0x0E9F6E, 0xE0245E, 0xF08C00, 0x7C3AED, 0x0E7490]
        var hash: UInt32 = 0
        for scalar in line.unicodeScalars {
            hash = hash &* 31 &+ scalar.value
        }
        return palette[Int(hash % UInt32(palette.count))]
    }

    // MARK: - ETA

    func fetchEtas(entry: RouteEntry, seq: Int, db: EtaDB, language: AppLanguage) async -> [Eta] {
        guard let stops = entry.stops["mainland"] ?? entry.stops["chelaile"],
              seq >= 0, seq < stops.count,
              let lineID = entry.gtfsId?.value, !lineID.isEmpty
        else { return [] }
        return (try? await fetchEtas(
            lineID: lineID,
            stopID: stops[seq],
            stopSequence: seq,
            language: language
        )) ?? []
    }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        language: AppLanguage,
        modeHint: MainlandTransitMode? = nil
    ) async throws -> [Eta] {
        guard MainlandRealtimePolicy.allowsRequest(modeHint: modeHint) else {
            throw MainlandProviderError.realtimeUnavailable(source: "legacy metro")
        }
        try Task.checkCancellation()
        let detail = try await CheLaileClient().stopDetail(
            cityId: cityId,
            physicalStId: stopID,
            namesakeStId: nil,
            lat: nil,
            lng: nil
        )
        try Task.checkCancellation()
        var etas: [Eta] = []
        for station in detail.stationList ?? [] {
            for item in station.lines ?? [] where item.line?.lineId == lineID {
                let destination = item.line?.endSn ?? ""
                for bus in item.stnStates ?? [] {
                    guard let date = Self.arrivalDate(for: bus) else { continue }
                    etas.append(
                        Eta(
                            eta: RegionClock.isoString(from: date),
                            remark: Terminal(en: "", zh: ""),
                            dest: Terminal(en: destination, zh: destination),
                            co: ""
                        )
                    )
                }
            }
        }
        return etas.sorted { $0.eta < $1.eta }
    }

    private static func arrivalDate(for bus: CheLaileLineItem.Bus) -> Date? {
        if let arrival = bus.arrivalTime, arrival > 0 {
            return Date(timeIntervalSince1970: arrival / 1000)
        }
        if let travel = bus.travelTime, travel > 0 {
            return Date().addingTimeInterval(TimeInterval(travel))
        }
        return nil
    }

    // MARK: - Search

    func search(keyword: String) async throws -> MainlandSearchResults {
        let response = try await CheLaileClient().search(cityId: cityId, keyword: keyword)
        var lines: [MainlandLineSummary] = []
        var stops: [MainlandStopSummary] = []
        for line in response.result?.lines ?? [] {
            guard let lineId = line.lineId, !lineId.isEmpty else { continue }
            lines.append(
                MainlandLineSummary(
                    id: "\(lineId)-\(line.direction ?? 0)",
                    lineID: lineId,
                    name: line.name ?? line.lineNo ?? lineId,
                    origin: line.startSn ?? "",
                    destination: line.endSn ?? "",
                    operatorName: nil,
                    mode: line.subwayV2 == 1 ? .metro : .bus,
                    serviceStatus: nil,
                    firstDeparture: nil,
                    lastDeparture: nil,
                    fare: nil,
                    city: city,
                    source: .legacyFallback
                )
            )
        }
        for station in response.result?.stations ?? [] {
            guard let physical = station.physicalStId, !physical.isEmpty else { continue }
            stops.append(
                MainlandStopSummary(
                    id: physical,
                    stopID: physical,
                    namesakeStopID: station.namesakeStId,
                    name: station.sn ?? "",
                    subtitle: nil,
                    location: station.lat.flatMap { lat in
                        station.lng.flatMap { lng in MainlandCoordinate.wgs84(latitude: lat, longitude: lng) }
                    },
                    city: city,
                    source: .legacyFallback
                )
            )
        }
        return MainlandSearchResults(lines: lines, stops: stops)
    }

    // MARK: - Nearby

    func nearby(latitude: Double, longitude: Double, limit: Int = 20) async throws -> [MainlandNearbyStop] {
        let response = try await CheLaileClient().nearby(cityId: cityId, lat: latitude, lng: longitude)
        return (response.nearSts ?? []).prefix(limit).compactMap { stop in
            guard let physical = stop.physicalStId, !physical.isEmpty else { return nil }
            let arrivals = (stop.lines ?? []).prefix(3).map { item in
                MainlandNearbyArrival(
                    lineID: item.line?.lineId,
                    lineName: item.line?.name ?? "",
                    destination: item.line?.endSn ?? "",
                    minutes: Self.minutes(for: item),
                    source: .legacyFallback
                )
            }
            return MainlandNearbyStop(
                id: physical,
                stopID: physical,
                namesakeStopID: stop.namesakeStId,
                name: stop.sn ?? "",
                distanceMeters: stop.distance.map(Double.init),
                location: stop.lat.flatMap { lat in
                    stop.lng.flatMap { lng in MainlandCoordinate.wgs84(latitude: lat, longitude: lng) }
                },
                arrivals: Array(arrivals),
                source: .legacyFallback
            )
        }
    }

    private static func minutes(for item: CheLaileLineItem) -> Int? {
        if let bus = item.stnStates?.first, let date = arrivalDate(for: bus) {
            return max(Int(round(date.timeIntervalSinceNow / 60)), 0)
        }
        return nil
    }

    // MARK: - Stop board

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        let detail = try await CheLaileClient().stopDetail(
            cityId: cityId,
            physicalStId: stopID,
            namesakeStId: namesakeStopID,
            lat: nil,
            lng: nil
        )
        var rows: [MainlandBoardLine] = []
        var seen = Set<String>()
        var otherLines: [MainlandTransitLine] = []
        var seenMetros = Set<String>()
        for station in detail.stationList ?? [] {
            for metro in station.metros ?? [] {
                let name = metro.fullName ?? metro.lineNo ?? ""
                guard !name.isEmpty, seenMetros.insert(name).inserted else { continue }
                let lineID = metro.lineId ?? name
                otherLines.append(MainlandTransitLine(
                    id: lineID,
                    lineID: lineID,
                    name: name,
                    mode: .metro,
                    color: metro.color
                ))
            }
            for item in station.lines ?? [] {
                guard let line = item.line, let lineId = line.lineId, !lineId.isEmpty else { continue }
                let order = item.targetStation?.order ?? 0
                let rowId = "\(lineId)-\(line.direction ?? 0)-\(order)"
                guard seen.insert(rowId).inserted else { continue }
                let etas = (item.stnStates ?? []).compactMap { Self.minutes(bus: $0) }
                rows.append(
                    MainlandBoardLine(
                        id: rowId,
                        lineID: lineId,
                        lineName: line.name ?? "",
                        destination: line.endSn ?? "",
                        targetStopSequence: order,
                        status: item.preArrivalTime.map { L10n.t("chelaile.scheduled") + " \($0)" },
                        minutes: etas,
                        source: .legacyFallback
                    )
                )
            }
        }
        rows.sort {
            ($0.minutes.first ?? 999) < ($1.minutes.first ?? 999)
        }
        return MainlandStopBoardResult(rows: rows, otherLines: otherLines)
    }

    private static func minutes(bus: CheLaileLineItem.Bus) -> Int? {
        guard let date = arrivalDate(for: bus) else { return nil }
        return max(Int(round(date.timeIntervalSinceNow / 60)), 0)
    }

    // MARK: - Line payload (synthesizes an EtaDB entry for the shared UI)

    func linePayload(
        lineID: String,
        modeHint: MainlandTransitMode? = nil
    ) async throws -> MainlandLinePayload? {
        let detail = try await CheLaileClient().lineDetail(cityId: cityId, lineId: lineID, lat: nil, lng: nil)
        guard let line = detail.line, let stations = detail.stations, !stations.isEmpty else { return nil }

        let routeName = line.name ?? lineID
        let origin = line.startSn ?? stations.first?.sn ?? ""
        let destination = line.endSn ?? stations.last?.sn ?? ""

        var stopSummaries: [(order: Int, index: Int, stop: MainlandStopSummary)] = []
        for (index, station) in stations.enumerated() {
            guard let physical = station.physicalStId, !physical.isEmpty else { continue }
            let name = station.sn ?? physical
            let location = station.wgsLat.flatMap { lat in
                station.wgsLng.flatMap { lng in MainlandCoordinate.wgs84(latitude: lat, longitude: lng) }
            }
            let stop = MainlandStopSummary(
                id: physical,
                stopID: physical,
                namesakeStopID: station.namesakeStId,
                name: name,
                subtitle: station.order.map { "Stop \($0)" },
                location: location,
                city: city,
                source: .legacyFallback
            )
            stopSummaries.append((station.order ?? Int.max, index, stop))
        }
        let orderedStops = stopSummaries
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.index < rhs.index
            }
            .map(\.stop)
        guard !orderedStops.isEmpty else { return nil }
        let summary = MainlandLineSummary(
            id: line.lineId ?? lineID,
            lineID: line.lineId ?? lineID,
            name: routeName,
            origin: origin.isEmpty ? orderedStops.first?.name ?? "" : origin,
            destination: destination.isEmpty ? orderedStops.last?.name ?? "" : destination,
            operatorName: nil,
            // The detail endpoint does not carry the search result's mode.
            // Preserve an explicit metro hint so it cannot fall through to
            // the legacy bus ETA path later.
            mode: modeHint ?? .bus,
            serviceStatus: nil,
            firstDeparture: line.firstTime,
            lastDeparture: line.lastTime,
            fare: line.price,
            city: city,
            source: .legacyFallback
        )
        return MainlandLinePayload(
            line: summary,
            stops: orderedStops,
            polyline: orderedStops.compactMap(\MainlandStopSummary.location),
            coordinateSystem: .wgs84,
            source: .legacyFallback
        )
    }
}

/// Source-compatibility alias for integrations that referenced the old name.
/// New code must use `LegacyCheLaileProvider` or `MainlandTransitProvider`.
@available(*, deprecated, message: "Use LegacyCheLaileProvider or MainlandTransitProvider")
typealias CheLaileProvider = LegacyCheLaileProvider

// MARK: - Query result models
