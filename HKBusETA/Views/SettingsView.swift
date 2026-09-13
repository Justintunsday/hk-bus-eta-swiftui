import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("settings.general")) {
                    Picker(selection: Binding(
                        get: { app.settings.language },
                        set: { app.settings.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    } label: {
                        Text(L10n.t("settings.language"))
                    }
                    Picker(selection: Binding(
                        get: { app.settings.etaFormat },
                        set: { app.settings.etaFormat = $0 }
                    )) {
                        ForEach(EtaFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    } label: {
                        Text(L10n.t("settings.etaFormat"))
                    }
                    Toggle(L10n.t("settings.annotateScheduled"), isOn: Binding(
                        get: { app.settings.annotateScheduled },
                        set: { app.settings.annotateScheduled = $0 }
                    ))
                }

                Section(L10n.t("settings.data")) {
                    if let lastLoaded = app.data.lastLoaded {
                        LabeledContent(L10n.t("settings.data.lastUpdated")) {
                            Text(lastLoaded.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Task {
                            isRefreshing = true
                            await app.data.refreshIfNeeded()
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Text(L10n.t("settings.data.refresh"))
                            Spacer()
                            if app.data.isDownloading || isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(app.data.isDownloading || isRefreshing)
                }

                Section(L10n.t("settings.about")) {
                    LabeledContent(L10n.t("settings.version"), value: appVersion)
                    Link(destination: URL(string: "https://hkbus.app")!) {
                        LabeledContent(L10n.t("settings.about.website"), value: "hkbus.app")
                    }
                    Link(destination: URL(string: "https://github.com/hkbus/hk-independent-bus-eta")!) {
                        LabeledContent(L10n.t("settings.about.source"), value: "GitHub")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("settings.about.attribution"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(L10n.t("settings.about.disclaimer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.t("settings.title"))
            .scrollContentBackground(.hidden)
            .appBackground()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
