import Foundation

/// A favorite selected for the Home / Lock Screen widget.
///
/// Stored in the shared App Group container: the app writes it, the widget
/// reads it. Kept deliberately small — no app models leak into the widget.
struct WidgetPinnedItem: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Hashable, Sendable {
        case route
        case stop
    }

    var id: String
    var kind: Kind
    var regionID: String
    /// Route number for route pins, stop name for stop pins.
    var title: String
    /// Route origin (route pins) or stop subtitle (stop pins).
    var origin: String
    /// Route destination; empty for stop pins.
    var destination: String
    /// Route number of the soonest arrival (stop pins).
    var arrivalLabel: String?
    var lineID: String?
    var stopID: String?
    var targetSequence: Int?
    var modeRawValue: String?
    /// Upcoming arrivals, soonest first (up to three).
    var etas: [Date]
    var updatedAt: Date?

    var nextArrival: Date? {
        etas.first { $0 > Date() } ?? etas.first
    }
}

struct WidgetSnapshot: Codable, Hashable, Sendable {
    var items: [WidgetPinnedItem] = []
    var updatedAt: Date?

    /// Items ordered by soonest known arrival so a small widget always shows
    /// the most useful pin.
    var orderedByArrival: [WidgetPinnedItem] {
        items.sorted { lhs, rhs in
            switch (lhs.nextArrival, rhs.nextArrival) {
            case let (left?, right?): return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.title < rhs.title
            }
        }
    }
}

enum WidgetSharedStore {
    static let appGroupID = "group.app.hkbus.swiftui"
    static let widgetKind = "RouteCountdownWidget"
    private static let snapshotKey = "widget.snapshot.v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func removeAll() {
        defaults?.removeObject(forKey: snapshotKey)
    }
}

/// Warm Minimal accent shared with the widget (the app's DesignTokens file is
/// not part of the widget target).
enum WidgetPalette {
    static let accentHex: UInt32 = 0xE85D3A
}

/// Small bilingual helper: the widget has no string catalog.
enum WidgetL10n {
    static var isChinese: Bool {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
    }

    static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// The app's Warm Minimal coral accent, shared with the widget.
enum WidgetAccent {
    static var color: Color {
        Color(.sRGB, red: 0.910, green: 0.365, blue: 0.227, opacity: 1)
    }
}
#endif

