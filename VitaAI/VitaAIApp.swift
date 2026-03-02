import SwiftUI
import SwiftData

@main
struct VitaAIApp: App {
    @StateObject private var container = AppContainer()

    init() {
        // Initialize Sentry for crash reporting and performance monitoring.
        // No-op in DEBUG builds. Requires SENTRY_DSN in Info.plist.
        SentryConfig.initialize()
    }

    var body: some Scene {
        WindowGroup {
            AppRouter(authManager: container.authManager)
                .environment(\.appContainer, container)
                // Attach the shared ModelContainer so child views that use
                // @Query or @Environment(\.modelContext) receive the same store.
                .modelContainer(container.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
