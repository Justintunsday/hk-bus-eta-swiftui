import Foundation

private struct FallbackProbeProvider: MainlandTransitProvider {
    let city = MainlandCityIdentifier(name: "fixture", adcode: "310000", citycode: "021")
    let probeResult: MainlandSearchResults

    var id: String { "fixture-fallback" }
    var regionName: String { "fixture" }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    var dataSource: MainlandDataSource { .legacyFallback }
    var supportsRealtimeETAs: Bool { false }

    func search(keyword: String) async throws -> MainlandSearchResults { probeResult }

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] { [] }

    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult {
        MainlandStopBoardResult()
    }

    func linePayload(lineID: String) async throws -> MainlandLinePayload? { nil }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        language: AppLanguage
    ) async throws -> [Eta] { [] }
}

@main
struct MainlandSelfTest {
    static func main() async {
        do {
            let lineResponse = try AMapClient.decodeLineResponse(AMapOfflineFixture.lineResponse)
            precondition(lineResponse.lines.count == 1)
            precondition(lineResponse.lines[0].stops.count == 1)
            precondition(lineResponse.lines[0].polyline.count == 2)
            precondition(lineResponse.lines[0].polyline[0].system == .gcj02)

            let stopResponse = try AMapClient.decodeStopResponse(AMapOfflineFixture.stopResponse)
            precondition(stopResponse.stops.first?.citycode == "021")
            precondition(stopResponse.stops.first?.lineReferences.count == 1)

            do {
                _ = try AMapClient.decodeLineResponse(AMapOfflineFixture.apiErrorResponse)
                preconditionFailure("AMap API error was not surfaced")
            } catch let error as AMapError {
                guard case .apiError = error else {
                    preconditionFailure("Unexpected AMap error mapping: \(error)")
                }
            }

            let url = try AMapClient.makeURL(
                endpoint: .lineName,
                apiKey: "fixture-key",
                parameters: [("keywords", "1 路")]
            )
            precondition(url.absoluteString.contains("keywords=1%20%E8%B7%AF"))
            precondition(AMapClient.resolveAPIKey(environment: ["AMAP_WEB_SERVICE_KEY": " env-key"]) == "env-key")

            let city = MainlandCityIdentifier(name: "fixture", adcode: "310000", citycode: "021")
            let client = try AMapClient(
                apiKey: "fixture-key",
                transport: AMapClosureTransport { request in
                    let body = request.url?.path.contains("linename") == true
                        ? AMapOfflineFixture.apiErrorResponse
                        : AMapOfflineFixture.stopResponse
                    return AMapTransportResponse(data: body, statusCode: 200)
                }
            )
            let primary = AMapTransitProvider(client: client, city: city, regionName: "fixture")
            let expected = MainlandSearchResults(
                lines: [MainlandLineSummary(
                    id: "fallback",
                    lineID: "fallback",
                    name: "Fallback",
                    origin: "A",
                    destination: "B",
                    operatorName: nil,
                    mode: .bus,
                    serviceStatus: nil,
                    firstDeparture: nil,
                    lastDeparture: nil,
                    fare: nil,
                    city: city,
                    source: .legacyFallback
                )]
            )
            let router = MainlandProviderRouter(
                primary: primary,
                fallback: FallbackProbeProvider(probeResult: expected)
            )
            let routed = try await router.search(keyword: "1")
            precondition(routed.lines.first?.id == "fallback")
            precondition(MainlandProviderError.unsupported(.nearby).isFallbackEligible)
            precondition(!MainlandProviderError.invalidRequest("bad input").isFallbackEligible)

            print("MAINLAND SELF-TEST OK")
        } catch {
            fatalError("MAINLAND SELF-TEST FAILED: \(error)")
        }
    }
}
