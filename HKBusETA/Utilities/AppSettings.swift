import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var language: AppLanguage = .system
    var etaFormat: EtaFormat = .mixed
    var annotateScheduled: Bool = true

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "settings.language"
        static let etaFormat = "settings.etaFormat"
        static let annotateScheduled = "settings.annotateScheduled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        etaFormat = EtaFormat(rawValue: defaults.string(forKey: Keys.etaFormat) ?? "") ?? .mixed
        annotateScheduled = defaults.object(forKey: Keys.annotateScheduled) as? Bool ?? true
        AppLanguage.current = language
    }

    func persist() {
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(etaFormat.rawValue, forKey: Keys.etaFormat)
        defaults.set(annotateScheduled, forKey: Keys.annotateScheduled)
        AppLanguage.current = language
    }
}
