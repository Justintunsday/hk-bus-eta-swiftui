import SwiftUI

/// Liquid Glass helpers (iOS 26+) with graceful fallbacks for older systems.
///
/// The `#if compiler(>=6.2)` guard keeps the project buildable with Xcode 16
/// (which ships an SDK without the Liquid Glass APIs) while enabling the new
/// material when compiled with Xcode 26 or later.
extension View {
    @ViewBuilder
    func glassCapsuleBackground(selected: Bool) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if selected {
                self.background(DesignTokens.accent, in: Capsule())
            } else {
                self.glassEffect(.regular, in: Capsule())
            }
        } else {
            legacyCapsuleBackground(selected: selected)
        }
        #else
        legacyCapsuleBackground(selected: selected)
        #endif
    }

    @ViewBuilder
    private func legacyCapsuleBackground(selected: Bool) -> some View {
        if selected {
            self.background(DesignTokens.accent, in: Capsule())
        } else {
            self.background(DesignTokens.surfaceMuted, in: Capsule())
        }
    }
}
