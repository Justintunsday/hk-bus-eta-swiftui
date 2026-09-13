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

                    etaSection(entry)

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

    // MARK: - Header

    private func header(_ entry: RouteEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack(spacing: 10) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 20)
                CompanyLogos(co: entry.co, language: language, height: 18)
                if entry.isSpecialTrip {
                    Text(L10n.t("route.special"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Text(entry.orig.name(language))
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.accent)
                Text(entry.dest.name(language))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("eta.currentStop"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentStopName(entry))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                if let fare = FareUtils.fare(entry, at: seq, db: app.data.db ?? .empty) {
                    Text("$\(fare)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // MARK: - ETA

    @ViewBuilder
    private func etaSection(_ entry: RouteEntry) -> some View {
        if isLoading && etas.isEmpty {
            Section {
                HStack(spacing: DesignTokens.Spacing.s) {
                    ProgressView()
                    Text(L10n.t("status.loading"))
                        .foregroundStyle(.secondary)
                }
            }
        } else if let hero = etas.first(where: { $0.date != nil }) {
            Section {
                heroRow(hero)
            }
            let rest = etas.filter { $0.id != hero.id }
            if !rest.isEmpty {
                Section {
                    ForEach(Array(rest.enumerated()), id: \.offset) { _, eta in
                        ETALineView(
                            eta: eta,
                            language: language,
                            format: app.settings.etaFormat,
                            annotateScheduled: app.settings.annotateScheduled,
                            highlight: false,
                            showCompany: entry.co.count > 1,
                            showDestination: true
                        )
                        .padding(.vertical, 2)
                    }
                }
            }
        } else if !etas.isEmpty {
            Section {
                ForEach(Array(etas.enumerated()), id: \.offset) { _, eta in
                    ETALineView(
                        eta: eta,
                        language: language,
                        format: app.settings.etaFormat,
                        annotateScheduled: app.settings.annotateScheduled,
                        highlight: false
                    )
                    .padding(.vertical, 2)
                }
            }
        } else {
            Section {
                Text(L10n.t("eta.noEta"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Signature detail: oversized rounded countdown numeral.
    private func heroRow(_ hero: Eta) -> some View {
        let minutes = hero.minutesUntil ?? 0
        let threshold = (hero.co == "mtr" || hero.co == "lightRail") ? 2 : 1
        let isArriving = minutes < threshold

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.s) {
                if isArriving {
                    Text(L10n.t("eta.arriving"))
                        .font(DesignTokens.display)
                        .foregroundStyle(DesignTokens.accent)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                        Text("\(minutes)")
                            .font(DesignTokens.displayNumerals)
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.accent)
                        Text(L10n.t("unit.minutes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.t("eta.arrivalTime"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(HKTime.timeString(hero.eta))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            HStack(spacing: DesignTokens.Spacing.s) {
                if app.settings.annotateScheduled && hero.isScheduled {
                    Label(L10n.t("eta.scheduled"), systemImage: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !hero.remark.name(language).isEmpty, !hero.isScheduled {
                    Text(hero.remark.name(language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if hero.co == "mtr", !hero.dest.name(language).isEmpty {
                    Text(hero.dest.name(language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // MARK: - Fallbacks

    @ViewBuilder
    private func scheduleFallback(_ entry: RouteEntry) -> some View {
        let db = app.data.db ?? .empty
        if let headway = ServiceHours.currentHeadway(entry, db: db) {
            Section {
                Label("\(L10n.t("route.every")) \(max(headway / 60, 1)) \(L10n.t("unit.minutes"))", systemImage: "timer")
                    .foregroundStyle(.secondary)
            }
        } else if let hours = ServiceHours.hoursToday(entry, db: db) {
            Section {
                Label(hours, systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
        } else if entry.freq != nil {
            Section {
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
        let isFavorite = app.bookmarks.isFavoriteRoute(routeKey)
        return Button {
            app.bookmarks.toggleFavoriteRoute(entry: entry, routeKey: routeKey)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
        }
        .tint(DesignTokens.accent)
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
