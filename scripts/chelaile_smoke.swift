import Foundation

/// Network smoke test for the production CheLaile client.
/// Run on macOS CI: it exercises search (plain), line detail (encrypted)
/// and stop detail (encrypted) against the live API.
@main
struct CheLaileSmoke {
    static func main() async {
        let client = CheLaileClient()
        let cityId = "014" // Shenzhen

        do {
            let search = try await client.search(cityId: cityId, keyword: "M133")
            let lines = search.result?.lines ?? []
            print("search lines:", lines.count)
            for line in lines.prefix(3) {
                print(" -", line.name ?? "?", "id=", line.lineId ?? "?", "subwayV2=", line.subwayV2 ?? -1)
            }

            guard let lineId = lines.first(where: { $0.subwayV2 != 1 })?.lineId else {
                print("SMOKE: no bus line found")
                return
            }

            let detail = try await client.lineDetail(cityId: cityId, lineId: lineId, lat: nil, lng: nil)
            print("line detail:", detail.line?.name ?? "nil", "stations:", detail.stations?.count ?? -1)
            if let first = detail.stations?.first {
                print("first station:", first.sn ?? "?", first.physicalStId ?? "?")
            }

            if let physical = detail.stations?.first?.physicalStId {
                let board = try await client.stopDetail(cityId: cityId, physicalStId: physical, namesakeStId: nil, lat: nil, lng: nil)
                print("stop detail stations:", board.stationList?.count ?? -1)
            }

            let nearby = try await client.nearby(cityId: cityId, lat: 22.5431, lng: 114.0579)
            print("nearby stops:", nearby.nearSts?.count ?? -1)

            print("SMOKE OK")
        } catch {
            print("SMOKE FAILED:", error)
        }
    }
}
