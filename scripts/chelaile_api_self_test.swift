import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct LegacyFallbackFixture: MainlandTransitProvider, MainlandRealtimeProvider {
    let city = MainlandCityIdentifier(name: "Fixture", adcode: "310000", citycode: "034")
    var id: String { "legacy-fixture" }
    var regionName: String { "Fixture" }
    var timeZone: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    var dataSource: MainlandDataSource { .legacyFallback }
    var supportsRealtimeETAs: Bool { true }

    func search(keyword: String) async throws -> MainlandSearchResults {
        MainlandSearchResults(lines: [fixtureLine(source: .legacyFallback)])
    }

    func nearby(latitude: Double, longitude: Double, limit: Int) async throws -> [MainlandNearbyStop] { [] }
    func stopBoard(stopID: String, namesakeStopID: String?) async throws -> MainlandStopBoardResult { MainlandStopBoardResult() }
    func linePayload(lineID: String, modeHint: MainlandTransitMode?) async throws -> MainlandLinePayload? { nil }

    func fetchEtas(
        lineID: String,
        stopID: String,
        stopSequence: Int?,
        latitude: Double?,
        longitude: Double?,
        source: MainlandDataSource?,
        language: AppLanguage,
        modeHint: MainlandTransitMode?
    ) async throws -> [Eta] { [] }

    private func fixtureLine(source: MainlandDataSource) -> MainlandLineSummary {
        MainlandLineSummary(
            id: "legacy-line-0",
            lineID: "legacy-line",
            name: "Legacy",
            origin: "A",
            destination: "B",
            operatorName: nil,
            mode: .bus,
            serviceStatus: nil,
            firstDeparture: nil,
            lastDeparture: nil,
            fare: nil,
            city: city,
            source: source
        )
    }
}

private struct FixtureTransport: CheLaileAPITransport, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> CheLaileAPITransportResponse {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/search") {
            return .init(data: Data(searchJSON.utf8), statusCode: 200)
        }
        if path.hasSuffix("/stops/nearby") {
            return .init(data: Data(nearbyJSON.utf8), statusCode: 200)
        }
        if path.hasSuffix("/stops/detail") {
            return .init(data: Data(stopDetailJSON.utf8), statusCode: 200)
        }
        if path.hasSuffix("/lines/detail") {
            return .init(data: Data(lineDetailJSON.utf8), statusCode: 200)
        }
        if path.hasSuffix("/lines/realtime") {
            precondition(request.url?.query?.contains("target_order=2") == true)
            precondition(request.url?.query?.contains("station_id=034-2") == true)
            precondition(request.url?.query?.contains("lat=31.230000") == true)
            return .init(data: Data(realtimeJSON.utf8), statusCode: 200)
        }
        preconditionFailure("Unexpected fixture URL: \(path)")
    }

    private var searchJSON: String {
        #"{"lines":[{"name":"71","lineNo":"r71","isSubway":false,"directions":[{"direction":0,"lineId":"line-0","startSn":"起点","endSn":"终点"},{"direction":1,"lineId":"line-1","startSn":"终点","endSn":"起点"}]}],"stations":[{"sId":"034-2","sn":"人民路","lat":31.23,"lng":121.47,"physicalStId":"physical-2","namesakeStId":"namesake-2","isSubway":false}]}"#
    }

    private var nearbyJSON: String {
        #"{"stops":[{"sId":"034-2","sn":"人民路","distance":87,"lat":31.23,"lng":121.47,"physicalStId":"physical-2","namesakeStId":"namesake-2","isSubway":false,"lines":[{"lineId":"line-0","name":"71","endSn":"终点","targetOrder":2,"targetStationId":"034-2","buses":[{"travelTime":90,"arrivalTime":-1}]}],"subwayLines":[] }]}"#
    }

    private var stopDetailJSON: String {
        #"{"stations":[{"sId":"034-2","sn":"人民路","lat":31.23,"lng":121.47,"lines":[{"lineId":"line-0","name":"71","direction":0,"endSn":"终点","targetOrder":2,"status":"正常","buses":[{"travelTime":90,"arrivalTime":-1}]}],"metros":[{"lineId":"metro-2","name":"地铁2号线","lineNo":"2号线","color":"140,194,32"}]}]}"#
    }

    private var lineDetailJSON: String {
        #"{"line":{"lineId":"line-0","name":"71","startSn":"起点","endSn":"终点","firstTime":"05:30","lastTime":"23:30","price":"2元"},"stations":[{"order":1,"sId":"034-1","sn":"起点","wgsLat":31.22,"wgsLng":121.46,"physicalStId":"physical-1","namesakeStId":"namesake-1"},{"order":2,"sId":"034-2","sn":"人民路","wgsLat":31.23,"wgsLng":121.47,"physicalStId":"physical-2","namesakeStId":"namesake-2"}],"empty":false}"#
    }

    private var realtimeJSON: String {
        #"{"line":{"lineId":"line-0","name":"71","endSn":"终点"},"targetOrder":2,"realData":true,"buses":[{"order":2,"eta":{"travelTime":90,"arrivalTime":-1,"displayTime":"10:14"}},{"order":3,"eta":null}]}"#
    }
}

