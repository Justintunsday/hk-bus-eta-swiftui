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

    func linePayload(
        lineID: String,
        modeHint: MainlandTransitMode?
    ) async throws -> MainlandLinePayload? { nil }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
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

            let city = MainlandCityIdentifier(name: "fixture", adcode: "310000", citycode: "021")
            let busLine = MainlandLineSummary(
                id: "bus",
                lineID: "bus",
                name: "Bus",
                origin: "A",
                destination: "B",
                operatorName: nil,
                mode: .bus,
                serviceStatus: nil,
                firstDeparture: nil,
                lastDeparture: nil,
                fare: nil,
                city: city,
                source: .amapBase
            )
            let metroLine = MainlandLineSummary(
                id: "metro",
                lineID: "metro",
                name: "Metro",
                origin: "C",
                destination: "D",
                operatorName: nil,
                mode: .metro,
                serviceStatus: nil,
                firstDeparture: nil,
                lastDeparture: nil,
                fare: nil,
                city: city,
                source: .amapBase
            )
            let stop = MainlandStopSummary(
                id: "stop",
                stopID: "stop",
                namesakeStopID: nil,
                name: "Stop",
                subtitle: nil,
                location: nil,
                city: city,
                source: .amapBase
            )
            let mixedResults = MainlandSearchResults(
                lines: [busLine, metroLine],
                stops: [stop]
            )
            precondition(MainlandSearchFiltering.apply(.all, to: mixedResults).lines.count == 2)
            precondition(MainlandSearchFiltering.apply(.bus, to: mixedResults).lines.map(\.mode) == [.bus])
            precondition(MainlandSearchFiltering.apply(.bus, to: mixedResults).stops.count == 1)
            precondition(MainlandSearchFiltering.apply(.mtr, to: mixedResults).lines.map(\.mode) == [.metro])
            precondition(MainlandSearchFiltering.apply(.mtr, to: mixedResults).stops.isEmpty)
            precondition(MainlandSearchFiltering.apply(.minibus, to: mixedResults) == .empty)
            precondition(MainlandSearchFiltering.apply(.lightRail, to: mixedResults) == .empty)
            precondition(MainlandSearchFiltering.apply(.ferry, to: mixedResults) == .empty)
            precondition(!MainlandSearchFiltering.isSupported(.minibus))
            precondition(MainlandSearchFiltering.isSupported(.mtr))
            precondition(MainlandRealtimePolicy.allowsRequest(modeHint: .bus))
            precondition(!MainlandRealtimePolicy.allowsRequest(modeHint: .metro))

            let payload = MainlandLinePayload(
                line: metroLine,
                stops: [stop],
                polyline: [],
                coordinateSystem: .wgs84,
                source: .legacyFallback
            )
            precondition(payload.applying(modeHint: .metro).line.mode == .metro)
            precondition(payload.applying(modeHint: .metro).stops == [stop])
            precondition(payload.routeMetadata.firstDeparture == nil)

            let metroLink = MainlandTransitLine(id: "metro-id", name: "Metro", mode: .metro)
            precondition(metroLink.lineID == "metro-id")

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
            let hintedClient = try AMapClient(
                apiKey: "fixture-key",
                transport: AMapClosureTransport { _ in
                    AMapTransportResponse(data: AMapOfflineFixture.lineResponse, statusCode: 200)
                }
            )
            let hintedProvider = AMapTransitProvider(client: hintedClient, city: city, regionName: "fixture")
            let hintedPayload = try await hintedProvider.linePayload(
                lineID: "fixture-line-1",
                modeHint: .metro
            )
            precondition(hintedPayload?.line.mode == .metro)
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
