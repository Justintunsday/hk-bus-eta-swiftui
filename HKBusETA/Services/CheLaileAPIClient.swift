import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Endpoints exposed by the hosted CheLaile API. The client deliberately
/// keeps the `/v1` prefix in its base URL so a self-hosted deployment can be
/// selected without changing the provider.
enum CheLaileAPIEndpoint: String, Sendable {
    case search
    case nearby = "stops/nearby"
    case stopDetail = "stops/detail"
    case lineDetail = "lines/detail"
    case realtime = "lines/realtime"

    var path: String { rawValue }
}

enum CheLaileAPIError: Error, LocalizedError, Hashable, Sendable {
    case invalidURL
    case invalidRequest(String)
    case httpStatus(Int)
    case apiError(statusCode: Int, code: String?, message: String, details: String?)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The CheLaile API URL could not be created."
        case let .invalidRequest(message):
            return message
        case let .httpStatus(status):
            return "The CheLaile API returned HTTP status \(status)."
        case let .apiError(statusCode, code, message, details):
            let codeText = code.map { " (\($0))" } ?? ""
            let detailText = details.map { " \($0)" } ?? ""
            return "The CheLaile API returned status \(statusCode)\(codeText): \(message)\(detailText)"
        case let .transport(message):
            return "The CheLaile API request failed: \(message)"
        case let .decoding(message):
            return "The CheLaile API response could not be decoded: \(message)"
        }
    }

    /// Only service/auth/upstream failures should switch to the legacy
    /// direct client. A malformed request is an app bug or caller error and
    /// must remain visible instead of being silently retried elsewhere.
    var isFallbackEligible: Bool {
        switch self {
        case .invalidURL, .transport, .decoding:
            return true
        case let .httpStatus(statusCode):
            return statusCode == 401 || statusCode == 403 || statusCode == 408
                || statusCode == 429 || statusCode >= 500
        case let .apiError(statusCode, _, _, _):
            return statusCode == 401 || statusCode == 403 || statusCode == 408
                || statusCode == 429 || statusCode >= 500
        case .invalidRequest:
            return false
        }
    }
}

struct CheLaileAPITransportResponse: Sendable {
    let data: Data
    let statusCode: Int?

    init(data: Data, statusCode: Int?) {
        self.data = data
        self.statusCode = statusCode
    }
}

protocol CheLaileAPITransport: Sendable {
    func data(for request: URLRequest) async throws -> CheLaileAPITransportResponse
}

final class CheLaileAPIURLSessionTransport: CheLaileAPITransport, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> CheLaileAPITransportResponse {
        let (data, response) = try await session.data(for: request)
        return CheLaileAPITransportResponse(
            data: data,
            statusCode: (response as? HTTPURLResponse)?.statusCode
        )
    }
}

struct CheLaileAPIClosureTransport: CheLaileAPITransport, @unchecked Sendable {
    let handler: @Sendable (URLRequest) async throws -> CheLaileAPITransportResponse

    init(handler: @escaping @Sendable (URLRequest) async throws -> CheLaileAPITransportResponse) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> CheLaileAPITransportResponse {
        try await handler(request)
    }
}

/// Route detail is used both to render a route and to translate its
/// physical stop IDs into the API's line×station `sId` for realtime. A small
/// actor cache avoids a second network call and keeps that translation tied
/// to the exact line detail response already shown to the user.
actor CheLaileAPILineDetailCache {
    private var values: [String: CheLaileAPILineDetailResponse] = [:]

    func value(cityID: String, lineID: String) -> CheLaileAPILineDetailResponse? {
        values["\(cityID)#\(lineID)"]
    }

    func insert(_ response: CheLaileAPILineDetailResponse, cityID: String, lineID: String) {
        values["\(cityID)#\(lineID)"] = response
    }
}

