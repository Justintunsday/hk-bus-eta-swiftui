import SwiftUI
import UIKit

/// Warm Minimal design system for HK Bus ETA.
///
/// Documented in `docs/brand-spec.md`. One warm coral accent, warm neutrals,
/// SF Rounded for numerals and route codes, 8pt spacing grid.
enum DesignTokens {
    // MARK: Colors

    /// Primary accent — warm coral. Interactive states, selection, links.
    static let accent = Color(hex: "E85D3A")
    /// Soft accent background for selections and badges.
    static let accentSoft = Color(light: "FBE9E2", dark: "3B241C")
    /// Text/icon color on top of the accent.
    static let onAccent = Color.white

    // Warm neutrals
    static let background = Color(light: "FAF9F7", dark: "1C1C1E")
    static let surface = Color(light: "FFFFFF", dark: "2C2C2E")
    static let surfaceMuted = Color(light: "F2EFEB", dark: "242426")
    static let textPrimary = Color(light: "1A1A1A", dark: "F2F2F7")
    static let textSecondary = Color(light: "6B6862", dark: "9A9A9E")
    static let textTertiary = Color(light: "9A968F", dark: "6E6E73")
    static let divider = Color(light: "E9E5E0", dark: "38383A")

    // Functional tints layered on top of the warm base
    static let success = Color(light: "2E8B57", dark: "4CD07D")
    static let warning = Color(light: "B26A00", dark: "FFB340")

    // MARK: Typography

    /// Display numerals — route numbers, countdowns. Warm and friendly.
    static let displayNumerals = Font.system(size: 44, weight: .bold, design: .rounded)
    static let display = Font.system(size: 28, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 22, weight: .bold, design: .rounded)

    static let heading = Font.system(size: 18, weight: .semibold, design: .default)
    static let subheading = Font.system(size: 16, weight: .medium, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let footnote = Font.system(size: 11, weight: .regular, design: .default)

    /// Monospaced digits for aligned ETA columns.
    static func tabular(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    // MARK: Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Radius

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }
}

// MARK: - Color helpers

extension Color {
    /// Hex string initializer, e.g. `Color(hex: "E85D3A")`.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Adaptive light/dark color.
    init(light lightHex: String, dark darkHex: String) {
        self.init(uiColor: UIColor(
            light: UIColor(Color(hex: lightHex)),
            dark: UIColor(Color(hex: darkHex))
        ))
    }
}

extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }
}

// MARK: - Surfaces

private struct SurfaceCardModifier: ViewModifier {
    var padding: CGFloat = DesignTokens.Spacing.m
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.l, style: .continuous)
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.30 : 0.05),
                radius: 8,
                y: 2
            )
    }
}

extension View {
    /// Warm Minimal surface card: soft rounded background with a subtle shadow.
    func surfaceCard(padding: CGFloat = DesignTokens.Spacing.m) -> some View {
        modifier(SurfaceCardModifier(padding: padding))
    }

    /// Screen background following the design system.
    func appBackground() -> some View {
        background(DesignTokens.background)
    }
}
