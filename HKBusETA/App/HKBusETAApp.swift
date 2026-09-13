import SwiftUI

@main
struct HKBusETAApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(\.locale, app.settings.language.locale)
                .task {
                    await app.data.load()
                }
        }
    }
}
