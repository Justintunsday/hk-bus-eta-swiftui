import CoreLocation
import Foundation

/// One selectable region in the app.
struct TransitRegion: Identifiable, Hashable, Sendable {
    enum Backend: Hashable, Sendable {
        case hongKong
        case chelaile(cityId: String)
    }

    let id: String
    let name: String
    let subtitle: String
    let backend: Backend
    let centerLat: Double
    let centerLng: Double

    var timeZone: TimeZone {
        switch backend {
        case .hongKong: return TimeZone(identifier: "Asia/Hong_Kong")!
        case .chelaile: return TimeZone(identifier: "Asia/Shanghai")!
        }
    }

    var center: CLLocation {
        CLLocation(latitude: centerLat, longitude: centerLng)
    }

    var isQueryMode: Bool {
        if case .chelaile = backend { return true }
        return false
    }
}

/// Bundled region list: Hong Kong plus the hot-city set supported by the
/// 车来了 API. Auto mode picks the nearest city to the device location.
enum RegionCatalog {
    static let autoID = "auto"
    static let hongKong = TransitRegion(
        id: "hk",
        name: "香港",
        subtitle: "九巴 · 城巴 · 嶼巴 · 港鐵巴士 · 輕鐵 · 港鐵 · 渡輪",
        backend: .hongKong,
        centerLat: 22.3193,
        centerLng: 114.1694
    )

    static let chelaileCities: [TransitRegion] = [
        TransitRegion(id: "cl-014", name: "深圳", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "014"), centerLat: 22.5431, centerLng: 114.0579),
        TransitRegion(id: "cl-040", name: "廣州", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "040"), centerLat: 23.1291, centerLng: 113.2644),
        TransitRegion(id: "cl-034", name: "上海", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "034"), centerLat: 31.2304, centerLng: 121.4737),
        TransitRegion(id: "cl-027", name: "北京", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "027"), centerLat: 39.9042, centerLng: 116.4074),
        TransitRegion(id: "cl-006", name: "天津", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "006"), centerLat: 39.3434, centerLng: 117.3616),
        TransitRegion(id: "cl-003", name: "重慶", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "003"), centerLat: 29.5630, centerLng: 106.5516),
        TransitRegion(id: "cl-007", name: "成都", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "007"), centerLat: 30.5728, centerLng: 104.0668),
        TransitRegion(id: "cl-019", name: "佛山", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "019"), centerLat: 23.0218, centerLng: 113.1219),
        TransitRegion(id: "cl-009", name: "青島", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "009"), centerLat: 36.0671, centerLng: 120.3826),
        TransitRegion(id: "cl-035", name: "瀋陽", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "035"), centerLat: 41.8057, centerLng: 123.4315),
        TransitRegion(id: "cl-018", name: "南京", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "018"), centerLat: 32.0603, centerLng: 118.7969),
        TransitRegion(id: "cl-076", name: "西安", subtitle: "車來了 · 公交地鐵", backend: .chelaile(cityId: "076"), centerLat: 34.3416, centerLng: 108.9398),
    ]

    static var all: [TransitRegion] { [hongKong] + chelaileCities }

    static func region(for id: String) -> TransitRegion? {
        all.first { $0.id == id }
    }

    /// Nearest region to a location; the Hong Kong metro area wins inside a
    /// 40 km radius so border readings don't flip to Shenzhen.
    static func nearest(to location: CLLocation) -> TransitRegion {
        if location.distance(from: hongKong.center) < 40_000 { return hongKong }
        return all.min {
            location.distance(from: $0.center) < location.distance(from: $1.center)
        } ?? hongKong
    }

    static func provider(for region: TransitRegion) -> any TransitProvider {
        switch region.backend {
        case .hongKong:
            return HongKongProvider()
        case .chelaile(let cityId):
            return CheLaileProvider(cityId: cityId, cityName: region.name)
        }
    }
}
