import Foundation

/// The cities that can be addressed by the SideStore-safe widget.
///
/// The city is part of the query grammar instead of being inferred from the
/// device or the app's current region. This keeps a widget configured for one
/// mainland city from ever searching another city's namespace.
struct WidgetTransitCity: Hashable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
}

enum WidgetTransitCityCatalog {
    static let all: [WidgetTransitCity] = [
        WidgetTransitCity(id: "014", name: "深圳", aliases: ["深圳", "深圳市", "shenzhen"]),
        WidgetTransitCity(id: "040", name: "广州", aliases: ["广州", "广州市", "廣州", "廣州市", "guangzhou"]),
        WidgetTransitCity(id: "034", name: "上海", aliases: ["上海", "上海市", "shanghai"]),
        WidgetTransitCity(id: "027", name: "北京", aliases: ["北京", "北京市", "beijing"]),
        WidgetTransitCity(id: "006", name: "天津", aliases: ["天津", "天津市", "tianjin"]),
        WidgetTransitCity(id: "003", name: "重庆", aliases: ["重庆", "重庆市", "重慶", "重慶市", "chongqing"]),
        WidgetTransitCity(id: "007", name: "成都", aliases: ["成都", "成都市", "chengdu"]),
        WidgetTransitCity(id: "019", name: "佛山", aliases: ["佛山", "佛山市", "foshan"]),
        WidgetTransitCity(id: "009", name: "青岛", aliases: ["青岛", "青岛市", "青島", "青島市", "qingdao"]),
        WidgetTransitCity(id: "035", name: "沈阳", aliases: ["沈阳", "沈阳市", "瀋陽", "瀋陽市", "shenyang"]),
        WidgetTransitCity(id: "018", name: "南京", aliases: ["南京", "南京市", "nanjing"]),
        WidgetTransitCity(id: "076", name: "西安", aliases: ["西安", "西安市", "xian"]),
    ]

    static func city(matchingPrefix input: String) -> (city: WidgetTransitCity, remainder: String)? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedAliases = all
            .flatMap { city in city.aliases.map { (city, $0) } }
            .sorted { $0.1.count > $1.1.count }

        for (city, alias) in sortedAliases {
            guard value.lowercased().hasPrefix(alias.lowercased()) else { continue }
            var separators = CharacterSet.whitespacesAndNewlines
            separators.formUnion(.punctuationCharacters)
            let remainder = String(value.dropFirst(alias.count))
                .trimmingCharacters(in: separators)
            return (city, remainder)
        }
        return nil
    }
}

struct WidgetTransitParsedQuery: Hashable, Sendable {
    let city: WidgetTransitCity
    let keyword: String
}

enum WidgetTransitQueryParser {
    static func parse(_ input: String) -> WidgetTransitParsedQuery? {
        guard let match = WidgetTransitCityCatalog.city(matchingPrefix: input),
              !match.remainder.isEmpty
        else { return nil }
        return WidgetTransitParsedQuery(city: match.city, keyword: match.remainder)
    }

    static func folded(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }
}

/// All information needed to render and refresh one route/station target.
///
/// `id` is a versioned, URL-safe JSON payload. It is deliberately not a
/// database key: App Intents can reconstruct an entity from its ID in a
/// process that has no App Group access and no app-side cache.
struct WidgetTransitTargetRecord: Codable, Hashable, Sendable, Identifiable {
    let cityID: String
    let cityName: String
    let lineID: String
    let lineName: String
    let direction: Int
    let origin: String
    let destination: String
    let stopID: String
    let stopName: String
    let stationID: String
    let stopSequence: Int
    let latitude: Double
    let longitude: Double

    var id: String { WidgetTransitTargetID.encode(self) }

    init(
        cityID: String,
        cityName: String,
        lineID: String,
        lineName: String,
        direction: Int,
        origin: String,
        destination: String,
        stopID: String,
        stopName: String,
        stationID: String,
        stopSequence: Int,
        latitude: Double,
        longitude: Double
    ) {
        self.cityID = cityID
        self.cityName = cityName
        self.lineID = lineID
        self.lineName = lineName
        self.direction = direction
        self.origin = origin
        self.destination = destination
        self.stopID = stopID
        self.stopName = stopName
        self.stationID = stationID
        self.stopSequence = stopSequence
        self.latitude = latitude
        self.longitude = longitude
    }

    var directionText: String {
        let endpoints = [origin, destination].filter { !$0.isEmpty }
        guard !endpoints.isEmpty else { return "方向 \(direction) / Direction \(direction)" }
        return "方向 \(direction) / Direction \(direction) · \(endpoints.joined(separator: " → "))"
    }

    init?(id: String) {
        guard let decoded = WidgetTransitTargetID.decode(id) else { return nil }
        self = decoded
    }
}

enum WidgetTransitTargetID {
    private static let prefix = "wmbn-target-v1_"

    static func encode(_ target: WidgetTransitTargetRecord) -> String {
        var encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(target) else { return prefix + "invalid" }
        return prefix + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ id: String) -> WidgetTransitTargetRecord? {
        guard id.hasPrefix(prefix) else { return nil }
        var encoded = String(id.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(WidgetTransitTargetRecord.self, from: data)
    }
}
