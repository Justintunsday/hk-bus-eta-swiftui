import SwiftUI

struct RouteDetailTarget: Hashable {
    let routeKey: String
}

struct RouteEtaTarget: Hashable {
    let routeKey: String
    let seq: Int
}

struct StopTarget: Hashable {
    let stopId: String
}

struct CheLaileLineTarget: Hashable {
    let lineId: String
    let title: String
    /// When non-nil the loader pushes the ETA screen at this stop sequence.
    let seq: Int?
}

struct CheLaileStopTarget: Hashable {
    let physicalStId: String
    let namesakeStId: String?
    let title: String
}
