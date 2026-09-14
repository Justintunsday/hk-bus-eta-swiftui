import SwiftUI

/// Simple transit-mode glyph used for regions that have no operator logos
/// (mainland 车来了 lines) and as a quiet fallback for ferry operators.
struct RouteModeIcon: View {
    let symbolName: String
    var size: CGFloat = 12
    var label: String?

    var body: some View {
        if let label {
            chip.accessibilityLabel(Text(label))
        } else {
            chip.accessibilityHidden(true)
        }
    }

    private var chip: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(DesignTokens.textSecondary)
            .frame(width: size + 9, height: size + 9)
            .background(
                DesignTokens.surfaceMuted,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
    }
}

extension MainlandTransitMode {
    var symbolName: String? {
        switch self {
        case .bus: return "bus.fill"
        case .metro: return "tram.fill"
        case .unknown: return nil
        }
    }
}
