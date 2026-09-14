import Foundation

private struct LegacyPinnedItem: Encodable {
    let id: String
    let kind: String
    let regionID: String
    let title: String
    let origin: String
    let destination: String
    let arrivalLabel: String?
    let lineID: String?
    let stopID: String?
    let targetSequence: Int?
    let modeRawValue: String?
    let etas: [Date]
    let updatedAt: Date?
}

@main
struct WidgetSnapshotSelfTest {
    static func main() throws {
        let eta = Date().addingTimeInterval(300)
        let legacy = LegacyPinnedItem(
            id: "route:hk:fixture",
            kind: "route",
            regionID: "hk",
            title: "73A",
            origin: "Origin",
            destination: "Destination",
            arrivalLabel: "Nearest Stop",
            lineID: nil,
            stopID: "stop-1",
            targetSequence: 4,
            modeRawValue: "bus",
            etas: [eta],
            updatedAt: Date()
        )
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(WidgetPinnedItem.self, from: data)
        precondition(decoded.regionName == nil)
        precondition(decoded.stopID == "stop-1")
        precondition(decoded.targetSequence == 4)

        let enriched = WidgetPinnedItem(
            id: decoded.id,
            kind: decoded.kind,
            regionID: decoded.regionID,
            regionName: "香港",
            title: decoded.title,
            origin: decoded.origin,
            destination: decoded.destination,
            arrivalLabel: decoded.arrivalLabel,
            lineID: decoded.lineID,
            stopID: decoded.stopID,
            targetSequence: decoded.targetSequence,
            modeRawValue: decoded.modeRawValue,
            etas: decoded.etas,
            updatedAt: decoded.updatedAt
        )
        let roundTrip = try JSONDecoder().decode(
            WidgetPinnedItem.self,
            from: JSONEncoder().encode(enriched)
        )
        precondition(roundTrip.regionName == "香港")
        print("WIDGET SNAPSHOT SELF-TEST OK")
    }
}
