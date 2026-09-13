import CoreLocation
import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var filter: TransportFilter = .all
    @State private var routeKeys: [String] = []
    @State private var stops: [StopSearchItem] = []
    @State private var chelaileLines: [CheLaileLineHit] = []
    @State private var chelaileStops: [CheLaileStopHit] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var language: AppLanguage { L10n.language }

    var body: some View {
        NavigationStack {
            DataGate {
                content
            }
            .navigationTitle(L10n.t("search.title"))
            .navigationDestination(for: RouteDetailTarget.self) { target in
                RouteDetailView(routeKey: target.routeKey)
            }
            .navigationDestination(for: RouteEtaTarget.self) { target in
                RouteEtaView(routeKey: target.routeKey, seq: target.seq)
            }
            .navigationDestination(for: StopTarget.self) { target in
                StopEtaView(stopId: target.stopId)
            }
            .navigationDestination(for: CheLaileLineTarget.self) { target in
                CheLaileLineLoaderView(lineId: target.lineId, title: target.title, seq: target.seq)
            }
            .navigationDestination(for: CheLaileStopTarget.self) { target in
                CheLaileStopBoardView(physicalStId: target.physicalStId, namesakeStId: target.namesakeStId, title: target.title)
            }
        }
        .searchable(text: $query, prompt: Text(L10n.t("search.placeholder")))
        .searchScopes($filter, activation: .onSearchPresentation) {
            ForEach(TransportFilter.allCases) { scope in
                Text(scope.title(language)).tag(scope)
            }
        }
        .onChange(of: query) { performSearch() }
        .onChange(of: filter) { performSearch() }
        .onChange(of: app.settings.language) { performSearch() }
    }

    @ViewBuilder
    private var content: some View {
        if app.region.isQueryMode {
            chelaileContent
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recentContent
        } else if routeKeys.isEmpty && stops.isEmpty {
            ContentUnavailableView {
                Label(L10n.t("search.noResults"), systemImage: "magnifyingglass")
            } description: {
                Text(L10n.t("search.noResults.hint"))
            }
        } else {
            List {
                if !routeKeys.isEmpty {
                    Section(L10n.t("search.section.routes")) {
                        ForEach(routeKeys, id: \.self) { key in
                            if let entry = app.data.entry(key) {
                                NavigationLink(value: RouteDetailTarget(routeKey: key)) {
                                    RouteResultRow(entry: entry, language: language)
                                }
                            }
                        }
                    }
                }
                if !stops.isEmpty {
                    Section(L10n.t("search.section.stops")) {
                        ForEach(stops, id: \.id) { item in
                            NavigationLink(value: StopTarget(stopId: item.id)) {
                                StopRowView(item: item, distance: distanceText(item))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chelaileContent: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView {
                Label(L10n.t("search.title"), systemImage: "bus")
            } description: {
                Text(L10n.t("search.empty.hint"))
            }
        } else if isSearching && chelaileLines.isEmpty && chelaileStops.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chelaileLines.isEmpty && chelaileStops.isEmpty {
            ContentUnavailableView {
                Label(L10n.t("search.noResults"), systemImage: "magnifyingglass")
            } description: {
                Text(L10n.t("search.noResults.hint"))
            }
        } else {
            List {
                if !chelaileLines.isEmpty {
                    Section(L10n.t("search.section.routes")) {
                        ForEach(chelaileLines) { hit in
                            NavigationLink(value: CheLaileLineTarget(lineId: hit.lineId, title: hit.lineName, seq: nil)) {
                                CheLaileLineRow(hit: hit)
                            }
                        }
                    }
                }
                if !chelaileStops.isEmpty {
                    Section(L10n.t("search.section.stops")) {
                        ForEach(chelaileStops) { hit in
                            NavigationLink(value: CheLaileStopTarget(physicalStId: hit.physicalStId, namesakeStId: hit.namesakeStId, title: hit.name)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.name)
                                    if let subtitle = hit.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentContent: some View {
        if app.bookmarks.recentRoutes.isEmpty && app.bookmarks.recentStops.isEmpty {
            ContentUnavailableView {
                Label(L10n.t("search.title"), systemImage: "bus")
            } description: {
                Text(L10n.t("search.empty.hint"))
            }
        } else {
            List {
                if !app.bookmarks.recentRoutes.isEmpty {
                    Section(L10n.t("search.recent.routes")) {
                        ForEach(app.bookmarks.recentRoutes) { recent in
                            NavigationLink(value: RouteEtaTarget(routeKey: recent.routeKey, seq: recent.seq)) {
                                HStack(spacing: 12) {
                                    RouteBadge(route: recent.route, entry: app.data.entry(recent.routeKey))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(L10n.t("route.to")) \(language.isChinese ? L10n.display(recent.destZh) : recent.destEn)")
                                            .lineLimit(1)
                                        HStack(spacing: 6) {
                                            Text(language.isChinese ? L10n.display(recent.stopNameZh) : recent.stopNameEn)
                                                .lineLimit(1)
                                            CompanyLogos(co: app.data.entry(recent.routeKey)?.co ?? recent.co, language: language, height: 12)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if !app.bookmarks.recentStops.isEmpty {
                    Section(L10n.t("search.recent.stops")) {
                        ForEach(app.bookmarks.recentStops) { recent in
                            NavigationLink(value: StopTarget(stopId: recent.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.isChinese ? L10n.display(recent.nameZh) : recent.nameEn)
                                    if let count = routeCount(recent.id) {
                                        Text("\(count) \(L10n.t("unit.routes"))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func distanceText(_ item: StopSearchItem) -> String? {
        guard let location = app.location.location else { return nil }
        let distance = location.distance(from: CLLocation(latitude: item.location.lat, longitude: item.location.lng))
        return GeoUtils.distanceString(distance, language: language)
    }

    private func routeCount(_ stopId: String) -> Int? {
        let count = app.data.routeCount(at: stopId)
        return count > 0 ? count : nil
    }

    private func performSearch() {
        searchTask?.cancel()
        let query = query
        let filter = filter

        if let provider = app.provider as? CheLaileProvider {
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                isSearching = true
                defer { isSearching = false }
                do {
                    let results = try await provider.search(keyword: query)
                    guard !Task.isCancelled else { return }
                    chelaileLines = results.lines
                    chelaileStops = results.stops
                } catch {
                    chelaileLines = []
                    chelaileStops = []
                }
            }
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let results = app.data.searchRoutes(query: query, filter: filter)
            let stopResults = app.data.searchStops(query: query)

            guard !Task.isCancelled else { return }
            routeKeys = results.map(\.key)
            stops = stopResults
        }
    }
}

struct CheLaileLineRow: View {
    let hit: CheLaileLineHit

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(route: hit.lineName, entry: nil, colorHex: CheLaileProvider.color(for: hit.lineName))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.t("route.to")) \(hit.dest)")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(hit.orig)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One row per direction of a route — the reverse direction is its own result.
struct RouteResultRow: View {
    let entry: RouteEntry
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(route: entry.route, entry: entry)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(L10n.t("route.to")) \(entry.dest.name(language))")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if entry.isSpecialTrip {
                        Text(L10n.t("route.special"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(entry.orig.name(language))
                    Text("·")
                    CompanyLogos(co: entry.co, language: language, height: 14)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct StopRowView: View {
    let item: StopSearchItem
    var distance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.language.isChinese ? L10n.display(item.nameZh) : item.nameEn)
            if let distance {
                Text(distance)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