/// JSON client for the user's hosted CheLaile API.
///
/// The default deployment is public and does not need a key. Both the base
/// URL and optional key can be supplied by generated Info.plist values or
/// environment variables. No credential is stored in source code.
struct CheLaileAPIClient: Sendable {
    static let defaultBaseURL = URL(string: "https://chelaile-api-server.vercel.app/v1")!
    static let baseURLInfoPlistKey = "CHELAILE_API_BASE_URL"
    static let apiKeyInfoPlistKey = "CHELAILE_API_KEY"

    private let baseURL: URL?
    private let apiKey: String?
    private let transport: any CheLaileAPITransport
    private let lineCache: CheLaileAPILineDetailCache

    init(
        baseURL: URL? = nil,
        apiKey: String? = nil,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        transport: any CheLaileAPITransport = CheLaileAPIURLSessionTransport(),
        lineCache: CheLaileAPILineDetailCache = CheLaileAPILineDetailCache()
    ) {
        let resolvedBaseURL = baseURL ?? Self.resolveBaseURL(bundle: bundle, environment: environment)
        self.baseURL = Self.normalizedBaseURL(resolvedBaseURL)

        let resolvedKey = apiKey ?? Self.resolveAPIKey(bundle: bundle, environment: environment)
        let trimmedKey = resolvedKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = trimmedKey.flatMap { Self.isUsableValue($0) ? $0 : nil }
        self.transport = transport
        self.lineCache = lineCache
    }

    static func resolveBaseURL(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let raw = environment[baseURLInfoPlistKey]
            ?? (bundle.object(forInfoDictionaryKey: baseURLInfoPlistKey) as? String)
        guard let raw else { return defaultBaseURL }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Xcode leaves an unresolved Info.plist build placeholder when no
        // override is supplied; that means "use the documented default".
        guard Self.isUsableValue(value) else { return defaultBaseURL }
        guard let url = URL(string: value), url.scheme != nil, url.host != nil else { return nil }
        return url
    }

    static func resolveAPIKey(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let raw = environment[apiKeyInfoPlistKey]
            ?? (bundle.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String)
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isUsableValue(value) ? value : nil
    }

    func search(cityID: String, keyword: String) async throws -> CheLaileAPISearchResponse {
        let data = try await request(
            .search,
            parameters: [
                ("city_id", cityID),
                ("keyword", keyword),
            ]
        )
        return try Self.decode(CheLaileAPISearchResponse.self, from: data)
    }

    func nearby(
        cityID: String,
        latitude: Double,
        longitude: Double,
        limit: Int
    ) async throws -> CheLaileAPINearbyResponse {
        let data = try await request(
            .nearby,
            parameters: [
                ("city_id", cityID),
                ("lat", Self.coordinateString(latitude)),
                ("lng", Self.coordinateString(longitude)),
                ("limit", String(limit)),
            ]
        )
        return try Self.decode(CheLaileAPINearbyResponse.self, from: data)
    }

    func stopDetail(
        cityID: String,
        physicalStopID: String,
        namesakeStopID: String?
    ) async throws -> CheLaileAPIStopDetailResponse {
        var parameters = [
            ("city_id", cityID),
            ("physical_st_id", physicalStopID),
        ]
        if let namesakeStopID, !namesakeStopID.isEmpty {
            parameters.append(("namesake_st_id", namesakeStopID))
        }
        let data = try await request(.stopDetail, parameters: parameters)
        return try Self.decode(CheLaileAPIStopDetailResponse.self, from: data)
    }

    func lineDetail(cityID: String, lineID: String) async throws -> CheLaileAPILineDetailResponse {
        if let cached = await lineCache.value(cityID: cityID, lineID: lineID) {
            return cached
        }
        let data = try await request(
            .lineDetail,
            parameters: [
                ("city_id", cityID),
                ("line_id", lineID),
            ]
        )
        let response = try Self.decode(CheLaileAPILineDetailResponse.self, from: data)
        await lineCache.insert(response, cityID: cityID, lineID: lineID)
        return response
    }

