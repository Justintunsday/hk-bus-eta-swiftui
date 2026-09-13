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

struct MainlandLineTarget: Hashable {
    let lineId: String
    let title: String
    /// When non-nil the loader pushes the ETA screen at this stop sequence.
    let seq: Int?
}

struct MainlandStopTarget: Hashable {
    let stopID: String
    let namesakeStopID: String?
    let title: String
}

struct MainlandMetroTarget: Hashable {
    let name: String
    let origin: String
    let destination: String
}
