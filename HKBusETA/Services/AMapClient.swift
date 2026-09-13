import Foundation

/// Official AMap Web Service bus endpoints used by the base-data provider.
enum AMapBusEndpoint: String, Sendable {
    case lineName = "/v3/bus/linename"
    case lineID = "/v3/bus/lineid"
    case stopName = "/v3/bus/stopname"
    case stopID = "/v3/bus/stopid"
}

enum AMapError: Error, LocalizedError, Hashable, Sendable {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case apiError(status: String, info: String, code: String?)
    case transport(String)
    case decoding(String)
    case invalidParameter(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AMAP_WEB_SERVICE_KEY is not configured."
        case .invalidURL:
            return "The AMap request URL could not be created."
        case .invalidResponse:
            return "The AMap response was not a valid HTTP/JSON response."
        case let .httpStatus(status):
            return "The AMap server returned HTTP status \(status)."
        case let .apiError(status, info, code):
            let suffix = code.map { " (\($0))" } ?? ""
            return "The AMap API returned status \(status)\(suffix): \(info)"
        case let .transport(message):
            return "The AMap request failed: \(message)"
        case let .decoding(message):
            return "The AMap response could not be decoded: \(message)"
        case let .invalidParameter(message):
            return message
        }
    }
}

/// A transport response that is easy to replace in offline tests.
struct AMapTransportResponse: Sendable {
    let data: Data
    let statusCode: Int?

    init(data: Data, statusCode: Int?) {
        self.data = data
        self.statusCode = statusCode
    }
}

protocol AMapTransport: Sendable {
    func data(for request: URLRequest) async throws -> AMapTransportResponse
}

/// Production transport.  Tests can inject `AMapClosureTransport` or their
/// own `AMapTransport` and never touch the network.
final class AMapURLSessionTransport: AMapTransport, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> AMapTransportResponse {
        let (data, response) = try await session.data(for: request)
        return AMapTransportResponse(
            data: data,
            statusCode: (response as? HTTPURLResponse)?.statusCode
        )
    }
}

struct AMapClosureTransport: AMapTransport, @unchecked Sendable {
    let handler: @Sendable (URLRequest) async throws -> AMapTransportResponse

    init(handler: @escaping @Sendable (URLRequest) async throws -> AMapTransportResponse) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> AMapTransportResponse {
        try await handler(request)
    }
}

/// Thin client for the four official AMap bus Web Service endpoints.
///
/// AMap keys are intentionally resolved only from the process environment or
/// the generated app Info.plist.  No key is embedded in this source file.
struct AMapClient: Sendable {
    static let apiKeyInfoPlistKey = "AMAP_WEB_SERVICE_KEY"
    static let defaultBaseURL = URL(string: "https://restapi.amap.com")!

    private let apiKey: String
    private let baseURL: URL
    private let transport: any AMapTransport

    init(
        apiKey: String? = nil,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        transport: any AMapTransport = AMapURLSessionTransport(),
        baseURL: URL = AMapClient.defaultBaseURL
    ) throws {
        guard let resolved = apiKey ?? Self.resolveAPIKey(bundle: bundle, environment: environment) else {
            throw AMapError.missingAPIKey
        }
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isUsableAPIKey(trimmed) else { throw AMapError.missingAPIKey }
        guard baseURL.scheme != nil, baseURL.host != nil else { throw AMapError.invalidURL }

        self.apiKey = trimmed
        self.baseURL = baseURL
        self.transport = transport
    }

    static func resolveAPIKey(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let value = environment[apiKeyInfoPlistKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           isUsableAPIKey(value) {
            return value
        }
        if let value = bundle.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if isUsableAPIKey(trimmed) { return trimmed }
        }
        return nil
    }

    private static func isUsableAPIKey(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("$(") && !value.contains("${")
    }

    // MARK: Official endpoint calls

    func searchLines(
        keyword: String,
        city: MainlandCityIdentifier? = nil,
        page: Int = 1,
        offset: Int = 20
    ) async throws -> [AMapLineRecord] {
        let keyword = try Self.requiredValue(keyword, named: "keywords")
        let page = max(page, 1)
        let offset = min(max(offset, 1), 100)
        var parameters = [
            ("keywords", keyword),
            ("page", String(page)),
            ("offset", String(offset)),
            ("extensions", "all"),
        ]
        parameters.append(contentsOf: Self.cityParameters(city))
        let data = try await request(.lineName, parameters: parameters)
        return try Self.decodeLineResponse(data).lines
    }

    func lineDetail(
        lineID: String,
        city: MainlandCityIdentifier? = nil
    ) async throws -> [AMapLineRecord] {
        let lineID = try Self.requiredValue(lineID, named: "id")
        var parameters = [
            ("id", lineID),
            ("extensions", "all"),
        ]
        parameters.append(contentsOf: Self.cityParameters(city))
        let data = try await request(.lineID, parameters: parameters)
        return try Self.decodeLineResponse(data).lines
    }

