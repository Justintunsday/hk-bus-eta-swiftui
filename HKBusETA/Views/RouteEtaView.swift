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
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
                        headerCard(entry)
                        etaSection(entry)

                        if etas.isEmpty, !isLoading {
                            scheduleFallback(entry)
                        }

                        if let lastUpdated {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("\(L10n.t("eta.updatedAt")) \(HKTime.timeString(lastUpdated))")
                                    .monospacedDigit()
                            }
                            .font(DesignTokens.footnote)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, DesignTokens.Spacing.xs)
                        }
                    }
                    .padding(DesignTokens.Spacing.m)
                }
                .appBackground()
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

    private func headerCard(_ entry: RouteEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack(spacing: DesignTokens.Spacing.s) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 20)
                CompanyTags(co: entry.co, language: language)
                if entry.isSpecialTrip {
                    Text(L10n.t("route.special"))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(entry.orig.name(language))
                    .font(DesignTokens.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                Image(systemName: "arrow.right")
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.accent)
                Text(entry.dest.name(language))
                    .font(DesignTokens.bodyMedium)
            }

            Divider().overlay(DesignTokens.divider)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("eta.currentStop"))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(currentStopName(entry))
                        .font(DesignTokens.subheading)
                }
                Spacer()
                if let fare = FareUtils.fare(entry, at: seq, db: app.data.db ?? .empty) {
                    Text("$\(fare)")
                        .font(DesignTokens.tabular(17, weight: .semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .surfaceCard()
    }

    // MARK: - ETA

    @ViewBuilder
    private func etaSection(_ entry: RouteEntry) -> some View {
        if isLoading && etas.isEmpty {
            HStack(spacing: DesignTokens.Spacing.s) {
                ProgressView()
                Text(L10n.t("status.loading"))
                    .font(DesignTokens.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .surfaceCard()
        } else if let hero = etas.first(where: { $0.date != nil }) {
            heroCard(hero)
            let rest = etas.filter { $0.id != hero.id }
            if !rest.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rest.enumerated()), id: \.offset) { index, eta in
                        ETALineView(
                            eta: eta,
                            language: language,
                            format: app.settings.etaFormat,
                            annotateScheduled: app.settings.annotateScheduled,
                            highlight: false,
                            showCompany: entry.co.count > 1,
                            showDestination: true
                        )
                        .padding(.vertical, DesignTokens.Spacing.s)
                        if index < rest.count - 1 {
                            Divider().overlay(DesignTokens.divider)
                        }
                    }
                }
                .surfaceCard(padding: DesignTokens.Spacing.m)
            }
        } else if !etas.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                ForEach(Array(etas.enumerated()), id: \.offset) { _, eta in
                    ETALineView(
                        eta: eta,
                        language: language,
                        format: app.settings.etaFormat,
                        annotateScheduled: app.settings.annotateScheduled,
                        highlight: false
                    )
                }
            }
            .surfaceCard()
        } else {
            Text(L10n.t("eta.noEta"))
                .font(DesignTokens.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .surfaceCard()
        }
    }

    /// Signature detail: oversized rounded countdown numeral.
    private func heroCard(_ hero: Eta) -> some View {
        let minutes = hero.minutesUntil ?? 0
        let threshold = (hero.co == "mtr" || hero.co == "lightRail") ? 2 : 1
        let isArriving = minutes < threshold

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
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
                            .font(DesignTokens.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    Text(L10n.t("eta.arrivalTime"))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(HKTime.timeString(hero.eta))
                        .font(DesignTokens.tabular(18, weight: .semibold))
                }
            }

            HStack(spacing: DesignTokens.Spacing.s) {
                if app.settings.annotateScheduled && hero.isScheduled {
                    Label(L10n.t("eta.scheduled"), systemImage: "calendar.badge.clock")
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                if !hero.remark.name(language).isEmpty, !hero.isScheduled {
                    Text(hero.remark.name(language))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                if hero.co == "mtr", !hero.dest.name(language).isEmpty {
                    Text(hero.dest.name(language))
                        .font(DesignTokens.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
        .surfaceCard()
    }

    // MARK: - Fallbacks

    @ViewBuilder
    private func scheduleFallback(_ entry: RouteEntry) -> some View {
        let db = app.data.db ?? .empty
        if let headway = ServiceHours.currentHeadway(entry, db: db) {
            Label("\(L10n.t("route.every")) \(max(headway / 60, 1)) \(L10n.t("unit.minutes"))", systemImage: "timer")
                .font(DesignTokens.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .surfaceCard()
        } else if let hours = ServiceHours.hoursToday(entry, db: db) {
            Label(hours, systemImage: "clock")
                .font(DesignTokens.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .surfaceCard()
        } else if entry.freq != nil {
            Text(L10n.t("eta.noServiceToday"))
                .font(DesignTokens.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .surfaceCard()
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
