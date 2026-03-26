import SwiftUI

struct AppRouter: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.appContainer) private var container
    @State private var router = Router()

    var body: some View {
        Group {
            if authManager.isLoading {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            } else if !authManager.isLoggedIn {
                LoginScreen(authManager: authManager)
            } else if !isOnboarded {
                OnboardingScreen {
                }
            } else {
                MainTabView(router: router, authManager: authManager)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isOnboarded: Bool {
        UserDefaults.standard.bool(forKey: "vita_is_onboarded")
    }
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @Environment(\.subscriptionStatus) private var subStatus
    @State private var showChat = false

    var body: some View {
        // Shell OUTSIDE NavigationStack
        ZStack {
            // Layer 1: Background edge-to-edge
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()

            // Layer 2: TopBar + Content
            VStack(spacing: 0) {
                VitaTopBar(
                    userName: authManager.userName,
                    userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                    onAvatarTap: { router.selectedTab = .progresso }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // NavigationStack wraps ONLY content, not the shell
                NavigationStack(path: $router.path) {
                    activeTabView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: 80)
                        }
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(for: route)
                        }
                }
                .toolbar(.hidden, for: .navigationBar)
            }

            // Layer 3: TabBar always visible at bottom
            VStack {
                Spacer()
                VitaTabBar(selectedTab: $router.selectedTab) {
                    showChat = true
                }
            }
            .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $showChat) {
            VitaChatScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .vitaXpToastHost(container.gamificationEvents.xpToast)
        .overlay {
            ZStack {
                VitaLevelUpOverlay(event: container.gamificationEvents.levelUpEvent)
                VitaBadgeUnlockOverlay(event: container.gamificationEvents.badgeEvent)
            }
            .allowsHitTesting(false)
        }
        .task {
            await subStatus.refresh()
            // await PushManager.shared.requestPermission()
            Task {
                let stats = try? await container.api.getGamificationStats()
                let previousLevel = stats?.level
                if let result = try? await container.api.logActivity(action: "daily_login") {
                    container.gamificationEvents.handleActivityResponse(result, previousLevel: previousLevel)
                }
            }
        }
    }

    // MARK: - Active Tab Content

    @ViewBuilder
    private var activeTabView: some View {
        switch router.selectedTab {
        case .home:
            DashboardScreen(
                onNavigateToFlashcards: { router.selectedTab = .estudos },
                onNavigateToSimulados: { router.navigate(to: .simuladoHome) },
                onNavigateToPdfs: { router.selectedTab = .estudos },
                onNavigateToMaterials: { router.selectedTab = .estudos }
            )
        case .estudos:
            EstudosScreen(
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) },
                onNavigateToNotebooks: { router.navigate(to: .notebookList) },
                onNavigateToMindMaps: { router.navigate(to: .mindMapList) },
                onNavigateToFlashcardSession: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) },
                onNavigateToFlashcardStats: { router.navigate(to: .flashcardStats) },
                onNavigateToPdfViewer: { url in router.navigate(to: .pdfViewer(url: url.absoluteString)) },
                onNavigateToSimulados: { router.navigate(to: .simuladoHome) },
                onNavigateToOsce: { router.navigate(to: .osce) },
                onNavigateToAtlas: { router.navigate(to: .atlas3D) },
                onNavigateToCourseDetail: { courseId, colorIdx in router.navigate(to: .courseDetail(courseId: courseId, colorIndex: colorIdx)) },
                onNavigateToProvas: { router.navigate(to: .provas) }
            )
        case .faculdade:
            AgendaScreen()
        case .progresso:
            ProfileScreen(
                authManager: authManager,
                onNavigateToAbout: { router.navigate(to: .about) },
                onNavigateToAppearance: { router.navigate(to: .appearance) },
                onNavigateToNotifications: { router.navigate(to: .notifications) },
                onNavigateToConnections: { router.navigate(to: .connections) },
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) },
                onNavigateToWebAluno: { router.navigate(to: .webalunoConnect) },
                onNavigateToInsights: { router.navigate(to: .insights) },
                onNavigateToTrabalhos: { router.navigate(to: .trabalhos) },
                onNavigateToPaywall: { router.navigate(to: .paywall) },
                onNavigateToActivity: { router.navigate(to: .activityFeed) }
            )
        }
    }

    // MARK: - Route Destination

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        switch route {
        case .notebookList:
            NotebookListScreen(
                store: container.notebookStore,
                onBack: { router.goBack() },
                onOpenNotebook: { id in
                    router.navigate(to: .notebookEditor(notebookId: id.uuidString))
                }
            )
        case .notebookEditor(let idString):
            let uuid = UUID(uuidString: idString) ?? UUID()
            EditorScreen(
                notebookId: uuid,
                store: container.notebookStore,
                onBack: { router.goBack() }
            )
        case .mindMapList:
            MindMapListView(
                store: container.mindMapStore,
                onBack: { router.goBack() },
                onOpenMindMap: { id in
                    router.navigate(to: .mindMapEditor(id: id))
                }
            )
        case .mindMapEditor(let id):
            MindMapEditorView(
                mindMapId: id,
                store: container.mindMapStore,
                onBack: { router.goBack() }
            )
        case .pdfViewer(let urlString):
            if let url = URL(string: urlString) {
                PdfViewerScreen(url: url, onBack: { router.goBack() })
            } else {
                EmptyView()
            }
        case .flashcardSession(let deckId):
            FlashcardSessionScreen(
                deckId: deckId,
                onBack: { router.goBack() },
                onFinished: { router.goBack() }
            )
        case .flashcardStats:
            FlashcardStatsView(onBack: { router.goBack() })
        case .simuladoHome:
            SimuladoHomeScreen(
                onBack: { router.goBack() },
                onNewSimulado: { router.navigate(to: .simuladoConfig) },
                onOpenSession: { id in router.navigate(to: .simuladoSession(attemptId: id)) },
                onOpenResult: { id in router.navigate(to: .simuladoResult(attemptId: id)) },
                onOpenDiagnostics: { router.navigate(to: .simuladoDiagnostics) }
            )
        case .simuladoConfig:
            SimuladoConfigScreen(
                onBack: { router.goBack() },
                onStartSession: { id in
                    router.path.removeLast()
                    router.navigate(to: .simuladoSession(attemptId: id))
                }
            )
        case .simuladoSession(let attemptId):
            SimuladoSessionScreen(
                attemptId: attemptId,
                onBack: { router.goBack() },
                onFinished: { id in
                    router.path.removeLast()
                    router.navigate(to: .simuladoResult(attemptId: id))
                }
            )
        case .simuladoResult(let attemptId):
            SimuladoResultScreen(
                attemptId: attemptId,
                onBack: { router.goBack() },
                onReview: { router.navigate(to: .simuladoReview(attemptId: attemptId)) },
                onNewSimulado: {
                    router.path.removeLast()
                    router.navigate(to: .simuladoConfig)
                }
            )
        case .simuladoReview(let attemptId):
            SimuladoReviewScreen(
                attemptId: attemptId,
                onBack: { router.goBack() }
            )
        case .simuladoDiagnostics:
            SimuladoDiagnosticsScreen(
                onBack: { router.goBack() }
            )
        case .canvasConnect:
            CanvasConnectScreen(
                onBack: { router.goBack() }
            )
        case .webalunoConnect:
            WebAlunoConnectScreen(
                onBack: { router.goBack() }
            )
        case .googleCalendarConnect:
            GoogleCalendarConnectScreen(
                onBack: { router.goBack() }
            )
        case .googleDriveConnect:
            GoogleDriveConnectScreen(
                onBack: { router.goBack() }
            )
        case .insights:
            InsightsScreen()
        case .trabalhos:
            TrabalhoScreen()
        case .about:
            AboutScreen()
        case .appearance:
            AppearanceScreen()
        case .notifications:
            NotificationSettingsScreen()
        case .connections:
            ConnectionsScreen(
                onCanvasConnect: { router.navigate(to: .canvasConnect) },
                onWebAlunoConnect: { router.navigate(to: .webalunoConnect) },
                onGoogleCalendarConnect: { router.navigate(to: .googleCalendarConnect) },
                onGoogleDriveConnect: { router.navigate(to: .googleDriveConnect) },
                onBack: { router.goBack() }
            )
        case .paywall:
            VitaPaywallScreen(onDismiss: { router.goBack() })
        case .atlas3D:
            AtlasWebViewScreen(onBack: { router.goBack() })
        case .osce:
            OsceScreen(onBack: { router.goBack() })
        case .activityFeed:
            ActivityFeedScreen(
                onBack: { router.goBack() },
                onLeaderboard: { router.navigate(to: .leaderboard) }
            )
        case .leaderboard:
            LeaderboardScreen(onBack: { router.goBack() })
        case .courseDetail(let courseId, let colorIndex):
            CourseDetailScreen(
                courseId: courseId,
                folderColor: FolderPalette.color(forIndex: colorIndex),
                onBack: { router.goBack() },
                onNavigateToPdfViewer: { url in
                    router.navigate(to: .pdfViewer(url: url.absoluteString))
                },
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) }
            )
        case .provas:
            ProvasScreen(onBack: { router.goBack() })
        case .achievements:
            AchievementsScreen(onBack: { router.goBack() })
        case .planner:
            PlannerScreen(
                onBack: { router.goBack() },
                onNavigate: { route in router.navigate(to: route) }
            )
        case .toolManager:
            ToolManagerScreen(
                onBack: { router.goBack() },
                onSave: { _ in router.goBack() }
            )
        default:
            EmptyView()
        }
    }
}