    func searchStops(
        keyword: String,
        city: MainlandCityIdentifier? = nil,
        page: Int = 1,
        offset: Int = 20
    ) async throws -> [AMapStopRecord] {
        let keyword = try Self.requiredValue(keyword, named: "keywords")
        let page = max(page, 1)
        let offset = min(max(offset, 1), 100)
        var parameters = [
            ("keywords", keyword),
            ("page", String(page)),
            ("offset", String(offset)),
            ("extensions", "all"),
        ]
        parameters.append(contentsOf: Self.cityParameters(city))
        let data = try await request(.stopName, parameters: parameters)
        return try Self.decodeStopResponse(data).stops
    }

    func stopDetail(
        stopID: String,
        city: MainlandCityIdentifier? = nil
    ) async throws -> [AMapStopRecord] {
        let stopID = try Self.requiredValue(stopID, named: "id")
        var parameters = [
            ("id", stopID),
            ("extensions", "all"),
        ]
        parameters.append(contentsOf: Self.cityParameters(city))
        let data = try await request(.stopID, parameters: parameters)
        return try Self.decodeStopResponse(data).stops
    }

    /// URL construction is exposed as a pure helper so an offline test can
    /// assert query encoding without creating a network task.
    func url(
        for endpoint: AMapBusEndpoint,
        parameters: [(String, String)] = []
    ) throws -> URL {
        try Self.makeURL(
            baseURL: baseURL,
            endpoint: endpoint,
            apiKey: apiKey,
            parameters: parameters
        )
    }

    static func makeURL(
        baseURL: URL = AMapClient.defaultBaseURL,
        endpoint: AMapBusEndpoint,
        apiKey: String,
        parameters: [(String, String)] = []
    ) throws -> URL {
        guard let scheme = baseURL.scheme, let host = baseURL.host else {
            throw AMapError.invalidURL
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = baseURL.port
        let basePath = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
        components.path = basePath + endpoint.rawValue
        let all = [("key", apiKey), ("output", "json")] + parameters
        components.queryItems = all.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw AMapError.invalidURL }
        return url
    }

    // MARK: Offline decoding entry points

    static func decodeLineResponse(_ data: Data) throws -> AMapLineSearchResponse {
        let envelope = try decodeEnvelope(data)
        try validate(envelope)

        var rawLines = envelope.lines
        if let single = envelope.singleLine, !rawLines.contains(where: { $0.id == single.id && $0.name == single.name }) {
            rawLines.append(single)
        }
        return AMapLineSearchResponse(lines: rawLines.map(AMapLineRecord.init(raw:)))
    }

    static func decodeStopResponse(_ data: Data) throws -> AMapStopSearchResponse {
        let envelope = try decodeEnvelope(data)
        try validate(envelope)

        var rawStops = envelope.stops
        if let single = envelope.singleStop, !rawStops.contains(where: { $0.id == single.id && $0.name == single.name }) {
            rawStops.append(single)
        }
        return AMapStopSearchResponse(stops: rawStops.map(AMapStopRecord.init(raw:)))
    }

    private func request(
        _ endpoint: AMapBusEndpoint,
        parameters: [(String, String)]
    ) async throws -> Data {
        try Task.checkCancellation()
        let url = try Self.makeURL(
            baseURL: baseURL,
            endpoint: endpoint,
            apiKey: apiKey,
            parameters: parameters
        )
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let response = try await transport.data(for: request)
            try Task.checkCancellation()
            guard let statusCode = response.statusCode else { throw AMapError.invalidResponse }
            guard (200...299).contains(statusCode) else { throw AMapError.httpStatus(statusCode) }
            guard !response.data.isEmpty else { throw AMapError.invalidResponse }
            return response.data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as AMapError {
            throw error
        } catch {
            throw AMapError.transport(error.localizedDescription)
        }
    }

    private static func requiredValue(_ value: String, named name: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AMapError.invalidParameter("AMap parameter \(name) cannot be empty.") }
        return trimmed
    }

    private static func cityParameters(_ city: MainlandCityIdentifier?) -> [(String, String)] {
        guard let code = city?.preferredCode else { return [] }
        return [("city", code)]
    }

    private static func decodeEnvelope(_ data: Data) throws -> AMapEnvelope {
        do {
            return try JSONDecoder().decode(AMapEnvelope.self, from: data)
        } catch {
            throw AMapError.decoding(error.localizedDescription)
        }
    }

    private static func validate(_ envelope: AMapEnvelope) throws {
        guard envelope.status == "1" else {
            throw AMapError.apiError(
                status: envelope.status,
                info: envelope.info ?? "Unknown AMap error",
                code: envelope.infocode
            )
        }

        if let info = envelope.info,
           !info.isEmpty,
           info.caseInsensitiveCompare("OK") != .orderedSame {
            throw AMapError.apiError(
                status: envelope.status,
                info: info,
                code: envelope.infocode
            )
        }
    }
}

