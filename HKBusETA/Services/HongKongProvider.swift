import Foundation

/// Hong Kong region: KMB/CTB/NLB/GMB/MTR Bus/Light Rail/MTR and ferries,
/// served by the daily hk-bus-crawling dataset plus data.gov.hk ETA APIs.
struct HongKongProvider: TransitProvider {
    let id = "hk"
    let regionName = "香港 Hong Kong"
    let timeZone = TimeZone(identifier: "Asia/Hong_Kong")!

    var databaseURLs: [URL] {
        [
            URL(string: "https://data.hkbus.app/routeFareList.min.json")!,
            URL(string: "https://hkbus.github.io/hk-bus-crawling/routeFareList.min.json")!,
        ]
    }

    var databaseMd5URLs: [URL] {
        [
            URL(string: "https://data.hkbus.app/routeFareList.md5")!,
            URL(string: "https://hkbus.github.io/hk-bus-crawling/routeFareList.md5")!,
        ]
    }

    var operators: OperatorRegistry {
        OperatorRegistry(operators: Self.operatorTable)
    }

    private static let operatorTable: [String: TransitOperator] = {
        var table: [String: TransitOperator] = [:]
        func add(_ id: String, _ zh: String, _ en: String, _ brand: UInt32, _ onBrand: UInt32, ferry: Bool = false, logo: String? = nil) {
            table[id] = TransitOperator(
                id: id,
                names: ["zh-Hant": zh, "en": en],
                brandHex: brand,
                onBrandHex: onBrand,
                isFerry: ferry,
                logoAsset: logo
            )
        }
        add("kmb", "九巴", "KMB", 0xFF4747, 0xFFFFFF, logo: "company_kmb")
        add("ctb", "城巴", "Citybus", 0xFFE15E, 0x000000, logo: "company_ctb")
        add("nlb", "嶼巴", "NLB", 0x26A69A, 0xFFFFFF, logo: "company_nlb")
        add("lrtfeeder", "港鐵巴士", "MTR Bus", 0x8AC4FF, 0x000000, logo: "company_lrtfeeder")
        add("gmb", "綠色小巴", "Minibus", 0x36C94D, 0x000000, logo: "company_gmb")
        add("lightRail", "輕鐵", "Light Rail", 0xD3A809, 0x000000, logo: "company_mtr")
        add("mtr", "港鐵", "MTR", 0x9C2E00, 0xFFFFFF, logo: "company_mtr")
        add("sunferry", "新渡輪", "Sun Ferry", 0xFF4747, 0xFFFFFF, ferry: true)
        add("fortuneferry", "富裕小輪", "Fortune Ferry", 0xFF4747, 0xFFFFFF, ferry: true)
        add("hkkf", "港九小輪", "HK & KF", 0xFF4747, 0xFFFFFF, ferry: true)
        return table
    }()

    // MARK: Filters

    func operatorIDs(for filter: TransportFilter) -> Set<String> {
        switch filter {
        case .all:
            return Set(Self.operatorTable.keys)
        case .bus:
            return ["kmb", "ctb", "nlb", "lrtfeeder"]
        case .minibus:
            return ["gmb"]
        case .lightRail:
            return ["lightRail"]
        case .mtr:
            return ["mtr"]
        case .ferry:
            return ["sunferry", "fortuneferry", "hkkf"]
        }
    }

    // MARK: Calendar & schedule

    func isHoliday(_ db: EtaDB, date: Date) -> Bool {
        if RegionClock.calendar.component(.weekday, from: date) == 1 { return true }
        return db.holidays.contains(RegionClock.dayString(date))
    }

