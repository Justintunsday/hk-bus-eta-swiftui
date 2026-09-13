import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label(L10n.t("tab.search"), systemImage: "magnifyingglass") }
            NearbyView()
                .tabItem { Label(L10n.t("tab.nearby"), systemImage: "location") }
            FavoritesView()
                .tabItem { Label(L10n.t("tab.favorites"), systemImage: "star") }
            SettingsView()
                .tabItem { Label(L10n.t("tab.settings"), systemImage: "gearshape") }
        }
        .tint(DesignTokens.accent)
        .id(app.settings.language)
        .onChange(of: app.settings.language) { app.settings.persist() }
        .onChange(of: app.settings.etaFormat) { app.settings.persist() }
        .onChange(of: app.settings.annotateScheduled) { app.settings.persist() }
    }
}

struct DataGate<Content: View>: View {
    @Environment(AppState.self) private var app
    @ViewBuilder let content: () -> Content

    var body: some View {
        if app.data.db != nil {
            content()
        } else if app.data.isDownloading || app.data.isLoading {
            VStack(spacing: DesignTokens.Spacing.m) {
                ProgressView()
                    .tint(DesignTokens.accent)
                Text(app.data.statusText.isEmpty ? L10n.t("status.loading") : app.data.statusText)
                    .font(DesignTokens.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
        } else {
            ContentUnavailableView {
                Label(L10n.t("error.noData.title"), systemImage: "wifi.exclamationmark")
            } description: {
                Text(app.data.errorMessage ?? L10n.t("error.noData.message"))
            } actions: {
                Button(L10n.t("common.retry")) {
                    Task { await app.data.refreshIfNeeded() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
