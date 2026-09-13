import CoreLocation
import SwiftUI

struct RouteGroupPayload: Identifiable {
    let id: String
    let route: String
    let co: [String]
    var variants: [String]
}

struct SearchView: View {
    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var filter: TransportFilter = .all
    @State private var groups: [RouteGroupPayload] = []
    @State private var stops: [StopSearchItem] = []
    @State private var searchTask: Task<Void, Never>?

    private var language: AppLanguage { L10n.language }

    var body: some View {
        NavigationStack {
            DataGate {
                VStack(spacing: 0) {
                    filterBar
                    content
                }
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
        }
        .searchable(text: $query, prompt: Text(L10n.t("search.placeholder")))
        .onChange(of: query) { performSearch() }
        .onChange(of: filter) { performSearch() }
        .onChange(of: app.settings.language) { performSearch() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransportFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.title(language))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassCapsuleBackground(selected: filter == option)
                            .foregroundStyle(filter == option ? Color.black : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recentContent
        } else if groups.isEmpty && stops.isEmpty {
            ContentUnavailableView {
                Label(L10n.t("search.noResults"), systemImage: "magnifyingglass")
            } description: {
                Text(L10n.t("search.noResults.hint"))
            }
        } else {
            resultList
        }
    }

    private var resultList: some View {
        List {
            if !groups.isEmpty {
                Section(L10n.t("search.section.routes")) {
                    ForEach(groups) { group in
                        RouteGroupRow(group: group)
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
                                HStack(spacing: 10) {
                                    RouteBadge(route: recent.route, entry: app.data.entry(recent.routeKey))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(L10n.t("route.to")) \(language == .zh ? recent.destZh : recent.destEn)")
                                            .font(.subheadline)
                                        Text(language == .zh ? recent.stopNameZh : recent.stopNameEn)
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
                                    Text(language == .zh ? recent.nameZh : recent.nameEn)
                                        .font(.subheadline)
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
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let items = app.data.searchRoutes(query: query, filter: filter)
            var payloads: [RouteGroupPayload] = []
            var indexByGroup: [String: Int] = [:]
            for item in items {
                guard let entry = app.data.entry(item.key) else { continue }
                let groupKey = "\(entry.route)#\(entry.co.sorted().joined(separator: "+"))"
                if let index = indexByGroup[groupKey] {
                    payloads[index].variants.append(item.key)
                } else {
                    indexByGroup[groupKey] = payloads.count
                    payloads.append(RouteGroupPayload(id: groupKey, route: entry.route, co: entry.co, variants: [item.key]))
                }
            }
            let stopResults = app.data.searchStops(query: query)

            guard !Task.isCancelled else { return }
            groups = payloads
            stops = stopResults
        }
    }
}

struct RouteGroupRow: View {
    @Environment(AppState.self) private var app
    let group: RouteGroupPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RouteBadge(route: group.route, entry: app.data.entry(group.variants.first ?? ""))
                CompanyTags(co: group.co, language: L10n.language)
                Spacer()
            }
            ForEach(group.variants, id: \.self) { key in
                if let entry = app.data.entry(key) {
                    NavigationLink(value: RouteDetailTarget(routeKey: key)) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(entry.dest.name(L10n.language))
                                .font(.subheadline)
                            if entry.isSpecialTrip {
                                Text(L10n.t("route.special"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
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
            Text(L10n.language == .zh ? item.nameZh : item.nameEn)
                .font(.subheadline)
            if let distance {
                Text(distance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
