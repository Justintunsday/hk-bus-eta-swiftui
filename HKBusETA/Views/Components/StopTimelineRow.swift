import SwiftUI

struct StopTimelineRow: View {
    @Environment(AppState.self) private var app
    let entry: RouteEntry
    let point: RouteStopPoint
    let isLast: Bool
    let isSelected: Bool
    let isExpanded: Bool
    let onTap: () -> Void

    private var lineColor: Color { RouteStyle.info(for: entry).background }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isSelected ? lineColor : Color.clear)
                    Circle()
                        .stroke(lineColor, lineWidth: isSelected ? 5 : 3)
                }
                .frame(width: 17, height: 17)
                .frame(width: 26, height: 26)

                if !isLast {
                    Rectangle()
                        .fill(lineColor.opacity(0.85))
                        .frame(width: 5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(point.seq + 1). \(point.name(L10n.language))")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

                if isExpanded {
                    StopEtaInlineView(entry: entry, seq: point.seq)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
    }
}

struct StopEtaInlineView: View {
    @Environment(AppState.self) private var app
    let entry: RouteEntry
    let seq: Int

    @State private var etas: [Eta] = []
    @State private var isLoading = false

    private var language: AppLanguage { L10n.language }

    private var stopId: String? {
        let stops = entry.canonicalStops
        guard seq >= 0, seq < stops.count else { return nil }
        return stops[seq]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fare = FareUtils.fare(entry, at: seq, db: app.data.db ?? .empty) {
                HStack(spacing: 4) {
                    Text(L10n.t("route.fare"))
                        .foregroundStyle(.secondary)
                    Text("$\(fare)")
                        .fontWeight(.medium)
                }
                .font(.caption)
            }

            if isLoading && etas.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if etas.isEmpty {
                Text(L10n.t("eta.noEta"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(etas.prefix(3).enumerated()), id: \.offset) { index, eta in
                    ETALineView(
                        eta: eta,
                        language: language,
                        format: app.settings.etaFormat,
                        annotateScheduled: app.settings.annotateScheduled,
                        highlight: index == 0,
                        showCompany: entry.co.count > 1,
                        showDestination: true
                    )
                }
            }

            HStack(spacing: 16) {
                NavigationLink(value: RouteEtaTarget(routeKey: entry.routeKey, seq: seq)) {
                    Label(L10n.t("route.fullEta"), systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                }

                if let stopId, let stop = app.data.stop(stopId) {
                    let isFavorite = app.bookmarks.isFavoriteStop(stopId)
                    Button {
                        app.bookmarks.toggleFavoriteStop(id: stopId, name: stop.name, location: stop.location)
                    } label: {
                        Label(
                            isFavorite ? L10n.t("common.unfavorite") : L10n.t("common.favorite"),
                            systemImage: isFavorite ? "star.fill" : "star"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .tint(.yellow)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .task(id: "\(entry.routeKey)#\(seq)") {
            while !Task.isCancelled {
                await refresh()
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    private func refresh() async {
        guard let db = app.data.db else { return }
        if etas.isEmpty { isLoading = true }
        let result = await ETAService.fetchEtas(entry: entry, seq: seq, db: db, language: language)
        etas = result
        isLoading = false
    }
}
