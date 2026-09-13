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
    let modeHint: MainlandTransitMode
    let origin: String?
    let destination: String?
    let firstDeparture: String?
    let lastDeparture: String?
    let fare: String?

    init(
        lineId: String,
        title: String,
        seq: Int? = nil,
        modeHint: MainlandTransitMode = .bus,
        origin: String? = nil,
        destination: String? = nil,
        firstDeparture: String? = nil,
        lastDeparture: String? = nil,
        fare: String? = nil
    ) {
        self.lineId = lineId
        self.title = title
        self.seq = seq
        self.modeHint = modeHint
        self.origin = origin
        self.destination = destination
        self.firstDeparture = firstDeparture
        self.lastDeparture = lastDeparture
        self.fare = fare
    }
}

struct MainlandStopTarget: Hashable {
    let stopID: String
    let namesakeStopID: String?
    let title: String
}
