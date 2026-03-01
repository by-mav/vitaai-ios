import SwiftUI

struct AppRouter: View {
    @Environment(\.appContainer) private var container
    @State private var router = Router()

    var body: some View {
        Group {
            if container.authManager.isLoading {
                // Splash
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            } else if !container.authManager.isLoggedIn {
                LoginScreen(authManager: container.authManager)
            } else if !isOnboarded {
                OnboardingScreen {
                    // Force re-check
                }
            } else {
                MainTabView(router: router, authManager: container.authManager)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isOnboarded: Bool {
        // Check synchronously from UserDefaults
        UserDefaults.standard.bool(forKey: "vita_is_onboarded")
    }
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @State private var showChat = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VitaAmbientBackground {
                VStack(spacing: 0) {
                    VitaTopBar(
                        title: router.selectedTab.rawValue,
                        userName: authManager.userName,
                        userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                        onAvatarTap: { router.selectedTab = .profile }
                    )

                    TabView(selection: $router.selectedTab) {
                        DashboardScreen()
                            .tag(TabItem.home)

                        EstudosScreen()
                            .tag(TabItem.estudos)

                        TrabalhoScreen()
                            .tag(TabItem.trabalhos)

                        AgendaScreen()
                            .tag(TabItem.agenda)

                        InsightsScreen()
                            .tag(TabItem.insights)

                        ProfileScreen(authManager: authManager)
                            .tag(TabItem.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }

            VitaTabBar(selectedTab: $router.selectedTab) {
                showChat = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showChat) {
            VitaChatScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
