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