    func realtime(
        cityID: String,
        lineID: String,
        targetOrder: Int,
        stationID: String,
        latitude: Double,
        longitude: Double
    ) async throws -> CheLaileAPIRealtimeResponse {
        let data = try await request(
            .realtime,
            parameters: [
                ("city_id", cityID),
                ("line_id", lineID),
                ("target_order", String(targetOrder)),
                ("station_id", stationID),
                ("lat", Self.coordinateString(latitude)),
                ("lng", Self.coordinateString(longitude)),
            ]
        )
        return try Self.decode(CheLaileAPIRealtimeResponse.self, from: data)
    }

    /// Pure URL construction is used by the offline fixture test.
    static func makeURL(
        baseURL: URL?,
        endpoint: CheLaileAPIEndpoint,
        parameters: [(String, String)] = []
    ) throws -> URL {
        guard let baseURL, baseURL.scheme != nil, baseURL.host != nil else {
            throw CheLaileAPIError.invalidURL
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        guard components != nil else { throw CheLaileAPIError.invalidURL }
        let basePath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let endpointPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = "/\([basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/"))"
        components?.queryItems = parameters.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components?.url else { throw CheLaileAPIError.invalidURL }
        return url
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CheLaileAPIError.decoding(error.localizedDescription)
        }
    }

    private func request(
        _ endpoint: CheLaileAPIEndpoint,
        parameters: [(String, String)]
    ) async throws -> Data {
        for (name, value) in parameters where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CheLaileAPIError.invalidRequest("Missing required parameter: \(name)")
        }
        guard let url = try? Self.makeURL(baseURL: baseURL, endpoint: endpoint, parameters: parameters) else {
            throw CheLaileAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "X-API-Key") }

        let response: CheLaileAPITransportResponse
        do {
            response = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CheLaileAPIError.transport(error.localizedDescription)
        }

        guard let statusCode = response.statusCode else {
            throw CheLaileAPIError.invalidURL
        }
        guard (200...299).contains(statusCode) else {
            if let envelope = try? JSONDecoder().decode(CheLaileAPIErrorEnvelope.self, from: response.data) {
                throw CheLaileAPIError.apiError(
                    statusCode: statusCode,
                    code: envelope.error.code,
                    message: envelope.error.message,
                    details: envelope.error.details?.summary
                )
            }
            throw CheLaileAPIError.httpStatus(statusCode)
        }
        return response.data
    }

    private static func normalizedBaseURL(_ url: URL?) -> URL? {
        guard let url, url.scheme != nil, url.host != nil else { return nil }
        let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = rawPath.isEmpty || rawPath.lowercased().hasSuffix("v1") ? rawPath : "\(rawPath)/v1"
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = path.isEmpty ? "/v1" : "/\(path)"
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }

    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func isUsableValue(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("$(") && !value.contains("${")
    }
}

// MARK: - API response models

struct CheLaileAPISearchResponse: Decodable, Sendable {
    let lines: [CheLaileAPISearchLine]
    let stations: [CheLaileAPISearchStation]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lines = try container.decodeIfPresent([CheLaileAPISearchLine].self, forKey: .lines) ?? []
        stations = try container.decodeIfPresent([CheLaileAPISearchStation].self, forKey: .stations) ?? []
    }

    private enum CodingKeys: String, CodingKey { case lines, stations }
}

struct CheLaileAPISearchLine: Decodable, Sendable {
    let name: String?
    let lineNo: String?
    let isSubway: Bool
    let directions: [CheLaileAPIDirection]
    let lineID: String?
    let direction: Int?
    let startName: String?
    let endName: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        lineNo = try container.decodeIfPresent(String.self, forKey: .lineNo)
        isSubway = try container.decodeFlexibleBool(forKey: .isSubway) ?? false
        directions = try container.decodeIfPresent([CheLaileAPIDirection].self, forKey: .directions) ?? []
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        direction = try container.decodeFlexibleInt(forKey: .direction)
        startName = try container.decodeIfPresent(String.self, forKey: .startName)
        endName = try container.decodeIfPresent(String.self, forKey: .endName)
    }

    private enum CodingKeys: String, CodingKey {
        case name, lineNo, isSubway, directions
        case lineID = "lineId"
        case direction
        case startName = "startSn"
        case endName = "endSn"
    }
}

