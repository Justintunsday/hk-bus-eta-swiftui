import Foundation

/// A transit operator (company) in a region.
///
/// Replaces the old hardcoded `Company` enum so that new regions can register
/// their own operators without touching the UI layer.
struct TransitOperator: Identifiable, Hashable, Sendable {
    let id: String
    /// Locale code -> display name, e.g. ["en": "KMB", "zh-Hant": "九巴"].
    let names: [String: String]
    let brandHex: UInt32
    let onBrandHex: UInt32
    let isFerry: Bool
    let logoAsset: String?

    func name(_ language: AppLanguage) -> String {
        if let direct = names[language.localeCode] {
            return direct
        }
        if language == .zhHans, let traditional = names["zh-Hant"] {
            return ChineseConverter.simplified(traditional)
        }
        if let english = names["en"] {
            return english
        }
        return names.values.first ?? id
    }
}

/// All operators of one region, keyed by id.
struct OperatorRegistry: Sendable {
    let operators: [String: TransitOperator]

    func op(_ id: String) -> TransitOperator? {
        operators[id]
    }

    func name(_ id: String, _ language: AppLanguage) -> String {
        operators[id]?.name(language) ?? id
    }
}

/// Generic transport category used by the search filter UI.
/// The mapping to concrete operator ids is region-specific.
enum TransportFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case bus
    case minibus
    case lightRail
    case mtr
    case ferry

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        let zh = language.isChinese
        switch self {
        case .all: return zh ? "全部" : "All"
        case .bus: return zh ? "巴士" : "Bus"
        case .minibus: return zh ? "小巴" : "Minibus"
        case .lightRail: return zh ? "輕鐵" : "Light Rail"
        case .mtr: return zh ? "港鐵" : "MTR"
        case .ferry: return zh ? "渡輪" : "Ferry"
        }
    }
}
