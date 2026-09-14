import Foundation

/// Primary mainland provider backed by the hosted CheLaile API.
///
/// This provider owns all CheLaile API identifiers. Search and stop-board
/// results expose the physical `physicalStId` required by stop detail; route
/// payloads retain that same canonical ID for legacy fallback and translate it
/// to the line × station `sId` only at the realtime request boundary. It never
/// mixes those identities with AMap.
struct CheLaileAPIProvider: TransitProvider, MainlandTransitProvider, MainlandRealtimeProvider {
    let cityId: String
    let cityName: String
    let city: MainlandCityIdentifier
    let client: CheLaileAPIClient

    init(
        cityId: String,
        cityName: String,
        adcode: String? = nil,
        client: CheLaileAPIClient = CheLaileAPIClient()
    ) {
        self.cityId = cityId
        self.cityName = cityName
        self.city = MainlandCityIdentifier(name: cityName, adcode: adcode, citycode: cityId)
        self.client = client
    }

    var id: String { "chelaile-api-\(cityId)" }
    var regionName: String { cityName }
    var dataSource: MainlandDataSource { .chelaileAPI }
    var supportsRealtimeETAs: Bool { true }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    var operators: OperatorRegistry { OperatorRegistry(operators: [:]) }
    var databaseURLs: [URL] { [] }
    var databaseMd5URLs: [URL] { [] }

    func operatorIDs(for filter: TransportFilter) -> Set<String> { [] }
    func isHoliday(_ db: EtaDB, date: Date) -> Bool { false }
    func isServiceAvailable(entry: RouteEntry, db: EtaDB, at date: Date) -> Bool { true }
    func currentHeadway(entry: RouteEntry, db: EtaDB, at date: Date) -> Int? { nil }
    func serviceHoursToday(entry: RouteEntry, db: EtaDB, at date: Date) -> String? { nil }
    func fare(entry: RouteEntry, at index: Int, db: EtaDB, at date: Date) -> String? { nil }
    func arrivingThreshold(operatorID: String) -> Int { 1 }
    func routeColorHex(entry: RouteEntry) -> UInt32 { MainlandProviderPalette.color(for: entry.route) }

    // MARK: Search

    func search(keyword: String) async throws -> MainlandSearchResults {
        let response = try await client.search(cityID: cityId, keyword: keyword)

        var lines: [MainlandLineSummary] = []
        for line in response.lines {
            let directions = line.directions.isEmpty
                ? [CheLaileAPIDirection(
                    direction: line.direction,
                    lineID: line.lineID,
                    startName: line.startName,
                    endName: line.endName
                )]
                : line.directions

            for (index, direction) in directions.enumerated() {
                guard let lineID = clean(direction.lineID ?? (index == 0 ? line.lineID : nil)), !lineID.isEmpty else {
                    continue
                }
                let directionValue = direction.direction ?? (index == 0 ? line.direction : nil) ?? index
                lines.append(
                    MainlandLineSummary(
                        id: "\(lineID)-\(directionValue)",
                        lineID: lineID,
                        name: clean(line.name ?? line.lineNo) ?? lineID,
                        origin: clean(direction.startName ?? line.startName) ?? "",
                        destination: clean(direction.endName ?? line.endName) ?? "",
                        operatorName: nil,
                        mode: line.isSubway ? .metro : .bus,
                        serviceStatus: nil,
                        firstDeparture: nil,
                        lastDeparture: nil,
                        fare: nil,
                        city: city,
                        source: .chelaileAPI
                    )
                )
            }
        }

        let stops = response.stations.compactMap { station -> MainlandStopSummary? in
            guard let physical = clean(station.physicalStopID), !physical.isEmpty else { return nil }
            let location = station.latitude.flatMap { latitude in
                station.longitude.flatMap { longitude in
                    MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
                }
            }
            return MainlandStopSummary(
                id: physical,
                stopID: physical,
                namesakeStopID: clean(station.namesakeStopID),
                name: clean(station.name) ?? physical,
                subtitle: station.isSubway ? L10n.t("mainland.metros") : nil,
                location: location,
                city: city,
                source: .chelaileAPI
            )
        }
        return MainlandSearchResults(lines: lines, stops: stops)
    }

    // MARK: Nearby

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { throw CheLaileAPIError.invalidRequest("Invalid WGS-84 location.") }

