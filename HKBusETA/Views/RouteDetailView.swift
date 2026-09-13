import SwiftUI

struct RouteDetailView: View {
    @Environment(AppState.self) private var app
    let routeKey: String

    private var language: AppLanguage { L10n.language }

    var body: some View {
        DataGate {
            if let entry = app.data.entry(routeKey) {
                List {
                    Section {
                        header(entry)
                    }
                    Section(L10n.t("route.section.stops")) {
                        let stops = entry.canonicalStops
                        ForEach(Array(stops.enumerated()), id: \.offset) { index, stopId in
                            NavigationLink(value: RouteEtaTarget(routeKey: routeKey, seq: index)) {
                                stopRow(entry: entry, stopId: stopId, index: index)
                            }
                            .swipeActions(edge: .leading) {
                                stopFavoriteButton(stopId: stopId)
                            }
                        }
                    }
                }
                .navigationTitle("\(entry.route) \(L10n.t("route.to")) \(entry.dest.name(language))")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(L10n.t("route.notFound"), systemImage: "questionmark.circle")
            }
        }
    }

    private func header(_ entry: RouteEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RouteBadge(route: entry.route, entry: entry, fontSize: 22)
                CompanyTags(co: entry.co, language: language)
                if entry.isSpecialTrip {
                    Text(L10n.t("route.special"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Text(entry.orig.name(language))
                    .font(.subheadline)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.dest.name(language))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 14) {
                if let hours = ServiceHours.hoursToday(entry, db: app.data.db ?? EtaDB.empty) {
                    labeled("clock", hours)
                }
                if let headway = ServiceHours.currentHeadway(entry, db: app.data.db ?? EtaDB.empty) {
                    labeled("timer", headwayText(headway))
                }
                if let journey = entry.journeyTimeMinutes {
                    labeled("hourglass", "\(journey) \(L10n.t("unit.minutes"))")
                }
            }

            if let fare = FareUtils.fare(entry, at: 0, db: app.data.db ?? EtaDB.empty) {
                labeled("dollarsign.circle", "$\(fare)")
            }
        }
        .padding(.vertical, 4)
    }

    private func labeled(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func headwayText(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(L10n.t("route.every")) \(minutes) \(L10n.t("unit.minutes"))"
    }

    private func stopRow(entry: RouteEntry, stopId: String, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.data.stopName(stopId, language))
                    .font(.subheadline)
                if let fare = FareUtils.fare(entry, at: index, db: app.data.db ?? EtaDB.empty) {
                    Text("$\(fare)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func stopFavoriteButton(stopId: String) -> some View {
        if let stop = app.data.stop(stopId) {
            let isFavorite = app.bookmarks.isFavoriteStop(stopId)
            Button {
                app.bookmarks.toggleFavoriteStop(id: stopId, name: stop.name, location: stop.location)
            } label: {
                Label(
                    isFavorite ? L10n.t("common.unfavorite") : L10n.t("common.favorite"),
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
    }
}
