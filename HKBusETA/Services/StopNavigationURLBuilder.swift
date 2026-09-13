import Foundation

/// The navigation app must match the coordinate reference system supplied by
/// the transit data source. In particular, GCJ-02 must never be interpreted
/// as a WGS-84 coordinate by MapKit.
enum StopNavigationStrategy: String, Hashable, Sendable {
    case appleMapsWalking
    case amapWalking
}

enum StopNavigationURLBuilder {
    static let amapSourceApplication = "Where My Bus Now"

    static func strategy(for location: StopLocation) -> StopNavigationStrategy {
        switch location.coordinateSystem {
        case .wgs84:
            return .appleMapsWalking
        case .gcj02:
            return .amapWalking
        }
    }

    /// Builds the official AMap iOS URI for walking from the user's current
    /// location. No start point is included intentionally: AMap resolves it
    /// from the device's current location.
    static func makeAMapURL(for location: StopLocation, localizedName: String) -> URL? {
        guard location.coordinateSystem == .gcj02, location.isValid else { return nil }

        var components = URLComponents()
        components.scheme = "iosamap"
        components.host = "path"
        components.queryItems = [
            URLQueryItem(name: "sourceApplication", value: amapSourceApplication),
            URLQueryItem(name: "dlat", value: coordinateString(location.lat)),
            URLQueryItem(name: "dlon", value: coordinateString(location.lng)),
            URLQueryItem(name: "dname", value: localizedName),
            URLQueryItem(name: "dev", value: "0"),
            URLQueryItem(name: "t", value: "2")
        ]
        return components.url
    }

    private static func coordinateString(_ value: Double) -> String {
        var result = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
        while result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }
}
