import SwiftUI

/// Shows metadata returned by a mainland base-data provider that cannot fit
/// into the shared legacy `RouteEntry` schema.
struct MainlandRouteOverview: View {
    let metadata: MainlandRouteMetadata

    private var hasSchedule: Bool {
        metadata.firstDeparture != nil || metadata.lastDeparture != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            if metadata.mode == .metro {
                Label(L10n.t("mainland.metros"), systemImage: "tram.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasSchedule {
                HStack(spacing: DesignTokens.Spacing.l) {
                    if let first = metadata.firstDeparture, !first.isEmpty {
                        labeled("mainland.firstDeparture", first)
                    }
                    if let last = metadata.lastDeparture, !last.isEmpty {
                        labeled("mainland.lastDeparture", last)
                    }
                }
            }

            if let fare = metadata.fare, !fare.isEmpty {
                labeled("route.fare", "¥\(fare)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func labeled(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t(key))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }
}
