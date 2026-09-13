import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var app

    private var language: AppLanguage { L10n.language }

    var body: some View {
        NavigationStack {
            DataGate {
                if app.bookmarks.favoriteRoutes.isEmpty && app.bookmarks.favoriteStops.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.t("favorites.empty.title"), systemImage: "star")
                    } description: {
                        Text(L10n.t("favorites.empty.message"))
                    }
                } else {
                    List {
                        if !app.bookmarks.favoriteRoutes.isEmpty {
                            Section(L10n.t("favorites.routes")) {
                                ForEach(app.bookmarks.favoriteRoutes) { favorite in
                                    NavigationLink(value: RouteDetailTarget(routeKey: favorite.routeKey)) {
                                        routeRow(favorite)
                                    }
                                }
                                .onDelete { app.bookmarks.removeFavoriteRoutes(at: $0) }
                            }
                        }
                        if !app.bookmarks.favoriteStops.isEmpty {
                            Section(L10n.t("favorites.stops")) {
                                ForEach(app.bookmarks.favoriteStops) { favorite in
                                    NavigationLink(value: StopTarget(stopId: favorite.id)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(language.isChinese ? L10n.display(favorite.nameZh) : favorite.nameEn)
                                            let count = app.data.routeCount(at: favorite.id)
                                            if count > 0 {
                                                Text("\(count) \(L10n.t("unit.routes"))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .onDelete { app.bookmarks.removeFavoriteStops(at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("favorites.title"))
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
    }

    private func routeRow(_ favorite: FavoriteRoute) -> some View {
        HStack(spacing: 12) {
            RouteBadge(route: favorite.route, entry: app.data.entry(favorite.routeKey))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.t("route.to")) \(language.isChinese ? L10n.display(favorite.destZh) : favorite.destEn)")
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(language.isChinese ? L10n.display(favorite.origZh) : favorite.origEn)
                    Text("·")
                    CompanyLogos(co: favorite.co, language: language, height: 13)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
