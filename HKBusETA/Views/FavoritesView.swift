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
                            Section {
                                ForEach(app.bookmarks.favoriteRoutes) { favorite in
                                    NavigationLink(value: RouteEtaTarget(routeKey: favorite.routeKey, seq: favorite.seq)) {
                                        routeRow(favorite)
                                    }
                                    .listRowBackground(DesignTokens.surface)
                                }
                                .onDelete { app.bookmarks.removeFavoriteRoutes(at: $0) }
                            } header: {
                                sectionHeader(L10n.t("favorites.routes"))
                            }
                        }
                        if !app.bookmarks.favoriteStops.isEmpty {
                            Section {
                                ForEach(app.bookmarks.favoriteStops) { favorite in
                                    NavigationLink(value: StopTarget(stopId: favorite.id)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(language.isChinese ? L10n.display(favorite.nameZh) : favorite.nameEn)
                                                .font(DesignTokens.bodyMedium)
                                            let count = app.data.routeCount(at: favorite.id)
                                            if count > 0 {
                                                Text("\(count) \(L10n.t("unit.routes"))")
                                                    .font(DesignTokens.footnote)
                                                    .foregroundStyle(DesignTokens.textTertiary)
                                            }
                                        }
                                    }
                                    .listRowBackground(DesignTokens.surface)
                                }
                                .onDelete { app.bookmarks.removeFavoriteStops(at: $0) }
                            } header: {
                                sectionHeader(L10n.t("favorites.stops"))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .appBackground()
                }
            }
            .navigationTitle(L10n.t("favorites.title"))
            .navigationDestination(for: RouteEtaTarget.self) { target in
                RouteEtaView(routeKey: target.routeKey, seq: target.seq)
            }
            .navigationDestination(for: StopTarget.self) { target in
                StopEtaView(stopId: target.stopId)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.caption)
            .foregroundStyle(DesignTokens.textTertiary)
            .textCase(nil)
    }

    private func routeRow(_ favorite: FavoriteRoute) -> some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            RouteBadge(route: favorite.route, entry: app.data.entry(favorite.routeKey))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.t("route.to")) \(language.isChinese ? L10n.display(favorite.destZh) : favorite.destEn)")
                    .font(DesignTokens.bodyMedium)
                Text("\(language.isChinese ? L10n.display(favorite.stopNameZh) : favorite.stopNameEn)")
                    .font(DesignTokens.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
    }
}
