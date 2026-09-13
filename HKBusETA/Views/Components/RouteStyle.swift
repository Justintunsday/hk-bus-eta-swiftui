import SwiftUI

struct RouteColorInfo {
    let background: Color
    let foreground: Color
}

enum RouteStyle {
    static func info(for entry: RouteEntry, provider: any TransitProvider) -> RouteColorInfo {
        let hex = provider.routeColorHex(entry: entry)
        return RouteColorInfo(background: Color(hex: hex), foreground: textColor(for: hex))
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
    @Environment(AppState.self) private var app
    let route: String
    let entry: RouteEntry?
    var fontSize: CGFloat = 17

    private var info: RouteColorInfo {
        if let entry {
            return RouteStyle.info(for: entry, provider: app.provider)
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