struct CheLaileAPIDirection: Decodable, Sendable {
    let direction: Int?
    let lineID: String?
    let startName: String?
    let endName: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        direction = try container.decodeFlexibleInt(forKey: .direction)
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        startName = try container.decodeIfPresent(String.self, forKey: .startName)
        endName = try container.decodeIfPresent(String.self, forKey: .endName)
    }

    private enum CodingKeys: String, CodingKey {
        case direction
        case lineID = "lineId"
        case startName = "startSn"
        case endName = "endSn"
    }
}

struct CheLaileAPISearchStation: Decodable, Sendable {
    let stationID: String?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let physicalStopID: String?
    let namesakeStopID: String?
    let isSubway: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationID = try container.decodeIfPresent(String.self, forKey: .stationID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        latitude = try container.decodeFlexibleDouble(forKey: .latitude)
        longitude = try container.decodeFlexibleDouble(forKey: .longitude)
        physicalStopID = try container.decodeIfPresent(String.self, forKey: .physicalStopID)
        namesakeStopID = try container.decodeIfPresent(String.self, forKey: .namesakeStopID)
        isSubway = try container.decodeFlexibleBool(forKey: .isSubway) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case stationID = "sId"
        case name = "sn"
        case latitude = "lat"
        case longitude = "lng"
        case physicalStopID = "physicalStId"
        case namesakeStopID = "namesakeStId"
        case isSubway
    }
}

struct CheLaileAPINearbyResponse: Decodable, Sendable {
    let stops: [CheLaileAPINearbyStop]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stops = try container.decodeIfPresent([CheLaileAPINearbyStop].self, forKey: .stops) ?? []
    }

    private enum CodingKeys: String, CodingKey { case stops }
}

struct CheLaileAPINearbyStop: Decodable, Sendable {
    let stationID: String?
    let name: String?
    let distance: Double?
    let latitude: Double?
    let longitude: Double?
    let physicalStopID: String?
    let namesakeStopID: String?
    let isSubway: Bool
    let lines: [CheLaileAPINearbyLine]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationID = try container.decodeIfPresent(String.self, forKey: .stationID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        distance = try container.decodeFlexibleDouble(forKey: .distance)
        latitude = try container.decodeFlexibleDouble(forKey: .latitudeKey)
        longitude = try container.decodeFlexibleDouble(forKey: .longitudeKey)
        physicalStopID = try container.decodeIfPresent(String.self, forKey: .physicalStopID)
        namesakeStopID = try container.decodeIfPresent(String.self, forKey: .namesakeStopID)
        isSubway = try container.decodeFlexibleBool(forKey: .isSubway) ?? false
        lines = try container.decodeIfPresent([CheLaileAPINearbyLine].self, forKey: .lines) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case stationID = "sId"
        case name = "sn"
        case distance, isSubway, lines
        case latitudeKey = "lat"
        case longitudeKey = "lng"
        case physicalStopID = "physicalStId"
        case namesakeStopID = "namesakeStId"
    }
}

struct CheLaileAPINearbyLine: Decodable, Sendable {
    let lineID: String?
    let name: String?
    let destination: String?
    let targetOrder: Int?
    let targetStationID: String?
    let buses: [CheLaileAPIBus]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        destination = try container.decodeIfPresent(String.self, forKey: .destination)
        targetOrder = try container.decodeFlexibleInt(forKey: .targetOrder)
        targetStationID = try container.decodeIfPresent(String.self, forKey: .targetStationID)
        buses = try container.decodeIfPresent([CheLaileAPIBus].self, forKey: .buses) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case lineID = "lineId"
        case name
        case destination = "endSn"
        case targetOrder, targetStationID = "targetStationId", buses
    }
}

