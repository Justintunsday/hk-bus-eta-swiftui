import SwiftUI

struct RouteColorInfo {
    let background: Color
    let foreground: Color
}

enum RouteStyle {
    static func info(for entry: RouteEntry) -> RouteColorInfo {
        let hex = hexColor(for: entry)
        return RouteColorInfo(background: Color(hex: hex), foreground: textColor(for: hex))
    }

    static func hexColor(for entry: RouteEntry) -> UInt32 {
        let companies = entry.co
        if companies.first == "mtr" {
            switch entry.route {
            case "AEL": return 0x00888E
            case "TCL": return 0xF3982D
            case "TML": return 0x9C2E00
            case "TKL": return 0x7E3C93
            case "EAL": return 0x5EB7E8
            case "SIL": return 0xCBD300
            case "TWL": return 0xE60012
            case "ISL": return 0x0075C2
            case "KTL": return 0x00A040
            case "DRL": return 0xEB6EA5
            default: return 0xFF4747
            }
        }
        if companies.contains("lightRail") {
            switch entry.route {
            case "505": return 0xDA2127
            case "507": return 0x00A652
            case "610": return 0x551C15
            case "614": return 0x00BFF3
            case "614P": return 0xF4858E
            case "615": return 0xFFDD00
            case "615P": return 0x016682
            case "705": return 0x73BF43
            case "706": return 0xB47AB5
            case "751": return 0xF48221
            case "761P": return 0x6F2D91
            default: return 0xD3A809
            }
        }
        if companies.first?.hasPrefix("gmb") == true { return 0x36C94D }
        if companies.contains("lrtfeeder") { return 0x8AC4FF }
        if companies.contains("nlb") { return 0x26A69A }
        if companies.contains("kmb") { return 0xFF4747 }
        if companies.contains("ctb") { return 0xFFE15E }
        return 0xFF4747
    }

    static func textColor(for hex: UInt32) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.6 ? .black : .white
    }
}

struct RouteBadge: View {
    let route: String
    let entry: RouteEntry?
    var fontSize: CGFloat = 17

    private var info: RouteColorInfo {
        if let entry {
            return RouteStyle.info(for: entry)
        }
        return RouteColorInfo(background: Color(hex: 0xFF4747), foreground: .white)
    }

    var body: some View {
        Text(route)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(info.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(info.background, in: RoundedRectangle(cornerRadius: 7))
            .lineLimit(1)
    }
}

struct CompanyTags: View {
    let co: [String]
    let language: AppLanguage

    var body: some View {
        Text(co.compactMap { Company(rawValue: $0)?.name(language) }.joined(separator: "+"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
