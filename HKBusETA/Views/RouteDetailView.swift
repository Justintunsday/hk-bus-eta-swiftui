import SwiftUI

struct RouteDetailView: View {
    @Environment(AppState.self) private var app
    let routeKey: String

    @State private var selectedSeq: Int?

    private var language: AppLanguage { L10n.language }

    var body: some View {
        DataGate {
            if let entry = app.data.entry(routeKey) {
                let points = makePoints(entry)
                VStack(spacing: 0) {
                    header(entry)
                        .padding(.horizontal, DesignTokens.Spacing.m)
                        .padding(.bottom, DesignTokens.Spacing.s)

                    if points.contains(where: { $0.coordinate != nil }) {
                        RouteMapSection(entry: entry, points: points, selectedSeq: $selectedSeq)
                            .frame(height: 230)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.l, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                            .padding(.horizontal, DesignTokens.Spacing.m)
                            .padding(.bottom, DesignTokens.Spacing.s)
                    }

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            HStack {
                                Text(L10n.t("route.section.stops"))
                                    .font(DesignTokens.caption)
                                    .foregroundStyle(DesignTokens.textTertiary)
                                Spacer()
                                Text("\(points.count) \(L10n.t("unit.stops"))")
                                    .font(DesignTokens.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .padding(.bottom, DesignTokens.Spacing.s)

                            ForEach(points) { point in
                                StopTimelineRow(
                                    entry: entry,
                                    point: point,
                                    isLast: point.seq == points.count - 1,
                                    isSelected: selectedSeq == point.seq,
                                    isExpanded: selectedSeq == point.seq,
                                    onTap: { toggle(point.seq) }
                                )
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.m)
                        .padding(.bottom, DesignTokens.Spacing.l)
                    }
                }
                .appBackground()
                .navigationTitle("\(entry.route) \(L10n.t("route.to")) \(entry.dest.name(language))")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(L10n.t("route.notFound"), systemImage: "questionmark.circle")
            }
        }
    }

    private func toggle(_ seq: Int) {
        withAnimation(.snappy) {
            selectedSeq = selectedSeq == seq ? nil : seq
        }
    }

    private func makePoints(_ entry: RouteEntry) -> [RouteStopPoint] {
        let db = app.data.db
        return entry.canonicalStops.enumerated().map { index, stopId in
            let stop = db?.stopList[stopId]
            return RouteStopPoint(
                seq: index,
                stopId: stopId,
                nameZh: stop?.name.zh ?? stopId,
                nameEn: stop?.name.en ?? stopId,
                lat: stop?.location.lat,
                lng: stop?.location.lng
            )
        }
    }

    private func header(_ entry: RouteEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack(spacing: DesignTokens.Spacing.s) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 22)
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

            HStack(spacing: DesignTokens.Spacing.m) {
                if let hours = ServiceHours.hoursToday(entry, db: app.data.db ?? EtaDB.empty) {
                    labeled("clock", hours)
                }
                if let headway = ServiceHours.currentHeadway(entry, db: app.data.db ?? EtaDB.empty) {
                    labeled("timer", headwayText(headway))
                }
                if let journey = entry.journeyTimeMinutes {
                    labeled("hourglass", "\(journey) \(L10n.t("unit.minutes"))")
                }
                if let fare = FareUtils.fare(entry, at: 0, db: app.data.db ?? EtaDB.empty) {
                    labeled("dollarsign.circle", "$\(fare)")
                }
            }
        }
        .surfaceCard()
    }

    private func labeled(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(DesignTokens.footnote)
            Text(text)
                .font(DesignTokens.caption)
                .monospacedDigit()
        }
        .foregroundStyle(DesignTokens.textSecondary)
    }

    private func headwayText(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(L10n.t("route.every")) \(minutes) \(L10n.t("unit.minutes"))"
    }
}
