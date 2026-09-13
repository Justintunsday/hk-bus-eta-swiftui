import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    /// Active region. Everything region-specific goes through this provider.
    let provider: any TransitProvider
    let data: DataStore
    let bookmarks: BookmarkStore
    let location: LocationService

    init(provider: any TransitProvider = HongKongProvider()) {
        self.provider = provider
        settings = AppSettings()
        data = DataStore(provider: provider)
        bookmarks = BookmarkStore()
        location = LocationService()
        RegionClock.timeZone = provider.timeZone
    }
}
