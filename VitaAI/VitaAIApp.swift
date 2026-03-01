import SwiftUI

@main
struct VitaAIApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(\.appContainer, container)
                .preferredColorScheme(.dark)
        }
    }
}
