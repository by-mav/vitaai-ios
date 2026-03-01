import SwiftUI

@main
struct VitaAIApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRouter(authManager: container.authManager)
                .environment(\.appContainer, container)
                .preferredColorScheme(.dark)
        }
    }
}