private struct FailingTransport: CheLaileAPITransport, @unchecked Sendable {
    let status: Int

    func data(for request: URLRequest) async throws -> CheLaileAPITransportResponse {
        let body = status == 400
            ? #"{"error":{"code":"INVALID_PARAMETER","message":"bad city_id","details":{"field":"city_id"}}}"#
            : #"{"error":{"code":"UPSTREAM_ERROR","message":"upstream unavailable"}}"#
        return .init(data: Data(body.utf8), statusCode: status)
    }
}

@main
struct CheLaileAPISelfTest {
    static func main() async {
        do {
            let city = MainlandCityIdentifier(name: "Fixture", adcode: "310000", citycode: "034")
            let client = CheLaileAPIClient(
                baseURL: URL(string: "https://fixture.example/v1"),
                apiKey: "fixture-key",
                transport: FixtureTransport()
            )
            let provider = CheLaileAPIProvider(
                cityId: "034",
                cityName: "Fixture",
                adcode: "310000",
                client: client
            )

            let search = try await provider.search(keyword: "71")
            precondition(search.lines.count == 2, "Search directions must be flattened")
            precondition(search.lines.map(\.lineID) == ["line-0", "line-1"])
            precondition(search.stops.first?.stopID == "physical-2", "Search stop must use physicalStId")
            precondition(search.stops.first?.source == .chelaileAPI)

            let nearby = try await provider.nearby(latitude: 31.23, longitude: 121.47, limit: 5)
            precondition(nearby.count == 1)
            precondition(nearby[0].stopID == "physical-2")
            precondition(nearby[0].arrivals.first?.minutes == 2)

            let board = try await provider.stopBoard(stopID: "physical-2", namesakeStopID: "namesake-2")
            precondition(board.rows.first?.lineID == "line-0")
            precondition(board.rows.first?.targetStopSequence == 2)
            precondition(board.rows.first?.minutes == [2])
            precondition(board.otherLines.first?.mode == .metro)
            precondition(board.location?.lat == 31.23)

            let payload = try await provider.linePayload(lineID: "line-0", modeHint: .bus)
            precondition(payload?.stops.map(\.stopID) == ["physical-1", "physical-2"], "Route IDs must remain physicalStId for legacy fallback")
            precondition(payload?.stops.allSatisfy { $0.location?.system == .wgs84 } == true)

            let etas = try await provider.fetchEtas(
                lineID: "line-0",
                stopID: "physical-2",
                stopSequence: 1,
                latitude: 31.23,
                longitude: 121.47,
                source: .chelaileAPI,
                language: .zhHans,
                modeHint: .bus
            )
            precondition(etas.count == 1)
            precondition(etas[0].co == "chelaile-api")

            let fallback = LegacyFallbackFixture()
            let failingPrimary = CheLaileAPIProvider(
                cityId: "034",
                cityName: "Fixture",
                client: CheLaileAPIClient(
                    baseURL: URL(string: "https://fixture.example/v1"),
                    transport: FailingTransport(status: 503)
                )
            )
            let routed = MainlandProviderRouter(
                primary: failingPrimary,
                fallback: fallback,
                realtime: failingPrimary
            )
            let fallbackResult = try await routed.search(keyword: "71")
            precondition(fallbackResult.lines.first?.source == .legacyFallback, "503 must use legacy fallback")

            let invalidPrimary = CheLaileAPIProvider(
                cityId: "034",
                cityName: "Fixture",
                client: CheLaileAPIClient(
                    baseURL: URL(string: "https://fixture.example/v1"),
                    transport: FailingTransport(status: 400)
                )
            )
            let invalidRouter = MainlandProviderRouter(primary: invalidPrimary, fallback: fallback)
            do {
                _ = try await invalidRouter.search(keyword: "71")
                preconditionFailure("400 parameter errors must not fall back")
            } catch let error as CheLaileAPIError {
                guard case let .apiError(statusCode, code, _, _) = error,
                      statusCode == 400, code == "INVALID_PARAMETER" else {
                    preconditionFailure("Unexpected 400 mapping: \(error)")
                }
                precondition(!error.isFallbackEligible)
            }

            precondition(CheLaileAPIClient.resolveAPIKey(environment: ["CHELAILE_API_KEY": "fixture-key"]) == "fixture-key")
            precondition(CheLaileAPIClient.resolveBaseURL(environment: ["CHELAILE_API_BASE_URL": "https://example.com/v1"])?.path == "/v1")
            precondition(CheLaileAPIClient.resolveBaseURL(environment: ["CHELAILE_API_BASE_URL": "$(CHELAILE_API_BASE_URL)"]) == CheLaileAPIClient.defaultBaseURL)
            precondition(CheLaileAPIClient.resolveBaseURL(environment: ["CHELAILE_API_BASE_URL": ""]) == CheLaileAPIClient.defaultBaseURL)
            precondition(CheLaileAPIClient.resolveBaseURL(environment: ["CHELAILE_API_BASE_URL": "not a URL"]) == nil)
            precondition(city.preferredCode == "310000")
            print("CHELAILE API SELF-TEST OK")
        } catch {
            fatalError("CHELAILE API SELF-TEST FAILED: \(error)")
        }
    }
}
