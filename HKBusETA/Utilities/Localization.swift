import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zh
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("settings.language.system")
        case .zh: return "繁體中文"
        case .en: return "English"
        }
    }

    /// The language actually used for data and UI strings.
    var resolved: AppLanguage {
        if self != .system { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }

    var locale: Locale {
        switch resolved {
        case .zh: return Locale(identifier: "zh_Hant_HK")
        case .en: return Locale(identifier: "en_HK")
        case .system: return Locale.current
        }
    }

    /// Strings table code, or nil to use the system default.
    var bundleCode: String? {
        switch resolved {
        case .zh: return "zh-Hant"
        case .en: return nil
        case .system: return nil
        }
    }
}

enum EtaFormat: String, CaseIterable, Identifiable, Sendable {
    case diff
    case exact
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diff: return L10n.t("settings.etaFormat.diff")
        case .exact: return L10n.t("settings.etaFormat.exact")
        case .mixed: return L10n.t("settings.etaFormat.mixed")
        }
    }
}

extension AppLanguage {
    /// Mirror of the user setting, updated by `AppSettings`, safe to read from any thread.
    nonisolated(unsafe) static var current: AppLanguage = .system
}

enum L10n {
    static func t(_ key: String) -> String {
        guard let code = AppLanguage.current.bundleCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return String(localized: String.LocalizationValue(key))
        }
        return String(localized: String.LocalizationValue(key), bundle: bundle)
    }

    /// Language actually used for data display.
    static var language: AppLanguage { AppLanguage.current.resolved }
}

enum HKTime {
    static let timeZone = TimeZone(identifier: "Asia/Hong_Kong")!

    static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    private static let isoFormatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func date(fromISO string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        for formatter in isoFormatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    static func isoString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func timeString(_ iso: String) -> String {
        guard let date = date(fromISO: iso) else {
            return iso.count >= 16 ? String(iso.dropFirst(11).prefix(5)) : iso
        }
        return timeString(date)
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    static func isHoliday(_ holidays: [String], date: Date = Date()) -> Bool {
        let components = calendar.dateComponents([.weekday], from: date)
        if components.weekday == 1 { return true }
        return holidays.contains(dayString(date))
    }

    /// Weekday index following the data convention: 0 = Sunday ... 6 = Saturday.
    static func weekdayIndex(_ date: Date = Date()) -> Int {
        let components = calendar.dateComponents([.weekday], from: date)
        return (components.weekday ?? 1) - 1
    }
}