struct AMapLineSearchResponse: Hashable, Sendable {
    let lines: [AMapLineRecord]
}

struct AMapStopSearchResponse: Hashable, Sendable {
    let stops: [AMapStopRecord]
}

struct AMapLineReference: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let origin: String
    let destination: String
}

struct AMapStopRecord: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let location: MainlandCoordinate?
    let sequence: Int?
    let adcode: String?
    let citycode: String?
    let lineReferences: [AMapLineReference]
}

struct AMapLineRecord: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let type: String?
    let origin: String
    let destination: String
    let operatorName: String?
    let serviceStatus: String?
    let firstDeparture: String?
    let lastDeparture: String?
    let basicFare: String?
    let totalFare: String?
    let adcode: String?
    let citycode: String?
    let stops: [AMapStopRecord]
    let polyline: [MainlandCoordinate]
}

private struct AMapEnvelope: Decodable {
    let status: String
    let info: String?
    let infocode: String?
    let lines: [AMapRawBusLine]
    let singleLine: AMapRawBusLine?
    let stops: [AMapRawBusStop]
    let singleStop: AMapRawBusStop?

    private enum CodingKeys: String, CodingKey {
        case status
        case info
        case infocode
        case buslines
        case busline
        case busstops
        case busstop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let status = try? container.decode(AMapValueString.self, forKey: .status) else {
            throw DecodingError.keyNotFound(
                CodingKeys.status,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing AMap status")
            )
        }
        self.status = status.value
        self.info = (try? container.decode(AMapValueString.self, forKey: .info))?.value
        self.infocode = (try? container.decode(AMapValueString.self, forKey: .infocode))?.value
        self.lines = (try? container.decode([AMapRawBusLine].self, forKey: .buslines)) ?? []
        self.singleLine = try? container.decode(AMapRawBusLine.self, forKey: .busline)
        self.stops = (try? container.decode([AMapRawBusStop].self, forKey: .busstops)) ?? []
        self.singleStop = try? container.decode(AMapRawBusStop.self, forKey: .busstop)
    }
}

private struct AMapRawBusLine: Decodable {
    let id: String
    let name: String
    let type: String?
    let origin: String
    let destination: String
    let operatorName: String?
    let serviceStatus: String?
    let firstDeparture: String?
    let lastDeparture: String?
    let basicFare: String?
    let totalFare: String?
    let adcode: String?
    let citycode: String?
    let polyline: String?
    let stops: [AMapRawBusStop]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case startStop = "start_stop"
        case endStop = "end_stop"
        case company
        case status
        case startTime = "start_time"
        case endTime = "end_time"
        case basicPrice = "basic_price"
        case totalPrice = "total_price"
        case adcode
        case citycode
        case polyline
        case busstops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.amapString(.id) ?? ""
        name = container.amapString(.name) ?? ""
        type = container.amapString(.type)
        origin = container.amapString(.startStop) ?? ""
        destination = container.amapString(.endStop) ?? ""
        operatorName = container.amapString(.company)
        serviceStatus = container.amapString(.status)
        firstDeparture = container.amapString(.startTime)
        lastDeparture = container.amapString(.endTime)
        basicFare = container.amapString(.basicPrice)
        totalFare = container.amapString(.totalPrice)
        adcode = container.amapString(.adcode)
        citycode = container.amapString(.citycode)
        polyline = container.amapString(.polyline)
        stops = (try? container.decode([AMapRawBusStop].self, forKey: .busstops)) ?? []
    }
}

private struct AMapRawBusStop: Decodable {
    let id: String
    let name: String
    let location: String?
    let sequence: Int?
    let adcode: String?
    let citycode: String?
    let lineReferences: [AMapRawLineReference]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case sequence
        case adcode
        case citycode
        case buslines
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.amapString(.id) ?? ""
        name = container.amapString(.name) ?? ""
        location = container.amapString(.location)
        sequence = container.amapInt(.sequence)
        adcode = container.amapString(.adcode)
        citycode = container.amapString(.citycode)
        lineReferences = (try? container.decode([AMapRawLineReference].self, forKey: .buslines)) ?? []
    }
}

private struct AMapRawLineReference: Decodable {
    let id: String
    let name: String
    let origin: String
    let destination: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case startStop = "start_stop"
        case endStop = "end_stop"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.amapString(.id) ?? ""
        name = container.amapString(.name) ?? ""
        origin = container.amapString(.startStop) ?? ""
        destination = container.amapString(.endStop) ?? ""
    }
}

