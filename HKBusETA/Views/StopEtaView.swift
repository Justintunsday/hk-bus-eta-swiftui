import SwiftUI

struct StopEtaView: View {
    @Environment(AppState.self) private var app
    let stopId: String

    @State private var items: [StopBoardItem] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date?

    private var language: AppLanguage { L10n.language }

    var body: some View {
        DataGate {
            List {
                Section {
                    header
                }
                Section(L10n.t("stop.section.routes")) {
                    if isLoading && items.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L10n.t("status.loading"))
                                .foregroundStyle(.secondary)
                        }
                    } else if items.isEmpty {
                        Text(L10n.t("stop.noRoutes"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            NavigationLink(value: RouteEtaTarget(routeKey: item.routeKey, seq: item.seq)) {
                                StopBoardRowView(item: item, language: language, settings: app.settings)
                            }
                        }
                    }
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
            .navigationTitle(app.data.stopName(stopId, language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    favoriteButton
                }
            }
            .refreshable { await refresh() }
            .task(id: stopId) {
                recordRecent()
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
    }

    @ViewBuilder
    private var header: some View {
        if let stop = app.data.stop(stopId) {
            VStack(alignment: .leading, spacing: 4) {
                Text(language == .zh ? stop.name.zh : stop.name.en)
                    .font(.headline)
                let count = app.data.routesAtStop(stopId).count
                if count > 0 {
                    Text("\(count) \(L10n.t("unit.routes"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if let stop = app.data.stop(stopId) {
            let isFavorite = app.bookmarks.isFavoriteStop(stopId)
            Button {
                app.bookmarks.toggleFavoriteStop(id: stopId, name: stop.name, location: stop.location)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .tint(.yellow)
        }
    }

    private func recordRecent() {
        guard let stop = app.data.stop(stopId) else { return }
        app.bookmarks.recordRecentStop(id: stopId, name: stop.name, location: stop.location)
    }

    private func refresh() async {
        guard let db = app.data.db else { return }
        if items.isEmpty { isLoading = true }
        let refs = app.data.routesAtStop(stopId)
        let result = await ETAService.fetchStopBoard(refs: refs, db: db, language: language)
        items = result
        lastUpdated = Date()
        isLoading = false
    }
}

struct StopBoardRowView: View {
    let item: StopBoardItem
    let language: AppLanguage
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 10) {
            RouteBadge(route: item.entry.route, entry: item.entry)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.t("route.to")) \(item.entry.dest.name(language))")
                    .font(.subheadline)
                    .lineLimit(1)
                CompanyTags(co: item.entry.co, language: language)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                let upcoming = item.upcoming
                if upcoming.isEmpty {
                    Text(item.etas.first?.remark.name(language) ?? L10n.t("eta.noEta"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                } else {
                    ForEach(Array(upcoming.prefix(3).enumerated()), id: \.offset) { index, eta in
                        ETALineView(
                            eta: eta,
                            language: language,
                            format: settings.etaFormat,
                            annotateScheduled: settings.annotateScheduled,
                            highlight: index == 0,
                            showCompany: false,
                            showDestination: false
                        )
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
