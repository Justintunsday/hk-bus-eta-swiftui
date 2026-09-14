import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var app

    private var language: AppLanguage { L10n.language }
    private var favoriteRoutes: [RegionalFavoriteRoute] { app.bookmarks.allFavoriteRoutes }
    private var favoriteStops: [RegionalFavoriteStop] { app.bookmarks.allFavoriteStops }

    var body: some View {
        NavigationStack {
            Group {
                if favoriteRoutes.isEmpty && favoriteStops.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.t("favorites.empty.title"), systemImage: "star")
                    } description: {
                        Text(L10n.t("favorites.empty.message"))
                    }
                } else {
                    List {
                        if !favoriteRoutes.isEmpty {
                            Section(L10n.t("favorites.routes")) {
                                ForEach(favoriteRoutes) { item in
                                    NavigationLink(value: SavedRouteTarget(item)) {
                                        routeRow(item)
                                    }
                                }
                                .onDelete { offsets in
                                    app.bookmarks.removeFavoriteRoutes(offsets.map { favoriteRoutes[$0] })
                                }
                            }
                        }
                        if !favoriteStops.isEmpty {
                            Section(L10n.t("favorites.stops")) {
                                ForEach(favoriteStops) { item in
                                    NavigationLink(value: SavedStopTarget(item)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            let favorite = item.favorite
                                            Text(language.isChinese ? L10n.display(favorite.nameZh) : favorite.nameEn)
                                            regionLabel(item.regionID)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    app.bookmarks.removeFavoriteStops(offsets.map { favoriteStops[$0] })
                                }
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
            .navigationDestination(for: SavedRouteTarget.self) { target in
                SavedRouteDestination(target: target)
            }
            .navigationDestination(for: SavedStopTarget.self) { target in
                SavedStopDestination(target: target)
            }
        }
    }

    private func routeRow(_ item: RegionalFavoriteRoute) -> some View {
        let favorite = item.favorite
        HStack(spacing: 12) {
            RouteBadge(
                route: favorite.route,
                entry: item.regionID == app.region.id ? app.data.entry(favorite.routeKey) : nil
            )
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
                regionLabel(item.regionID)
            }
        }
        .padding(.vertical, 2)
    }

    private func regionLabel(_ regionID: String) -> some View {
        Label(RegionCatalog.region(for: regionID)?.name ?? regionID, systemImage: "mappin.and.ellipse")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
