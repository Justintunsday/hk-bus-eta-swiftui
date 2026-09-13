import SwiftUI

/// Loads a 车来了 line detail, registers it as a synthetic database entry and
/// then shows the standard route detail / ETA screens.
struct CheLaileLineLoaderView: View {
    @Environment(AppState.self) private var app
    let lineId: String
    let title: String
    let seq: Int?

    @State private var routeKey: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let routeKey {
                if let seq {
                    RouteEtaView(routeKey: routeKey, seq: seq)
                } else {
                    RouteDetailView(routeKey: routeKey)
                }
            } else if failed {
                ContentUnavailableView {
                    Label(L10n.t("route.notFound"), systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(L10n.t("common.retry")) {
                        failed = false
                        Task { await load() }
                    }
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.m) {
                    ProgressView()
                    Text(L10n.t("status.loading"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        guard let provider = app.provider as? CheLaileProvider else {
            failed = true
            return
        }
        do {
            guard let payload = try await provider.linePayload(lineId: lineId) else {
                failed = true
                return
            }
            app.data.registerSynthetic(entry: payload.entry, stops: payload.stops)
            routeKey = payload.entry.routeKey
        } catch {
            failed = true
        }
    }
}

/// Stop departure board for 车来了 regions.
struct CheLaileStopBoardView: View {
    @Environment(AppState.self) private var app
    let physicalStId: String
    let namesakeStId: String?
    let title: String

    @State private var rows: [CheLaileBoardLine] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                VStack(spacing: DesignTokens.Spacing.m) {
                    ProgressView()
                    Text(L10n.t("status.loading"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("stop.noRoutes"), systemImage: "bus")
                } actions: {
                    Button(L10n.t("common.retry")) {
                        Task { await load() }
                    }
                }
            } else {
                List(rows) { row in
                    NavigationLink(value: CheLaileLineTarget(
                        lineId: row.lineId,
                        title: row.lineName,
                        seq: max(row.targetOrder - 1, 0)
                    )) {
                        CheLaileBoardRowView(row: row)
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: physicalStId) { await load() }
    }

    private func load() async {
        guard let provider = app.provider as? CheLaileProvider else { return }
        if rows.isEmpty { isLoading = true }
        defer { isLoading = false }
        if let result = try? await provider.stopBoard(physicalStId: physicalStId, namesakeStId: namesakeStId) {
            rows = result
        }
    }
}

struct CheLaileBoardRowView: View {
    let row: CheLaileBoardLine

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            RouteBadge(route: row.lineName, entry: nil, colorHex: CheLaileProvider.color(for: row.lineName))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.t("route.to")) \(row.destination)")
                    .font(.body)
                    .lineLimit(1)
                if !row.status.isEmpty {
                    Text(row.status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.s)
            VStack(alignment: .trailing, spacing: 2) {
                if row.minutes.isEmpty {
                    Text(L10n.t("eta.noEta"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(row.minutes.prefix(3).enumerated()), id: \.offset) { index, minutes in
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(minutes)")
                                .font(DesignTokens.tabular(17, weight: .bold))
                                .foregroundStyle(index == 0 ? DesignTokens.accent : Color.primary)
                            Text(L10n.t("unit.minutes"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