struct CheLaileAPILineDetailResponse: Decodable, Sendable {
    let line: CheLaileAPILineInfo?
    let stations: [CheLaileAPIStation]
    let empty: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        line = try container.decodeIfPresent(CheLaileAPILineInfo.self, forKey: .line)
        stations = try container.decodeIfPresent([CheLaileAPIStation].self, forKey: .stations) ?? []
        empty = try container.decodeFlexibleBool(forKey: .empty) ?? false
    }

    private enum CodingKeys: String, CodingKey { case line, stations, empty }
}

struct CheLaileAPILineInfo: Decodable, Sendable {
    let lineID: String?
    let name: String?
    let startName: String?
    let endName: String?
    let firstTime: String?
    let lastTime: String?
    let price: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        startName = try container.decodeIfPresent(String.self, forKey: .startName)
        endName = try container.decodeIfPresent(String.self, forKey: .endName)
        firstTime = try container.decodeIfPresent(String.self, forKey: .firstTime)
        lastTime = try container.decodeIfPresent(String.self, forKey: .lastTime)
        price = try container.decodeIfPresent(String.self, forKey: .price)
    }

    private enum CodingKeys: String, CodingKey {
        case lineID = "lineId"
        case name
        case startName = "startSn"
        case endName = "endSn"
        case firstTime, lastTime, price
    }
}

struct CheLaileAPIStation: Decodable, Sendable {
    let order: Int?
    let stationID: String?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let physicalStopID: String?
    let namesakeStopID: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decodeFlexibleInt(forKey: .order)
        stationID = try container.decodeIfPresent(String.self, forKey: .stationID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        latitude = try container.decodeFlexibleDouble(forKey: .latitude)
        longitude = try container.decodeFlexibleDouble(forKey: .longitude)
        physicalStopID = try container.decodeIfPresent(String.self, forKey: .physicalStopID)
        namesakeStopID = try container.decodeIfPresent(String.self, forKey: .namesakeStopID)
    }

    private enum CodingKeys: String, CodingKey {
        case order
        case stationID = "sId"
        case name = "sn"
        case latitude = "wgsLat"
        case longitude = "wgsLng"
        case physicalStopID = "physicalStId"
        case namesakeStopID = "namesakeStId"
    }
}

struct CheLaileAPIStopDetailResponse: Decodable, Sendable {
    let stations: [CheLaileAPIStopDetailStation]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stations = try container.decodeIfPresent([CheLaileAPIStopDetailStation].self, forKey: .stations) ?? []
    }

    private enum CodingKeys: String, CodingKey { case stations }
}

struct CheLaileAPIStopDetailStation: Decodable, Sendable {
    let stationID: String?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let lines: [CheLaileAPIStopLine]
    let metros: [CheLaileAPIMetro]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationID = try container.decodeIfPresent(String.self, forKey: .stationID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        latitude = try container.decodeFlexibleDouble(forKey: .latitude)
        longitude = try container.decodeFlexibleDouble(forKey: .longitude)
        lines = try container.decodeIfPresent([CheLaileAPIStopLine].self, forKey: .lines) ?? []
        metros = try container.decodeIfPresent([CheLaileAPIMetro].self, forKey: .metros) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case stationID = "sId"
        case name = "sn"
        case latitude = "lat"
        case longitude = "lng"
        case lines, metros
    }
}

struct CheLaileAPIStopLine: Decodable, Sendable {
    let lineID: String?
    let name: String?
    let direction: Int?
    let destination: String?
    let targetOrder: Int?
    let firstTime: String?
    let lastTime: String?
    let price: String?
    let status: String?
    let buses: [CheLaileAPIBus]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        direction = try container.decodeFlexibleInt(forKey: .direction)
        destination = try container.decodeIfPresent(String.self, forKey: .destination)
        targetOrder = try container.decodeFlexibleInt(forKey: .targetOrder)
        firstTime = try container.decodeIfPresent(String.self, forKey: .firstTime)
        lastTime = try container.decodeIfPresent(String.self, forKey: .lastTime)
        price = try container.decodeIfPresent(String.self, forKey: .price)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        buses = try container.decodeIfPresent([CheLaileAPIBus].self, forKey: .buses) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case lineID = "lineId"
        case name, direction
        case destination = "endSn"
        case targetOrder, firstTime, lastTime, price, status, buses
    }
}

