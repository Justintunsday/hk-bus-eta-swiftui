import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    let data: DataStore
    let bookmarks: BookmarkStore
    let location: LocationService

    init() {
        settings = AppSettings()
        data = DataStore()
        bookmarks = BookmarkStore()
        location = LocationService()
    }
}
