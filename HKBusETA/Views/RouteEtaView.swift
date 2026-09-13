import SwiftUI

struct RouteEtaView: View {
    @Environment(AppState.self) private var app
    let routeKey: String
    let seq: Int

    @State private var etas: [Eta] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date?

    private var language: AppLanguage { L10n.language }
    private var refreshInterval: UInt64 { 30_000_000_000 }

    var body: some View {
        DataGate {
            if let entry = app.data.entry(routeKey) {
                List {
                    Section {
                        header(entry)
                    }
                    Section(L10n.t("eta.section.upcoming")) {
                        if isLoading && etas.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(L10n.t("status.loading"))
                                    .foregroundStyle(.secondary)
                            }
                        } else if etas.isEmpty {
                            Text(L10n.t("eta.noEta"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(etas.enumerated()), id: \.offset) { index, eta in
                                ETALineView(
                                    eta: eta,
                                    language: language,
                                    format: app.settings.etaFormat,
                                    annotateScheduled: app.settings.annotateScheduled,
                                    highlight: index == 0,
                                    showCompany: entry.co.count > 1,
                                    showDestination: true
                                )
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if etas.isEmpty, !isLoading {
                        scheduleFallback(entry)
                    }

                    if let lastUpdated {
                        Section {
                            HStack {
                                Text(L10n.t("eta.updatedAt"))
                                Spacer()
                                Text(HKTime.timeString(lastUpdated))
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("\(entry.route) \(L10n.t("route.to")) \(entry.dest.name(language))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        favoriteButton(entry)
                    }
                }
                .refreshable { await refresh() }
                .task(id: "\(routeKey)#\(seq)") {
                    recordRecent(entry)
                    while !Task.isCancelled {
                        await refresh()
                        do {
                            try await Task.sleep(nanoseconds: refreshInterval)
                        } catch {
                            break
                        }
                    }
                }
            } else {
                ContentUnavailableView(L10n.t("route.notFound"), systemImage: "questionmark.circle")
            }
        }
    }

    private func header(_ entry: RouteEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 20)
                CompanyTags(co: entry.co, language: language)
                Spacer()
            }
            HStack(spacing: 6) {
                Text(entry.orig.name(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.dest.name(language))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            let stopName = currentStopName(entry)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("eta.currentStop"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(stopName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let fare = FareUtils.fare(entry, at: seq, db: app.data.db ?? .empty) {
                    Text("$\(fare)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func scheduleFallback(_ entry: RouteEntry) -> some View {
        let db = app.data.db ?? .empty
        if let headway = ServiceHours.currentHeadway(entry, db: db) {
            Section(L10n.t("eta.section.schedule")) {
                Label("\(L10n.t("route.every")) \(max(headway / 60, 1)) \(L10n.t("unit.minutes"))", systemImage: "timer")
                    .foregroundStyle(.secondary)
            }
        } else if let hours = ServiceHours.hoursToday(entry, db: db) {
            Section(L10n.t("eta.section.schedule")) {
                Label(hours, systemImage: "clock")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } else if entry.freq != nil {
            Section(L10n.t("eta.section.schedule")) {
                Text(L10n.t("eta.noServiceToday"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func currentStopName(_ entry: RouteEntry) -> String {
        guard seq >= 0, seq < entry.canonicalStops.count else { return "" }
        return app.data.stopName(entry.canonicalStops[seq], language)
    }

    private func favoriteButton(_ entry: RouteEntry) -> some View {
        let isFavorite = app.bookmarks.isFavoriteRoute(routeKey: routeKey, seq: seq)
        return Button {
            let stops = entry.canonicalStops
            guard seq >= 0, seq < stops.count, let stop = app.data.stop(stops[seq]) else { return }
            app.bookmarks.toggleFavoriteRoute(entry: entry, routeKey: routeKey, stopId: stops[seq], seq: seq, stopName: stop.name)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
        }
        .tint(.yellow)
    }

    private func recordRecent(_ entry: RouteEntry) {
        let stops = entry.canonicalStops
        guard seq >= 0, seq < stops.count, let stop = app.data.stop(stops[seq]) else { return }
        app.bookmarks.recordRecentRoute(entry: entry, routeKey: routeKey, stopId: stops[seq], seq: seq, stopName: stop.name)
    }

    private func refresh() async {
        guard let entry = app.data.entry(routeKey), let db = app.data.db else { return }
        if etas.isEmpty { isLoading = true }
        let result = await ETAService.fetchEtas(entry: entry, seq: seq, db: db, language: language)
        etas = result
        lastUpdated = Date()
        isLoading = false
    }
}
