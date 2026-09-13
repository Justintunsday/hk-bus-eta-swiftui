import CoreLocation
import Foundation

enum GeoUtils {
    static func distance(from a: StopLocation, to b: StopLocation) -> CLLocationDistance {
        CLLocation(latitude: a.lat, longitude: a.lng)
            .distance(from: CLLocation(latitude: b.lat, longitude: b.lng))
    }

    static func distance(from a: CLLocation, to b: StopLocation) -> CLLocationDistance {
        a.distance(from: CLLocation(latitude: b.lat, longitude: b.lng))
    }

    static func distanceString(_ meters: CLLocationDistance, language: AppLanguage) -> String {
        if meters < 1000 {
            return "\(Int(round(meters / 10) * 10)) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}
