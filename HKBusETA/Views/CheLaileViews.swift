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
                    Label(L10n.t("chelaile.loadFailed"), systemImage: "exclamationmark.triangle")
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

/// Lightweight info page for metro lines: the CheLaile bus API carries the
/// line's origin/terminus but not its intermediate stops.
struct CheLaileMetroInfoView: View {
    let name: String
    let origin: String
    let destination: String

    var body: some View {
        List {
            Section {
                LabeledContent(L10n.t("chelaile.metroStart"), value: origin)
                LabeledContent(L10n.t("chelaile.metroEnd"), value: destination)
            }
            Section {
                Text(L10n.t("chelaile.metroNotice"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stop departure board for 车来了 regions.
struct CheLaileStopBoardView: View {
    @Environment(AppState.self) private var app
    let physicalStId: String
    let namesakeStId: String?
    let title: String

    @State private var rows: [CheLaileBoardLine] = []
    @State private var metros: [CheLaileMetroLine] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && rows.isEmpty && metros.isEmpty {
                VStack(spacing: DesignTokens.Spacing.m) {
                    ProgressView()
                    Text(L10n.t("status.loading"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty && metros.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("stop.noRoutes"), systemImage: "bus")
                } actions: {
                    Button(L10n.t("common.retry")) {
                        Task { await load() }
                    }
                }
            } else {
                List {
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { row in
                                NavigationLink(value: CheLaileLineTarget(
                                    lineId: row.lineId,
                                    title: row.lineName,
                                    seq: max(row.targetOrder - 1, 0)
                                )) {
                                    CheLaileBoardRowView(row: row)
                                }
                            }
                        }
                    }
                    if !metros.isEmpty {
                        Section(L10n.t("chelaile.metros")) {
                            ForEach(metros) { metro in
                                HStack(spacing: DesignTokens.Spacing.s) {
                                    Circle()
                                        .fill(metroColor(metro.color))
                                        .frame(width: 9, height: 9)
                                    Text(metro.name)
                                }
                            }
                        }
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
        if rows.isEmpty && metros.isEmpty { isLoading = true }
        defer { isLoading = false }
        if let result = try? await provider.stopBoard(physicalStId: physicalStId, namesakeStId: namesakeStId) {
            rows = result.rows
            metros = result.metros
        }
    }

    private func metroColor(_ text: String?) -> Color {
        guard let text else { return .gray }
        let parts = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3 else { return .gray }
        return Color(.sRGB, red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255)
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
