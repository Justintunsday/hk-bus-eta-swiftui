import CommonCrypto
import CryptoKit
import Foundation

/// Minimal client for the 车来了 (CheLaile) H5 API.
///
/// Reverse-engineered endpoints used by the open-source chelaile-mcp project:
/// requests are MD5-signed, responses are AES-256-ECB encrypted envelopes.
/// Unofficial and may break whenever the upstream changes.
struct CheLaileClient: Sendable {
    private static let baseURL = "https://web.chelaile.net.cn/api"
    private static let signSalt = "qwihrnbtmj"
    private static let aesKey = "FF32AE65FBFD19414EAAFF6291A54B42"
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 MicroMessenger/7.0.20.1781(0x6700143B) NetType/WIFI MiniProgramEnv/Windows WindowsWechat/WMPF WindowsWechat(0x63090a13) UnifiedPCWindowsWechat(0xf254160a) XWEB/18055"

    private static let defaultParams: [(String, String)] = [
        ("s", "h5"),
        ("wxs", "wx_app"),
        ("sign", "1"),
        ("h5RealData", "1"),
        ("v", "3.11.28"),
        ("src", "weixinapp_cx"),
        ("ctm_mp", "mp_wx"),
        ("vc", "2"),
        ("favoriteGray", "1"),
        ("gpstype", "wgs"),
        ("geo_type", "wgs"),
        ("scene", "1256"),
    ]

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    // MARK: - Endpoints

    func search(cityId: String, keyword: String) async throws -> CheLaileSearchResponse {
        try await request("/bus/query!nSearch.action", params: [
            ("cityId", cityId),
            ("localCityId", cityId),
            ("key", keyword),
            ("supportPhyStn", "true"),
        ])
    }

    func nearby(cityId: String, lat: Double, lng: Double) async throws -> CheLaileNearbyResponse {
        let latText = String(lat)
        let lngText = String(lng)
        return try await request("/bus/stop!encryptedHomePage.action", params: [
            ("cityId", cityId),
            ("localCityId", "undefined"),
            ("lat", latText),
            ("lng", lngText),
            ("geo_lat", latText),
            ("geo_lng", lngText),
            ("type", "5"),
            ("permission", "0"),
        ])
    }

    func stopDetail(cityId: String, physicalStId: String, namesakeStId: String?, lat: Double?, lng: Double?) async throws -> CheLaileStopDetailResponse {
        let latText = lat.map { String($0) } ?? ""
        let lngText = lng.map { String($0) } ?? ""
        return try await request("/bus/stop!encryptedPhyStnDetail.action", params: [
            ("cityId", cityId),
            ("localCityId", cityId),
            ("physicalStId", physicalStId),
            ("namesakeStId", namesakeStId ?? ""),
            ("firstLineId", ""),
            ("stationId", ""),
            ("lat", latText),
            ("lng", lngText),
            ("geo_lat", latText),
            ("geo_lng", lngText),
            ("actionState", "1"),
            ("permission", "0"),
        ])
    }

    func lineDetail(cityId: String, lineId: String, lat: Double?, lng: Double?) async throws -> CheLaileLineDetailResponse {
        let latText = lat.map { String($0) } ?? ""
        let lngText = lng.map { String($0) } ?? ""
        return try await request("/bus/line!encryptedLineDetail.action", params: [
            ("cityId", cityId),
            ("localCityId", cityId),
            ("lineId", lineId),
            ("lat", latText),
            ("lng", lngText),
            ("geo_lat", latText),
            ("geo_lng", lngText),
        ])
    }

    // MARK: - Transport

