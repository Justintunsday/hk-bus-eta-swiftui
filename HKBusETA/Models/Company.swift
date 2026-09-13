import SwiftUI

enum Company: String, Codable, CaseIterable, Sendable, Identifiable {
    case kmb
    case ctb
    case nlb
    case lrtfeeder
    case gmb
    case lightRail
    case mtr
    case sunferry
    case fortuneferry
    case hkkf

    var id: String { rawValue }

    var nameZh: String {
        switch self {
        case .kmb: return "九巴"
        case .ctb: return "城巴"
        case .nlb: return "嶼巴"
        case .lrtfeeder: return "港鐵巴士"
        case .gmb: return "綠色小巴"
        case .lightRail: return "輕鐵"
        case .mtr: return "港鐵"
        case .sunferry: return "新渡輪"
        case .fortuneferry: return "富裕小輪"
        case .hkkf: return "港九小輪"
        }
    }

    var nameEn: String {
        switch self {
        case .kmb: return "KMB"
        case .ctb: return "Citybus"
        case .nlb: return "NLB"
        case .lrtfeeder: return "MTR Bus"
        case .gmb: return "Minibus"
        case .lightRail: return "Light Rail"
        case .mtr: return "MTR"
        case .sunferry: return "Sun Ferry"
        case .fortuneferry: return "Fortune Ferry"
        case .hkkf: return "HK & KF"
        }
    }

    func name(_ language: AppLanguage) -> String {
        language == .zh ? nameZh : nameEn
    }

    var isFerry: Bool {
        self == .sunferry || self == .fortuneferry || self == .hkkf
    }

    /// Brand color, following hkbus.app conventions.
    var brandColor: Color {
        switch self {
        case .kmb: return Color(hex: 0xFF4747)
        case .ctb: return Color(hex: 0xFFE15E)
        case .nlb: return Color(hex: 0x26A69A)
        case .lrtfeeder: return Color(hex: 0x8AC4FF)
        case .gmb: return Color(hex: 0x36C94D)
        case .lightRail: return Color(hex: 0xD3A809)
        case .mtr: return Color(hex: 0x9C2E00)
        case .sunferry, .fortuneferry, .hkkf: return Color(hex: 0xFF4747)
        }
    }

    var textColorOnBrand: Color {
        switch self {
        case .ctb, .gmb, .lrtfeeder, .lightRail: return .black
        default: return .white
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum TransportFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case bus
    case minibus
    case lightRail
    case mtr
    case ferry

    var id: String { rawValue }

    var companies: Set<String> {
        switch self {
        case .all:
            return Set(Company.allCases.map(\.rawValue))
        case .bus:
            return ["kmb", "ctb", "nlb", "lrtfeeder"]
        case .minibus:
            return ["gmb"]
        case .lightRail:
            return ["lightRail"]
        case .mtr:
            return ["mtr"]
        case .ferry:
            return ["sunferry", "fortuneferry", "hkkf"]
        }
    }

    func title(_ language: AppLanguage) -> String {
        let zh = language.resolved == .zh
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