struct CheLaileAPIMetro: Decodable, Sendable {
    let lineID: String?
    let name: String?
    let lineNo: String?
    let color: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineID = try container.decodeIfPresent(String.self, forKey: .lineID)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        lineNo = try container.decodeIfPresent(String.self, forKey: .lineNo)
        color = try container.decodeIfPresent(String.self, forKey: .color)
    }

    private enum CodingKeys: String, CodingKey {
        case lineID = "lineId"
        case name, lineNo, color
    }
}

struct CheLaileAPIBus: Decodable, Sendable {
    let travelTime: Int?
    let arrivalTime: Int64?
    let eta: CheLaileAPIEta?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        travelTime = try container.decodeFlexibleInt(forKey: .travelTime)
        arrivalTime = try container.decodeFlexibleInt64(forKey: .arrivalTime)
        eta = try container.decodeIfPresent(CheLaileAPIEta.self, forKey: .eta)
    }

    private enum CodingKeys: String, CodingKey { case travelTime, arrivalTime, eta }
}

struct CheLaileAPIEta: Decodable, Sendable {
    let travelTime: Int?
    let arrivalTime: Int64?
    let displayTime: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        travelTime = try container.decodeFlexibleInt(forKey: .travelTime)
        arrivalTime = try container.decodeFlexibleInt64(forKey: .arrivalTime)
        displayTime = try container.decodeIfPresent(String.self, forKey: .displayTime)
    }

    private enum CodingKeys: String, CodingKey { case travelTime, arrivalTime, displayTime }
}

struct CheLaileAPIRealtimeResponse: Decodable, Sendable {
    let line: CheLaileAPILineInfo?
    let targetOrder: Int?
    let buses: [CheLaileAPIRealtimeBus]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        line = try container.decodeIfPresent(CheLaileAPILineInfo.self, forKey: .line)
        targetOrder = try container.decodeFlexibleInt(forKey: .targetOrder)
        buses = try container.decodeIfPresent([CheLaileAPIRealtimeBus].self, forKey: .buses) ?? []
    }

    private enum CodingKeys: String, CodingKey { case line, targetOrder, buses }
}

struct CheLaileAPIRealtimeBus: Decodable, Sendable {
    let eta: CheLaileAPIEta?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eta = try container.decodeIfPresent(CheLaileAPIEta.self, forKey: .eta)
    }

    private enum CodingKeys: String, CodingKey { case eta }
}

private struct CheLaileAPIErrorEnvelope: Decodable {
    let error: CheLaileAPIErrorBody
}

private struct CheLaileAPIErrorBody: Decodable {
    let code: String?
    let message: String
    let details: CheLaileAPIJSONValue?
}

private indirect enum CheLaileAPIJSONValue: Decodable {
    case string(String)
    case number(String)
    case bool(Bool)
    case object([String: CheLaileAPIJSONValue])
    case array([CheLaileAPIJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) {
            self = .number(String(value))
            return
        }
        if let value = try? container.decode([String: CheLaileAPIJSONValue].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([CheLaileAPIJSONValue].self) {
            self = .array(value)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    var summary: String {
        switch self {
        case let .string(value): return value
        case let .number(value): return value
        case let .bool(value): return String(value)
        case let .object(value): return value.map { "\($0.key): \($0.value.summary)" }.joined(separator: ", ")
        case let .array(value): return value.map(\.summary).joined(separator: ", ")
        case .null: return ""
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeFlexibleInt64(forKey key: Key) throws -> Int64? {
        if let value = try decodeIfPresent(Int64.self, forKey: key) { return value }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Int64(value) }
        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func decodeFlexibleBool(forKey key: Key) throws -> Bool? {
        if let value = try decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }
}