private struct AMapValueString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = String(value)
        } else if let value = try? container.decode(Double.self) {
            self.value = String(value)
        } else if let value = try? container.decode(Bool.self) {
            self.value = value ? "1" : "0"
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or number")
            )
        }
    }
}

private extension KeyedDecodingContainer {
    func amapString(_ key: Key) -> String? {
        guard let decoded = try? decode(AMapValueString.self, forKey: key) else { return nil }
        let trimmed = decoded.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func amapInt(_ key: Key) -> Int? {
        guard let value = amapString(key) else { return nil }
        return Int(value) ?? Double(value).map { Int($0.rounded()) }
    }
}

private extension AMapLineRecord {
    init(raw: AMapRawBusLine) {
        let recordID = raw.id.isEmpty ? raw.name : raw.id
        self.init(
            id: recordID,
            name: raw.name.isEmpty ? recordID : raw.name,
            type: raw.type,
            origin: raw.origin,
            destination: raw.destination,
            operatorName: raw.operatorName,
            serviceStatus: raw.serviceStatus,
            firstDeparture: raw.firstDeparture,
            lastDeparture: raw.lastDeparture,
            basicFare: raw.basicFare,
            totalFare: raw.totalFare,
            adcode: raw.adcode,
            citycode: raw.citycode,
            stops: raw.stops.map(AMapStopRecord.init(raw:)),
            polyline: Self.parsePolyline(raw.polyline)
        )
    }

    static func parsePolyline(_ text: String?) -> [MainlandCoordinate] {
        guard let text, !text.isEmpty else { return [] }
        return text
            .split(separator: "|", omittingEmptySubsequences: true)
            .flatMap { segment in
                segment.split(separator: ";", omittingEmptySubsequences: true).compactMap { pair in
                    let values = pair.split(separator: ",", omittingEmptySubsequences: true)
                    guard values.count >= 2,
                          let longitude = Double(values[0].trimmingCharacters(in: .whitespaces)),
                          let latitude = Double(values[1].trimmingCharacters(in: .whitespaces))
                    else { return nil }
                    return MainlandCoordinate.gcj02(latitude: latitude, longitude: longitude)
                }
            }
    }
}

private extension AMapStopRecord {
    init(raw: AMapRawBusStop) {
        self.init(
            id: raw.id.isEmpty ? raw.name : raw.id,
            name: raw.name.isEmpty ? raw.id : raw.name,
            location: Self.parseLocation(raw.location),
            sequence: raw.sequence,
            adcode: raw.adcode,
            citycode: raw.citycode,
            lineReferences: raw.lineReferences.map {
                AMapLineReference(
                    id: $0.id,
                    name: $0.name,
                    origin: $0.origin,
                    destination: $0.destination
                )
            }
        )
    }

    static func parseLocation(_ text: String?) -> MainlandCoordinate? {
        guard let text else { return nil }
        let values = text.split(separator: ",", omittingEmptySubsequences: true)
        guard values.count >= 2,
              let longitude = Double(values[0].trimmingCharacters(in: .whitespaces)),
              let latitude = Double(values[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return MainlandCoordinate.gcj02(latitude: latitude, longitude: longitude)
    }
}

/// Small deterministic responses for unit tests and local self-checks.  They
/// are decoded through the same production entry points and never trigger a
/// network request.
enum AMapOfflineFixture {
    static let lineResponse = Data(
        #"""
        {
          "status": "1",
          "info": "OK",
          "infocode": "10000",
          "buslines": [
            {
              "id": "fixture-line-1",
              "name": "示例 1 路",
              "type": "普通公交",
              "start_stop": "起点",
              "end_stop": "终点",
              "company": "示例公交",
              "status": "运营",
              "start_time": "0600",
              "end_time": "2300",
              "basic_price": "2",
              "total_price": "2",
              "polyline": "121.4737,31.2304;121.4740,31.2308",
              "busstops": [
                {
                  "id": "fixture-stop-1",
                  "name": "起点",
                  "location": "121.4737,31.2304",
                  "sequence": "1"
                }
              ]
            }
          ]
        }
        """#.utf8
    )

    static let stopResponse = Data(
        #"""
        {
          "status": "1",
          "info": "OK",
          "busstops": [
            {
              "id": "fixture-stop-1",
              "name": "起点",
              "location": "121.4737,31.2304",
              "adcode": "310000",
              "citycode": "021",
              "buslines": [
                {
                  "id": "fixture-line-1",
                  "name": "示例 1 路",
                  "start_stop": "起点",
                  "end_stop": "终点"
                }
              ]
            }
          ]
        }
        """#.utf8
    )

    static let apiErrorResponse = Data(
        #"{"status":"0","info":"INVALID_USER_KEY","infocode":"10001"}"#.utf8
    )
}
