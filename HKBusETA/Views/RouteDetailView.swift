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
                List {
                    Section {
                        header(entry)
                    }

                    if points.contains(where: { $0.coordinate != nil }) {
                        Section {
                            RouteMapSection(entry: entry, points: points, selectedSeq: $selectedSeq)
                                .frame(height: 230)
                                .listRowInsets(EdgeInsets())
                        }
                    }

                    Section {
                        ForEach(points) { point in
                            StopTimelineRow(
                                entry: entry,
                                point: point,
                                isLast: point.seq == points.count - 1,
                                isSelected: selectedSeq == point.seq,
                                isExpanded: selectedSeq == point.seq,
                                onTap: { toggle(point.seq) }
                            )
                            .listRowInsets(EdgeInsets(
                                top: point.seq == 0 ? 12 : 0,
                                leading: 16,
                                bottom: point.seq == points.count - 1 ? 12 : 0,
                                trailing: 16
                            ))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("\(L10n.t("route.section.stops")) · \(points.count) \(L10n.t("unit.stops"))")
                    }
                }
                .navigationTitle("\(entry.route) \(L10n.t("route.to")) \(entry.dest.name(language))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let opposite = app.data.oppositeEntry(for: entry) {
                            NavigationLink(value: RouteDetailTarget(routeKey: opposite.key)) {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .tint(DesignTokens.accent)
                            .accessibilityLabel(L10n.t("route.reverse"))
                        }
                        favoriteButton(entry)
                    }
                }
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
        entry.canonicalStops.enumerated().map { index, stopId in
            let stop = app.data.stop(stopId)
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
            HStack(spacing: 10) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 22)
                CompanyLogos(co: entry.co, language: language, height: 20)
                if entry.isSpecialTrip {
                    Text(L10n.t("route.special"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Text(entry.orig.name(language))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.accent)
                Text(entry.dest.name(language))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            HStack(spacing: 14) {
                if let hours = app.provider.serviceHoursToday(entry: entry, db: app.data.db ?? EtaDB.empty, at: Date()) {
                    labeled("clock", hours)
                }
                if let headway = app.provider.currentHeadway(entry: entry, db: app.data.db ?? EtaDB.empty, at: Date()) {
                    labeled("timer", headwayText(headway))
                }
                if let journey = entry.journeyTimeMinutes {
                    labeled("hourglass", "\(journey) \(L10n.t("unit.minutes"))")
                }
                if let fare = app.provider.fare(entry: entry, at: 0, db: app.data.db ?? EtaDB.empty, at: Date()) {
                    labeled("dollarsign.circle", "$\(fare)")
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func labeled(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func headwayText(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(L10n.t("route.every")) \(minutes) \(L10n.t("unit.minutes"))"
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
}
