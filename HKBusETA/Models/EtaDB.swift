import Foundation

struct EtaDB: Codable, Sendable {
    let holidays: [String]
    let routeList: [String: RouteEntry]
    let stopList: [String: StopEntry]
    let stopMap: [String: [[String]]]
    let serviceDayMap: [String: [String]]
}

extension EtaDB {
    static let empty = EtaDB(holidays: [], routeList: [:], stopList: [:], stopMap: [:], serviceDayMap: [:])
}

struct Terminal: Codable, Hashable, Sendable {
    let en: String
    let zh: String

    init(en: String, zh: String) {
        self.en = en
        self.zh = zh
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        en = (try? container.decodeIfPresent(String.self, forKey: .en)) ?? ""
        zh = (try? container.decodeIfPresent(String.self, forKey: .zh)) ?? ""
    }

    func name(_ language: AppLanguage) -> String {
        language == .zh ? zh : en
    }
}

struct StopLocation: Codable, Hashable, Sendable {
    let lat: Double
    let lng: Double
}

struct StopEntry: Codable, Sendable {
    let location: StopLocation
    let name: Terminal
}

struct RouteEntry: Codable, Sendable {
    let route: String
    let co: [String]
    let orig: Terminal
    let dest: Terminal
    let fares: [String]?
    let faresHoliday: [String]?
    let freq: [String: [String: FreqSlot?]]?
    let jt: FlexibleString?
    let seq: Int
    let serviceType: FlexibleString
    let stops: [String: [String]]
    let bound: [String: String]
    let gtfsId: FlexibleString?
    let nlbId: FlexibleString?

    var serviceTypeValue: String { serviceType.value }

    var isSpecialTrip: Bool { (Int(serviceTypeValue) ?? 1) >= 2 }

    var journeyTimeMinutes: Int? {
        guard let jt, let value = Int(jt.value) else { return nil }
        return value
    }

    var companies: [Company] {
        co.compactMap { Company(rawValue: $0) }
    }

    func stopIDs(_ company: Company) -> [String] {
        stops[company.rawValue] ?? []
    }

    /// The longest stop list among serving companies; used as canonical stop sequence.
    var canonicalStops: [String] {
        stops.values.max(by: { $0.count < $1.count }) ?? []
    }

    var boundValue: String { bound.values.first ?? "" }

    var routeKey: String {
        "\(route)+\(serviceTypeValue)+\(orig.en)+\(dest.en)"
    }
}

struct FreqSlot: Codable, Hashable, Sendable {
    /// End time in HHmm (may exceed 24 hours, e.g. "2620" = 02:20 next day).
    let end: String
    /// Headway in seconds.
    let headway: Int

    init(end: String, headway: Int) {
        self.end = end
        self.headway = headway
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        end = (try? container.decode(String.self)) ?? ""
        let headwayValue = try? container.decode(FlexibleString.self)
        headway = Int(headwayValue?.value ?? "") ?? 0
    }
}

/// Decodes a value that may be encoded either as a JSON string or a JSON number.
struct FlexibleString: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