        let response = try await client.nearby(
            cityID: cityId,
            latitude: latitude,
            longitude: longitude,
            limit: min(max(limit, 1), 20)
        )
        return Array(response.stops.prefix(max(limit, 0))).compactMap { stop in
            guard let physical = clean(stop.physicalStopID), !physical.isEmpty else { return nil }
            let location = stop.latitude.flatMap { latitude in
                stop.longitude.flatMap { longitude in
                    MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
                }
            }
            let arrivals = stop.lines.prefix(3).compactMap { line -> MainlandNearbyArrival? in
                guard let lineID = clean(line.lineID), !lineID.isEmpty else { return nil }
                return MainlandNearbyArrival(
                    lineID: lineID,
                    lineName: clean(line.name) ?? lineID,
                    destination: clean(line.destination) ?? "",
                    minutes: Self.minutes(for: line.buses),
                    source: .chelaileAPI
                )
            }
            return MainlandNearbyStop(
                id: physical,
                stopID: physical,
                namesakeStopID: clean(stop.namesakeStopID),
                name: clean(stop.name) ?? physical,
                distanceMeters: stop.distance,
                location: location,
                arrivals: Array(arrivals),
                source: .chelaileAPI
            )
        }
    }

    // MARK: Stop board

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        let physical = try required(stopID, named: "physical_st_id")
        let response = try await client.stopDetail(
            cityID: cityId,
            physicalStopID: physical,
            namesakeStopID: namesakeStopID
        )

        var rows: [MainlandBoardLine] = []
        var seenRows = Set<String>()
        var otherLines: [MainlandTransitLine] = []
        var seenMetroIDs = Set<String>()
        var stationLocation: MainlandCoordinate?

        for station in response.stations {
            if stationLocation == nil {
                stationLocation = station.latitude.flatMap { latitude in
                    station.longitude.flatMap { longitude in
                        MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
                    }
                }
            }

            for metro in station.metros {
                let name = clean(metro.name ?? metro.lineNo) ?? ""
                guard !name.isEmpty else { continue }
                let lineID = clean(metro.lineID) ?? name
                guard seenMetroIDs.insert(lineID).inserted else { continue }
                otherLines.append(
                    MainlandTransitLine(
                        id: lineID,
                        lineID: lineID,
                        name: name,
                        mode: .metro,
                        color: metro.color
                    )
                )
            }

            for line in station.lines {
                guard let lineID = clean(line.lineID), !lineID.isEmpty else { continue }
                let order = line.targetOrder ?? 0
                let direction = line.direction ?? 0
                let rowID = "\(lineID)-\(direction)-\(order)"
                guard seenRows.insert(rowID).inserted else { continue }
                rows.append(
                    MainlandBoardLine(
                        id: rowID,
                        lineID: lineID,
                        lineName: clean(line.name) ?? lineID,
                        destination: clean(line.destination) ?? "",
                        targetStopSequence: line.targetOrder,
                        status: clean(line.status),
                        minutes: line.buses.compactMap(Self.minutes(for:)),
                        source: .chelaileAPI
                    )
                )
            }
        }

        rows.sort { ($0.minutes.first ?? 999) < ($1.minutes.first ?? 999) }
        return MainlandStopBoardResult(
            rows: rows,
            otherLines: otherLines,
            location: stationLocation.map(StopLocation.init)
        )
    }

    // MARK: Line detail

    func linePayload(
        lineID: String,
        modeHint: MainlandTransitMode?
    ) async throws -> MainlandLinePayload? {
        let lineID = try required(lineID, named: "line_id")
        let response = try await client.lineDetail(cityID: cityId, lineID: lineID)
        guard !response.empty, let line = response.line else { return nil }

        let orderedStations = response.stations.enumerated().sorted { lhs, rhs in
            let left = lhs.element.order ?? Int.max
            let right = rhs.element.order ?? Int.max
            return left == right ? lhs.offset < rhs.offset : left < right
        }
        let stops = orderedStations.compactMap { pair -> MainlandStopSummary? in
            let station = pair.element
            // Keep physicalStId as the canonical route stop ID. The legacy
            // fallback's stopDetail endpoint requires it. The realtime
            // method translates it to this station's sId using the cached
            // line detail before making the new API request.
            guard let physicalStopID = clean(station.physicalStopID), !physicalStopID.isEmpty else {
                return nil
            }
            let location = station.latitude.flatMap { latitude in
                station.longitude.flatMap { longitude in
                    MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
                }
            }
            return MainlandStopSummary(
                id: physicalStopID,
                stopID: physicalStopID,
                namesakeStopID: clean(station.namesakeStopID),
                name: clean(station.name) ?? physicalStopID,
                subtitle: station.order.map { "Stop \($0)" },
                location: location,
                city: city,
                source: .chelaileAPI
            )
        }
        guard !stops.isEmpty else { return nil }

        let routeName = clean(line.name) ?? lineID
        let origin = clean(line.startName) ?? stops.first?.name ?? ""
        let destination = clean(line.endName) ?? stops.last?.name ?? ""
        let summary = MainlandLineSummary(
            id: clean(line.lineID) ?? lineID,
            lineID: clean(line.lineID) ?? lineID,
            name: routeName,
            origin: origin,
            destination: destination,
            operatorName: nil,
            mode: modeHint ?? .bus,
            serviceStatus: nil,
            firstDeparture: line.firstTime,
            lastDeparture: line.lastTime,
            fare: line.price,
            city: city,
            source: .chelaileAPI
        )
        return MainlandLinePayload(
            line: summary,
            stops: stops,
            polyline: stops.compactMap(\.location),
            coordinateSystem: .wgs84,
            source: .chelaileAPI
        )
    }

    // MARK: Realtime

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        source: MainlandDataSource? = nil,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
    ) async throws -> [Eta] {
        guard MainlandRealtimePolicy.allowsRequest(modeHint: modeHint) else {
            throw MainlandProviderError.realtimeUnavailable(source: "CheLaile API metro")
        }
        let lineID = try required(lineID, named: "line_id")
        let physicalStopID = try required(stopID, named: "physical_st_id")

        // The route payload intentionally carries physicalStId so the legacy
        // provider can receive the right identifier during a failure. Resolve
        // that identity against the same cached line detail and only then
        // send the API-specific sId to /lines/realtime.
        let detail = try await client.lineDetail(cityID: cityId, lineID: lineID)
        guard !detail.empty else {
            throw CheLaileAPIError.transport("The line has no realtime station detail.")
        }
        guard let station = detail.stations.first(where: {
            $0.physicalStopID == physicalStopID || $0.stationID == physicalStopID
        }),
        let stationID = clean(station.stationID), !stationID.isEmpty
        else {
            throw CheLaileAPIError.transport("The line detail did not contain the requested physical stop ID.")
        }

        let targetOrder = station.order ?? stopSequence.map { $0 + 1 }
        let stationCoordinate = station.latitude.flatMap { latitude in
            station.longitude.flatMap { longitude in
                MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
            }
        }
        let callerCoordinate = latitude.flatMap { latitude in
            longitude.flatMap { longitude in
                MainlandCoordinate.wgs84(latitude: latitude, longitude: longitude)
            }
        }
        guard let targetOrder, targetOrder > 0,
              let coordinate = stationCoordinate ?? callerCoordinate,
              coordinate.system == .wgs84
        else {
            throw CheLaileAPIError.invalidRequest("Realtime ETA requires a station order and WGS-84 coordinates.")
        }

        let response = try await client.realtime(
            cityID: cityId,
            lineID: lineID,
            targetOrder: targetOrder,
            stationID: stationID,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let destination = response.line.flatMap { clean($0.endName) } ?? ""
        return response.buses.compactMap { bus in
            guard let eta = bus.eta, let date = Self.date(for: eta) else { return nil }
            return Eta(
                eta: RegionClock.isoString(from: date),
                remark: Terminal(en: "", zh: ""),
                dest: Terminal(en: destination, zh: destination),
                co: "chelaile-api"
            )
        }
        .sorted { $0.eta < $1.eta }
    }

    func fetchEtas(
        entry: RouteEntry,
        seq: Int,
        db: EtaDB,
        language: AppLanguage
    ) async -> [Eta] {
        guard let stops = entry.stops["mainland"] ?? entry.stops["chelaile"],
              seq >= 0, seq < stops.count,
              let lineID = entry.gtfsId?.value, !lineID.isEmpty
        else { return [] }
        return (try? await fetchEtas(
            lineID: lineID,
            stopID: stops[seq],
            stopSequence: seq,
            language: language,
            modeHint: nil
        )) ?? []
    }

    private static func minutes(for buses: [CheLaileAPIBus]) -> Int? {
        guard let bus = buses.first else { return nil }
        if let eta = bus.eta, let minutes = minutes(travelTime: eta.travelTime, arrivalTime: eta.arrivalTime) {
            return minutes
        }
        return minutes(travelTime: bus.travelTime, arrivalTime: bus.arrivalTime)
    }

    private static func minutes(for bus: CheLaileAPIBus) -> Int? {
        if let eta = bus.eta, let minutes = minutes(travelTime: eta.travelTime, arrivalTime: eta.arrivalTime) {
            return minutes
        }
        return minutes(travelTime: bus.travelTime, arrivalTime: bus.arrivalTime)
    }

    private static func minutes(travelTime: Int?, arrivalTime: Int64?) -> Int? {
        if let travelTime, travelTime >= 0 {
            return max(Int((Double(travelTime) / 60).rounded()), 0)
        }
        guard let arrivalTime, arrivalTime > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(arrivalTime) / 1000)
        return max(Int((date.timeIntervalSinceNow / 60.0).rounded()), 0)
    }

    private static func date(for eta: CheLaileAPIEta) -> Date? {
        if let arrivalTime = eta.arrivalTime, arrivalTime > 0 {
            return Date(timeIntervalSince1970: TimeInterval(arrivalTime) / 1000)
        }
        if let travelTime = eta.travelTime, travelTime >= 0 {
            return Date().addingTimeInterval(TimeInterval(travelTime))
        }
        return nil
    }

    private func required(_ value: String, named name: String) throws -> String {
        guard let value = clean(value), !value.isEmpty else {
            throw CheLaileAPIError.invalidRequest("Missing required parameter: \(name)")
        }
        return value
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension CheLaileAPIDirection {
    init(direction: Int?, lineID: String?, startName: String?, endName: String?) {
        self.direction = direction
        self.lineID = lineID
        self.startName = startName
        self.endName = endName
    }
}