    private func request<T: Decodable>(_ path: String, params: [(String, String)]) async throws -> T {
        let all = Self.defaultParams + params
        let signature = Self.cryptoSign(all)

        guard var components = URLComponents(string: Self.baseURL + path) else {
            throw CheLaileError.invalidURL
        }
        components.queryItems = (all + [("cryptoSign", signature)]).map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw CheLaileError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://servicewechat.com/wx71d589ea01ce3321/814/page-frame.html", forHTTPHeaderField: "Referer")
        request.setValue("1", forHTTPHeaderField: "xweb_xhr")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, _) = try await session.data(for: request)
        let body = String(decoding: data, as: UTF8.self)
        let payload = try Self.decodeEnvelope(body)
        return try JSONDecoder().decode(T.self, from: payload)
    }

    private static func cryptoSign(_ params: [(String, String)]) -> String {
        let joined = params.map { "\"\($0.0)\"=\"\($0.1)\"" }.joined(separator: "&") + signSalt
        let digest = Insecure.MD5.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Finds the JSON envelope, unwraps `jsonr.data` and AES-decrypts
    /// `encryptResult` when present.
    private static func decodeEnvelope(_ body: String) throws -> Data {
        guard let start = body.firstIndex(of: "{") else { throw CheLaileError.invalidResponse }

        var depth = 0
        var end = start
        var index = start
        while index < body.endIndex {
            let character = body[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    end = index
                    break
                }
            }
            index = body.index(after: index)
        }

        guard let outerData = String(body[start...end]).data(using: .utf8),
              let outer = try? JSONSerialization.jsonObject(with: outerData) as? [String: Any],
              let jsonr = outer["jsonr"] as? [String: Any],
              let payload = jsonr["data"] as? [String: Any]
        else {
            throw CheLaileError.invalidResponse
        }

        if let encrypted = payload["encryptResult"] as? String {
            return try decrypt(encrypted)
        }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private static func decrypt(_ base64: String) throws -> Data {
        guard let cipher = Data(base64Encoded: base64) else { throw CheLaileError.decryptFailed }
        let key = Data(aesKey.utf8)
        let keyCount = key.count
        let cipherCount = cipher.count
        let outputCapacity = cipherCount + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0

        let status = output.withUnsafeMutableBytes { outputBytes in
            cipher.withUnsafeBytes { cipherBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        keyBytes.baseAddress,
                        keyCount,
                        nil,
                        cipherBytes.baseAddress,
                        cipherCount,
                        outputBytes.baseAddress,
                        outputCapacity,
                        &outputLength
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw CheLaileError.decryptFailed }
        output.removeSubrange(outputLength..<output.count)
        return output
    }
}

enum CheLaileError: Error {
    case invalidURL
    case invalidResponse
    case decryptFailed
}

// MARK: - Responses

struct CheLaileSearchResponse: Decodable {
    let result: Result?

    struct Result: Decodable {
        let lines: [Line]?
        let stations: [Station]?
    }

    struct Line: Decodable {
        let lineId: String?
        let name: String?
        let lineNo: String?
        let direction: Int?
        let startSn: String?
        let endSn: String?
        let subwayV2: Int?
    }

    struct Station: Decodable {
        let sId: String?
        let sn: String?
        let lat: Double?
        let lng: Double?
        let physicalStId: String?
        let namesakeStId: String?
        let isSubway: Bool?
    }
}

struct CheLaileNearbyResponse: Decodable {
    let nearSts: [Stop]?

    struct Stop: Decodable {
        let sId: String?
        let sn: String?
        let distance: Int?
        let physicalStId: String?
        let namesakeStId: String?
        let firstLineId: String?
        let isSubway: Int?
        let lines: [CheLaileLineItem]?
    }
}

struct CheLaileStopDetailResponse: Decodable {
    let stationList: [Station]?

    struct Station: Decodable {
        let sId: String?
        let sn: String?
        let lat: Double?
        let lng: Double?
        let distance: Int?
        let lines: [CheLaileLineItem]?
        let metros: [Metro]?
    }

    struct Metro: Decodable {
        let lineId: String?
        let fullName: String?
        let lineNo: String?
        let color: String?
    }
}

struct CheLaileLineDetailResponse: Decodable {
    let line: Line?
    let stations: [Station]?

    struct Line: Decodable {
        let lineId: String?
        let name: String?
        let direction: Int?
        let startSn: String?
        let endSn: String?
        let firstTime: String?
        let lastTime: String?
        let price: String?
        let stationsNum: Int?
    }

    struct Station: Decodable {
        let order: Int?
        let sId: String?
        let sn: String?
        let wgsLat: Double?
        let wgsLng: Double?
        let physicalStId: String?
        let namesakeStId: String?
    }
}

/// A line entry as embedded in nearby / stop-detail responses.
struct CheLaileLineItem: Decodable {
    let line: Line?
    let preArrivalTime: String?
    let targetStation: TargetStation?
    let stnStates: [Bus]?

    struct Line: Decodable {
        let lineId: String?
        let name: String?
        let direction: Int?
        let startSn: String?
        let endSn: String?
        let firstTime: String?
        let lastTime: String?
        let price: String?
        let shortDesc: String?
        let nextOperationTimeDesc: String?
    }

    struct TargetStation: Decodable {
        let sId: String?
        let sn: String?
        let order: Int?
    }

    struct Bus: Decodable {
        let busId: String?
        let order: Int?
        let arrivalTime: Double?
        let travelTime: Int?
        let capacity: Int?
    }
}
