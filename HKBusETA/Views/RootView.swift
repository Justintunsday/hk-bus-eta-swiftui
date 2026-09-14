import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabView {
            SearchView()
                .id(app.region.id)
                .tabItem { Label(L10n.t("tab.search"), systemImage: "magnifyingglass") }
            NearbyView()
                .id(app.region.id)
                .tabItem { Label(L10n.t("tab.nearby"), systemImage: "location") }
            FavoritesView()
                .tabItem { Label(L10n.t("tab.favorites"), systemImage: "star") }
            SettingsView()
                .tabItem { Label(L10n.t("tab.settings"), systemImage: "gearshape") }
        }
        .tint(DesignTokens.accent)
        .id(app.settings.language.rawValue)
        .task {
            app.location.startUpdating()
            app.resolveAutoRegion(location: app.location.location)
        }
        .onChange(of: app.location.location) {
            app.resolveAutoRegion(location: app.location.location)
        }
        .onChange(of: app.settings.selectedRegionID) { app.settings.persist() }
        .onChange(of: app.settings.language) { app.settings.persist() }
        .onChange(of: app.settings.etaFormat) { app.settings.persist() }
        .onChange(of: app.settings.annotateScheduled) { app.settings.persist() }
    }
}

struct DataGate<Content: View>: View {
    @Environment(AppState.self) private var app
    @ViewBuilder let content: () -> Content

    private var byteText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: app.data.downloadedBytes)) / \(formatter.string(fromByteCount: app.data.totalBytes))"
    }

    var body: some View {
        if app.data.db != nil {
            content()
        } else if app.data.isDownloading || app.data.isLoading {
            VStack(spacing: DesignTokens.Spacing.m) {
                if app.data.totalBytes > 0 {
                    ProgressView(value: app.data.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 240)
                    Text("\(Int(app.data.downloadProgress * 100))% · \(byteText)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .tint(DesignTokens.accent)
                }
                Text(app.data.statusText.isEmpty ? L10n.t("status.loading") : app.data.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if app.data.db == nil {
                    Text(L10n.t("status.firstLaunchHint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
