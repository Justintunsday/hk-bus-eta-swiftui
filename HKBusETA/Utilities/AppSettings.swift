import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var language: AppLanguage = .system
    var etaFormat: EtaFormat = .mixed
    var annotateScheduled: Bool = true
    /// `RegionCatalog.autoID` or a `TransitRegion.id`.
    var selectedRegionID: String = RegionCatalog.autoID

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "settings.language"
        static let etaFormat = "settings.etaFormat"
        static let annotateScheduled = "settings.annotateScheduled"
        static let regionID = "settings.regionID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        etaFormat = EtaFormat(rawValue: defaults.string(forKey: Keys.etaFormat) ?? "") ?? .mixed
        annotateScheduled = defaults.object(forKey: Keys.annotateScheduled) as? Bool ?? true
        selectedRegionID = defaults.string(forKey: Keys.regionID) ?? RegionCatalog.autoID
        AppLanguage.current = language
    }

    func persist() {
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(etaFormat.rawValue, forKey: Keys.etaFormat)
        defaults.set(annotateScheduled, forKey: Keys.annotateScheduled)
        defaults.set(selectedRegionID, forKey: Keys.regionID)
        AppLanguage.current = language
    }
}
