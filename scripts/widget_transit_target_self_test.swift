import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct FixtureTransport: WidgetTransitAPITransport, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> WidgetTransitAPITransportResponse {
        let host = request.url?.host ?? ""
        if host == "primary.example" {
            return WidgetTransitAPITransportResponse(data: Data(), statusCode: 503)
        }

        let path = request.url?.path ?? ""
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        if path.hasSuffix("/search") {
            let body = values["city_id"] == "019" ? foshanSearchJSON : shanghaiSearchJSON
            return WidgetTransitAPITransportResponse(data: Data(body.utf8), statusCode: 200)
        }
        if path.hasSuffix("/lines/detail") {
            let lineID = values["line_id"] ?? "line-0"
            return WidgetTransitAPITransportResponse(
                data: Data(lineDetailJSON(lineID: lineID).utf8),
                statusCode: 200
            )
        }
        if path.hasSuffix("/lines/realtime") {
            precondition(values["city_id"] == "034", "realtime must stay in the entity city")
            precondition(values["target_order"] == "2")
            precondition(values["station_id"] == "034-2")
            return WidgetTransitAPITransportResponse(
                data: Data(#"{"buses":[{"eta":{"travelTime":120,"arrivalTime":-1}}]}"#.utf8),
                statusCode: 200
            )
        }
        preconditionFailure("Unexpected widget API path: \(path)")
    }

    private var foshanSearchJSON: String {
        #"{"lines":[{"name":"352","lineNo":"352","directions":[{"direction":0,"lineId":"fs-352-0","startSn":"禅城","endSn":"南海"},{"direction":1,"lineId":"fs-352-1","startSn":"南海","endSn":"禅城"}]}],"stations":[]}"#
    }

    private var shanghaiSearchJSON: String {
        #"{"lines":[{"name":"71","lineNo":"71","directions":[{"direction":0,"lineId":"line-0","startSn":"人民广场","endSn":"外滩"},{"direction":1,"lineId":"line-1","startSn":"外滩","endSn":"人民广场"}]}],"stations":[]}"#
    }

    private func lineDetailJSON(lineID: String) -> String {
        let start = lineID == "line-1" ? "外滩" : lineID.hasPrefix("fs-") && lineID.hasSuffix("-1") ? "南海" : "人民广场"
        let end = lineID == "line-1" ? "人民广场" : lineID.hasPrefix("fs-") && lineID.hasSuffix("-1") ? "禅城" : "外滩"
        let stop = lineID.hasPrefix("fs-") ? "季华园" : "人民广场"
        let prefix = lineID.hasPrefix("fs-") ? "019" : "034"
        let name = lineID.hasPrefix("fs-") ? "352" : "71"
        return "{\"line\":{\"lineId\":\"\(lineID)\",\"name\":\"\(name)\",\"startSn\":\"\(start)\",\"endSn\":\"\(end)\"},\"stations\":[{\"order\":1,\"sId\":\"\(prefix)-1\",\"sn\":\"起点\",\"wgsLat\":31.2200,\"wgsLng\":121.4600,\"physicalStId\":\"\(prefix)-1\"},{\"order\":2,\"sId\":\"\(prefix)-2\",\"sn\":\"\(stop)\",\"wgsLat\":31.2300,\"wgsLng\":121.4700,\"physicalStId\":\"\(prefix)-2\"}],\"empty\":false}"
    }
}

@main
struct WidgetTransitTargetSelfTest {
    static func main() async {
        precondition(WidgetTransitQueryParser.parse("佛山 352")?.city.id == "019")
        precondition(WidgetTransitQueryParser.parse("上海 71 人民广场")?.city.id == "034")
        precondition(WidgetTransitQueryParser.parse("71") == nil, "a city is required")

        let record = WidgetTransitTargetRecord(
            cityID: "034",
            cityName: "上海",
            lineID: "line-0",
            lineName: "71",
            direction: 0,
            origin: "人民广场",
            destination: "外滩",
            stopID: "034-2",
            stopName: "人民广场",
            stationID: "034-2",
            stopSequence: 2,
            latitude: 31.23,
            longitude: 121.47
        )
        precondition(record.id.hasPrefix("wmbn-target-v1_"))
        let restored = WidgetTransitTargetRecord(id: record.id)
        precondition(restored == record, "entity ID must rebuild the full target")
        precondition(restored?.cityID == "034" && restored?.stopName == "人民广场")

        let client = WidgetTransitAPIClient(
            baseURLs: [
                URL(string: "https://primary.example/v1")!,
                URL(string: "https://fallback.example/v1")!,
            ],
            transport: FixtureTransport()
        )
        let resolver = WidgetTransitTargetResolver(client: client)
        let foshanTargets = await resolver.targets(for: "佛山 352")
        precondition(!foshanTargets.isEmpty)
        precondition(foshanTargets.allSatisfy { $0.cityID == "019" && $0.cityName == "佛山" })
        precondition(foshanTargets.contains { $0.direction == 1 && $0.destination == "禅城" })

        let shanghaiTargets = await resolver.targets(for: "上海 71 人民广场")
        precondition(!shanghaiTargets.isEmpty)
        precondition(shanghaiTargets.allSatisfy {
            $0.cityID == "034" && $0.cityName == "上海" && $0.lineName == "71" && $0.stopName == "人民广场"
        })
        let etaResult = await resolver.etaDates(for: record)
        precondition(etaResult.unavailable == false && etaResult.dates.count == 1)

        let url = try! WidgetTransitAPIClient.makeURL(
            baseURL: WidgetTransitAPIClient.primaryBaseURL,
            path: "lines/realtime",
            parameters: [("city_id", "034"), ("line_id", "line-0")]
        )
        precondition(url.absoluteString.contains("city_id=034"))
        print("SIDESTORE WIDGET TARGET SELF-TEST OK")
    }
}
