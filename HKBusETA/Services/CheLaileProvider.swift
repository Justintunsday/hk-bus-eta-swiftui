import Foundation

/// Mainland-China cities served through the 车来了 (CheLaile) H5 API.
///
/// Unlike the Hong Kong provider this one has no static route database: every
/// screen is backed by on-demand queries (search / nearby / stop / line).
struct CheLaileProvider: TransitProvider {
    let cityId: String
    let cityName: String

    var id: String { "cl-\(cityId)" }
    var regionName: String { cityName }
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
        guard let stops = entry.stops["chelaile"], seq >= 0, seq < stops.count,
              let lineId = entry.gtfsId?.value, !lineId.isEmpty
        else { return [] }

        let physicalStId = stops[seq]
        do {
            let detail = try await CheLaileClient().stopDetail(
                cityId: cityId,
                physicalStId: physicalStId,
                namesakeStId: nil,
                lat: nil,
                lng: nil
            )
            var etas: [Eta] = []
            for station in detail.stationList ?? [] {
                for item in station.lines ?? [] where item.line?.lineId == lineId {
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
        } catch {
            return []
        }
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

    func search(keyword: String) async throws -> CheLaileSearchResults {
        let response = try await CheLaileClient().search(cityId: cityId, keyword: keyword)
        var lines: [CheLaileLineHit] = []
        var stops: [CheLaileStopHit] = []
        for line in response.result?.lines ?? [] {
            guard line.subwayV2 != 1, let lineId = line.lineId, !lineId.isEmpty else { continue }
            lines.append(
                CheLaileLineHit(
                    id: "\(lineId)-\(line.direction ?? 0)",
                    lineId: lineId,
                    lineName: line.name ?? line.lineNo ?? "",
                    orig: line.startSn ?? "",
                    dest: line.endSn ?? ""
                )
            )
        }
        for station in response.result?.stations ?? [] {
            guard let physical = station.physicalStId, !physical.isEmpty else { continue }
            stops.append(
                CheLaileStopHit(
                    id: physical,
                    physicalStId: physical,
                    namesakeStId: station.namesakeStId,
                    name: station.sn ?? "",
                    subtitle: station.isSubway == true ? nil : nil
                )
            )
        }
        return CheLaileSearchResults(lines: lines, stops: stops)
    }

    // MARK: - Nearby

    func nearby(lat: Double, lng: Double, limit: Int = 20) async throws -> [CheLaileNearbyStop] {
        let response = try await CheLaileClient().nearby(cityId: cityId, lat: lat, lng: lng)
        return (response.nearSts ?? []).prefix(limit).compactMap { stop in
            guard let physical = stop.physicalStId, !physical.isEmpty else { return nil }
            let arrivals = (stop.lines ?? []).prefix(3).map { item in
                CheLaileNearbyArrival(
                    lineName: item.line?.name ?? "",
                    dest: item.line?.endSn ?? "",
                    minutes: Self.minutes(for: item)
                )
            }
            return CheLaileNearbyStop(
                id: physical,
                physicalStId: physical,
                namesakeStId: stop.namesakeStId,
                name: stop.sn ?? "",
                distance: stop.distance,
                arrivals: Array(arrivals)
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

    func stopBoard(physicalStId: String, namesakeStId: String?) async throws -> CheLaileStopBoardResult {
        let detail = try await CheLaileClient().stopDetail(
            cityId: cityId,
            physicalStId: physicalStId,
            namesakeStId: namesakeStId,
            lat: nil,
            lng: nil
        )
        var rows: [CheLaileBoardLine] = []
        var seen = Set<String>()
        var metros: [CheLaileMetroLine] = []
        var seenMetros = Set<String>()
        for station in detail.stationList ?? [] {
            for metro in station.metros ?? [] {
                let name = metro.fullName ?? metro.lineNo ?? ""
                guard !name.isEmpty, seenMetros.insert(name).inserted else { continue }
                metros.append(CheLaileMetroLine(id: name, name: name, color: metro.color))
            }
            for item in station.lines ?? [] {
                guard let line = item.line, let lineId = line.lineId, !lineId.isEmpty else { continue }
                let order = item.targetStation?.order ?? 0
                let rowId = "\(lineId)-\(line.direction ?? 0)-\(order)"
                guard seen.insert(rowId).inserted else { continue }
                let etas = (item.stnStates ?? []).compactMap { Self.minutes(bus: $0) }
                rows.append(
                    CheLaileBoardLine(
                        id: rowId,
                        lineId: lineId,
                        lineName: line.name ?? "",
                        destination: line.endSn ?? "",
                        targetOrder: order,
                        status: item.preArrivalTime.map { L10n.t("chelaile.scheduled") + " \($0)" } ?? "",
                        minutes: etas
                    )
                )
            }
        }
        rows.sort {
            ($0.minutes.first ?? 999) < ($1.minutes.first ?? 999)
        }
        return CheLaileStopBoardResult(rows: rows, metros: metros)
    }

    private static func minutes(bus: CheLaileLineItem.Bus) -> Int? {
        guard let date = arrivalDate(for: bus) else { return nil }
        return max(Int(round(date.timeIntervalSinceNow / 60)), 0)
    }

    // MARK: - Line payload (synthesizes an EtaDB entry for the shared UI)

    struct LinePayload: Sendable {
        let entry: RouteEntry
        let stops: [String: StopEntry]
    }

    func linePayload(lineId: String) async throws -> LinePayload? {
        let detail = try await CheLaileClient().lineDetail(cityId: cityId, lineId: lineId, lat: nil, lng: nil)
        guard let line = detail.line, let stations = detail.stations, !stations.isEmpty else { return nil }

        let routeName = line.name ?? lineId
        let origin = line.startSn ?? stations.first?.sn ?? ""
        let destination = line.endSn ?? stations.last?.sn ?? ""

        var stopIDs: [String] = []
        var stopEntries: [String: StopEntry] = [:]
        for station in stations {
            guard let physical = station.physicalStId, !physical.isEmpty else { continue }
            stopIDs.append(physical)
            if let lat = station.wgsLat, let lng = station.wgsLng {
                let name = station.sn ?? physical
                stopEntries[physical] = StopEntry(
                    location: StopLocation(lat: lat, lng: lng),
                    name: Terminal(en: name, zh: name)
                )
            }
        }
        guard !stopIDs.isEmpty else { return nil }

        let entry = RouteEntry(
            route: routeName,
            co: [],
            orig: Terminal(en: origin, zh: origin),
            dest: Terminal(en: destination, zh: destination),
            fares: nil,
            faresHoliday: nil,
            freq: nil,
            jt: nil,
            seq: stopIDs.count,
            serviceType: FlexibleString("1"),
            stops: ["chelaile": stopIDs],
            bound: [:],
            gtfsId: FlexibleString(lineId),
            nlbId: nil
        )
        return LinePayload(entry: entry, stops: stopEntries)
    }
}

// MARK: - Query result models

struct CheLaileSearchResults: Sendable {
    var lines: [CheLaileLineHit] = []
    var stops: [CheLaileStopHit] = []
}

struct CheLaileLineHit: Identifiable, Hashable, Sendable {
    let id: String
    let lineId: String
    let lineName: String
    let orig: String
    let dest: String
}

struct CheLaileStopHit: Identifiable, Hashable, Sendable {
    let id: String
    let physicalStId: String
    let namesakeStId: String?
    let name: String
    let subtitle: String?
}

struct CheLaileNearbyArrival: Sendable, Hashable {
    let lineName: String
    let dest: String
    let minutes: Int?
}

struct CheLaileNearbyStop: Identifiable, Sendable {
    let id: String
    let physicalStId: String
    let namesakeStId: String?
    let name: String
    let distance: Int?
    let arrivals: [CheLaileNearbyArrival]
}

struct CheLaileBoardLine: Identifiable, Sendable {
    let id: String
    let lineId: String
    let lineName: String
    let destination: String
    let targetOrder: Int
    let status: String
    let minutes: [Int]
}

struct CheLaileMetroLine: Identifiable, Sendable {
    let id: String
    let name: String
    /// Upstream "r,g,b" text.
    let color: String?
}

struct CheLaileStopBoardResult: Sendable {
    var rows: [CheLaileBoardLine] = []
    var metros: [CheLaileMetroLine] = []
}