    func isServiceAvailable(entry: RouteEntry, db: EtaDB, at date: Date) -> Bool {
        guard let freq = entry.freq, !freq.isEmpty else { return true }
        let holiday = isHoliday(db, date: date)
        let target = weeklyMinutes(for: date, holiday: holiday)

        var available = false
        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else {
                available = true
                continue
            }
            for (dayIndex, valid) in validDays.enumerated() where valid == "1" {
                for (start, slot) in slots {
                    let startMinutes = dayIndex * 1440 + Self.minutes(start)
                    let endMinutes = dayIndex * 1440 + Self.minutes(slot?.end ?? start)
                    if Self.isBetween(start: startMinutes, end: endMinutes, target: target) {
                        available = true
                    }
                }
            }
        }
        return available
    }

    func currentHeadway(entry: RouteEntry, db: EtaDB, at date: Date) -> Int? {
        guard let freq = entry.freq, !freq.isEmpty else { return nil }
        let holiday = isHoliday(db, date: date)
        let target = weeklyMinutes(for: date, holiday: holiday)

        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else { continue }
            let effectiveDays: [Int] = holiday
                ? (validDays.first == "1" ? [0] : [])
                : validDays.enumerated().compactMap { $0.element == "1" ? $0.offset : nil }
            for dayIndex in effectiveDays {
                for (start, slot) in slots {
                    guard let slot else { continue }
                    let startMinutes = dayIndex * 1440 + Self.minutes(start)
                    let endMinutes = dayIndex * 1440 + Self.minutes(slot.end)
                    if startMinutes <= target, target <= endMinutes {
                        return slot.headway
                    }
                }
            }
        }
        return nil
    }

    func serviceHoursToday(entry: RouteEntry, db: EtaDB, at date: Date) -> String? {
        guard let freq = entry.freq, !freq.isEmpty else { return nil }
        let holiday = isHoliday(db, date: date)
        let weekday = RegionClock.weekdayIndex(date)
        var starts: [String] = []
        var ends: [String] = []
        for (serviceId, slots) in freq {
            guard let validDays = db.serviceDayMap[serviceId] else { continue }
            let valid = holiday ? validDays.first == "1" : validDays[weekday] == "1"
            guard valid else { continue }
            for (start, slot) in slots {
                starts.append(start)
                if let slot { ends.append(slot.end) }
            }
        }
        guard let minStart = starts.min(), let maxEnd = ends.max() else { return nil }
        return "\(Self.format(minStart)) - \(Self.format(maxEnd))"
    }

    func fare(entry: RouteEntry, at index: Int, db: EtaDB, at date: Date) -> String? {
        if isHoliday(db, date: date),
           let holidayFares = entry.faresHoliday,
           index < holidayFares.count {
            return holidayFares[index]
        }
        if let fares = entry.fares, index < fares.count {
            return fares[index]
        }
        return nil
    }

    // MARK: Presentation

    func routeColorHex(entry: RouteEntry) -> UInt32 {
        let companies = entry.co
        if companies.first == "mtr" {
            switch entry.route {
            case "AEL": return 0x00888E
            case "TCL": return 0xF3982D
            case "TML": return 0x9C2E00
            case "TKL": return 0x7E3C93
            case "EAL": return 0x5EB7E8
            case "SIL": return 0xCBD300
            case "TWL": return 0xE60012
            case "ISL": return 0x0075C2
            case "KTL": return 0x00A040
            case "DRL": return 0xEB6EA5
            default: return 0xFF4747
            }
        }
        if companies.contains("lightRail") {
            switch entry.route {
            case "505": return 0xDA2127
            case "507": return 0x00A652
            case "610": return 0x551C15
            case "614": return 0x00BFF3
            case "614P": return 0xF4858E
            case "615": return 0xFFDD00
            case "615P": return 0x016682
            case "705": return 0x73BF43
            case "706": return 0xB47AB5
            case "751": return 0xF48221
            case "761P": return 0x6F2D91
            default: return 0xD3A809
            }
        }
        if let first = companies.first, let op = operators.op(first), !op.isFerry {
            return op.brandHex
        }
        return companies.compactMap { operators.op($0)?.brandHex }.first ?? 0xFF4747
    }

    func arrivingThreshold(operatorID: String) -> Int {
        (operatorID == "mtr" || operatorID == "lightRail") ? 2 : 1
    }

    // MARK: ETA

    func fetchEtas(entry: RouteEntry, seq: Int, db: EtaDB, language: AppLanguage) async -> [Eta] {
        await HongKongETAService.fetchEtas(entry: entry, seq: seq, db: db, language: language)
    }

    // MARK: Helpers

    private func weeklyMinutes(for date: Date, holiday: Bool) -> Int {
        let components = RegionClock.calendar.dateComponents([.hour, .minute], from: date)
        return (holiday ? 0 : RegionClock.weekdayIndex(date)) * 1440
            + (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func minutes(_ hhmm: String) -> Int {
        let hour = Int(hhmm.prefix(2)) ?? 0
        let minute = Int(hhmm.dropFirst(2).prefix(2)) ?? 0
        return hour * 60 + minute
    }

    private static func isBetween(start: Int, end: Int, target: Int) -> Bool {
        if start - 60 <= target && target <= end + 60 { return true }
        let wholeWeek = 24 * 7 * 60
        if start - 60 <= target + wholeWeek && target + wholeWeek <= end + 60 { return true }
        return false
    }

    private static func format(_ hhmm: String) -> String {
        let total = minutes(hhmm)
        let hour = (total / 60) % 24
        let minute = total % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}
