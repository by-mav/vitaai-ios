import SwiftUI

// Clears ONLY the UINavigationController and its child view controllers' backgrounds.
// Applied as a zero-size overlay inside NavigationStack content so the outer
// VitaAmbientBackground (full screen) shows through seamlessly.
/// Custom UIView that clears all superview backgrounds on every layout pass.
private final class ClearBackgroundUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        clearChain()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        clearChain()
    }
    private func clearChain() {
        var view: UIView? = self
        while let parent = view?.superview {
            parent.backgroundColor = .clear
            view = parent
        }
    }
}

/// Placed inside each pushed route to clear UIKit hosting backgrounds.
private struct HostingClearerView: UIViewRepresentable {
    func makeUIView(context: Context) -> ClearBackgroundUIView {
        let v = ClearBackgroundUIView()
        v.backgroundColor = .clear
        v.isHidden = true
        return v
    }
    func updateUIView(_ uiView: ClearBackgroundUIView, context: Context) {}
}

private struct NavControllerBackgroundClearer: UIViewRepresentable {
    var pathCount: Int  // triggers updateUIView on every push/pop

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        clearNavBackgrounds(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        clearNavBackgrounds(from: uiView)
    }

    private func clearNavBackgrounds(from view: UIView) {
        func doClear() {
            var responder: UIResponder? = view
            while let next = responder?.next {
                if let nc = next as? UINavigationController {
                    nc.view.backgroundColor = .clear
                    nc.viewControllers.forEach { $0.view.backgroundColor = .clear }
                    return
                }
                responder = next
            }
        }
        DispatchQueue.main.async { doClear() }
        // Delayed pass catches VCs mid-push that weren't ready on first pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { doClear() }
    }
}

struct AppRouter: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.appContainer) private var container
    @AppStorage("vita_is_onboarded") private var isOnboardedStored = false
    @AppStorage("vita_onboarding_done") private var legacyOnboardingStored = false
    @State private var router = Router()
    @State private var profileChecked = false
    @State private var needsOnboarding = false

    var body: some View {
        Group {
            if authManager.isLoading || (authManager.isLoggedIn && !profileChecked) {
                // Show loading while auth is initializing OR profile check is pending.
                // CRITICAL: do NOT show MainTabView before profileChecked — it fires
                // background API calls (gamification, subscriptions) that can 401 and
                // trigger global logout before onboarding even starts.
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    VitaHeartbeatLoader(orbSize: 96)
                }
            } else if !authManager.isLoggedIn {
                LoginScreen(authManager: authManager)
            } else if needsOnboarding {
                VitaOnboarding(
                    userName: authManager.userName ?? "",
                    onLogout: {
                        authManager.logout()
                    }
                ) {
                    isOnboardedStored = true
                    legacyOnboardingStored = true
                    needsOnboarding = false
                }
            } else {
                MainTabView(router: router, authManager: authManager)
            }
        }
        .task(id: authManager.isLoggedIn) {
            // First-launch pasteboard sniff (one-time) pra capturar referral
            // que veio via App Store install (sem Universal Link tap).
            ReferralCaptureService.shared.checkPasteboardForReferral()

            guard authManager.isLoggedIn else {
                profileChecked = false
                needsOnboarding = false
                return
            }
            do {
                let profile = try await container.api.getProfile()
                NSLog("[AppRouter] getProfile OK onboardingCompleted=\(String(describing: profile.onboardingCompleted)) university=\(String(describing: profile.university))")
                if profile.onboardingCompleted != true {
                    needsOnboarding = true
                    isOnboardedStored = false
                    legacyOnboardingStored = false
                } else {
                    needsOnboarding = false
                    isOnboardedStored = true
                }
            } catch let error as APIError {
                // 401 = token expired — let the global handler deal with it,
                // but do NOT set needsOnboarding (we're about to be logged out).
                if case .unauthorized = error {
                    NSLog("[AppRouter] getProfile 401 — token expired, logout imminent")
                    profileChecked = true
                    return
                }
                // ALL non-401 API errors (404 HTML page, 500, decode, etc) →
                // do NOT force onboarding. Backend dev returns 404 HTML when
                // routes are stale (canvas/files etc.) and that has nothing to
                // do with profile state. Onboarding flag is now ONLY set from
                // a 200 profile with onboardingCompleted=false (incident
                // 2026-04-25_atlas-focus-mode-empty-viewport.md).
                NSLog("[AppRouter] getProfile API error: \(error) — skipping onboarding check")
                needsOnboarding = false
            } catch {
                // Network error / timeout — DON'T force onboarding.
                // The user may be fully onboarded but temporarily offline.
                NSLog("[AppRouter] getProfile network error: \(error) — skipping onboarding check")
                needsOnboarding = false
            }
            profileChecked = true

            // Auto-redeem referral pendente (Universal Link, pasteboard ou
            // captura via vitaai://r/CODE). Idempotente, fire-and-forget.
            await ReferralCaptureService.shared.redeemPendingIfAny(api: container.api)
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            let result = DeepLinkHandler.shared.parse(url: url)
            switch result {
            case .navigate(let route):
                switch route {
                case .home:      router.selectedTab = .home
                case .estudos:   router.selectedTab = .estudos
                case .faculdade: router.selectedTab = .faculdade
                case .progresso: router.selectedTab = .progresso
                case .profile:   router.selectedTab = .progresso
                case .paywall:   router.navigate(to: .paywall)
                case .trabalhoDetail:
                    router.selectedTab = .faculdade
                    // Small delay so tab switch completes before push
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        router.navigate(to: route)
                    }
                case .qbank, .qbankSession(_, _), .simuladoHome, .transcricao, .atlas3D, .osce,
                     .provas, .trabalhos, .flashcardHome, .flashcardSession:
                    // Sub-features de Estudos: ao chegar via deep link,
                    // ative a tab Estudos pra bottom nav refletir o contexto.
                    // Sem isso o bottom nav fica em Home (default) enquanto
                    // user navega QBank — UX confuso (Rafael 2026-04-27 A5 audit).
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        router.navigate(to: route)
                    }
                default:         router.navigate(to: route)
                }
            case .integrationCallback(let provider):
                // OAuth finished — navigate to connections and reload
                router.navigate(to: .connections)
                // Post notification so ConnectorsViewModel reloads
                NotificationCenter.default.post(name: .integrationOAuthCompleted, object: provider)
            case .reviewToken(let token):
                // App Store reviewer deep link — sign into demo account.
                Task { await authManager.signInWithReviewToken(token) }
            case .referralCode(let code, let source):
                // Captura referral code (Universal Link /r/CODE ou vitaai://r/CODE).
                // Persiste em UserDefaults pra ser consumido após auth + onboarding.
                ReferralCaptureService.shared.captureCode(code: code, source: source)
                if authManager.isLoggedIn && profileChecked && !needsOnboarding {
                    // Já tá logado e onboarded — redime imediato.
                    Task { await ReferralCaptureService.shared.redeemPendingIfAny(api: container.api) }
                }
                // Senão, AppRouter task chama redeemPendingIfAny após auth check.
            case .sharedAudioImport(let importId):
                // VitaAIShare extension copiou áudio pro App Group. Navega pra
                // Transcrição e posta notification que TranscricaoViewModel consome
                // (chamando SharedImportStore.find + LocalStore.save + upload R2).
                router.selectedTab = .estudos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    router.navigate(to: .transcricao)
                    NotificationCenter.default.post(
                        name: .shareAudioImported,
                        object: importId
                    )
                }
            default: break
            }
        }
    }


    // Note: onboarding check is now fully handled by the `needsOnboarding` state
    // set from the profile check in `.task(id:)`. The `isOnboardedStored` and
    // `legacyOnboardingStored` flags are kept as fallback for offline launches.
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @Environment(\.subscriptionStatus) private var subStatus
    @ObservedObject private var pushManager = PushManager.shared
    @State private var showChat = false
    /// Optional pre-filled prompt sent into VitaChatScreen on its next open.
    /// Set by Atlas 3D's "Perguntar pra VITA" so the chat lands with the
    /// student's question already submitted; cleared after consumption.
    @State private var chatInitialPrompt: String? = nil
    @State private var showSettingsPanel = false
    @State private var showNotifPopout = false
    @State private var dashboardSubtitle: String = ""
    /// True when a descendant screen (e.g. PdfViewerScreen fullscreen) asks for
    /// the chrome to go away. Hides TopBar, Breadcrumb, TabBar, safe-area inset.
    @State private var isImmersiveMode: Bool = false
    @State private var navVisibility = NavVisibility()

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--vita-skin-demo") {
            SkinAppearanceScreen()
        } else {
            mainShell
        }
    }

    private var mainShell: some View {
        GeometryReader { shellGeo in
        // Shell OUTSIDE NavigationStack
        ZStack {
            if isHomeRoot {
                VitaHomeGrassBackdrop()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Content owns the layout; Home chrome floats over the map so the
            // grassy world stays continuous instead of reserving a top bar row.
            VStack(spacing: 0) {
                Color.clear.frame(height: 0)
                    .onChange(of: router.selectedTab) { _, _ in navVisibility.reset() }
                    .onChange(of: router.path.count) { _, _ in navVisibility.reset() }

                ZStack(alignment: .topTrailing) {
                    NavigationStack(path: $router.path) {
                        activeTabView
                            .environment(\.navVisibility, navVisibility)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .overlay(alignment: .topLeading) {
                                NavControllerBackgroundClearer(pathCount: router.path.count)
                                    .frame(width: 0, height: 0)
                            }
                            // Liquid Glass: conteúdo passa por baixo da TabBar
                            // E do home indicator — `.ignoresSafeArea(.container,
                            // edges: .bottom)` libera scroll até o pixel final.
                            .ignoresSafeArea(.container, edges: .bottom)
                            .navigationDestination(for: Route.self) { route in
                                routeDestination(for: route)
                            }
                    }
                    .frame(width: shellGeo.size.width, height: shellGeo.size.height)
                    .background(.clear)
                    .scrollContentBackground(.hidden)
                    .toolbar(.hidden, for: .navigationBar)
                    .enableSwipeBack(router: router)
                    .overlay(alignment: .top) {
                        if shouldShowGlobalTopBar {
                            VitaTopBar(
                                userName: authManager.userName,
                                userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                                subtitle: dashboardSubtitle,
                                level: container.gamificationEvents.currentLevel,
                                streak: container.dashboardViewModel.streakDays,
                                xpProgress: container.gamificationEvents.currentXpProgress,
                                xpToast: container.gamificationEvents.xpToast,
                                blendsWithHome: isHomeRoot,
                                onAvatarTap: { router.selectedTab = .progresso },
                                onMenuTap: {
                                    withAnimation(.spring(duration: 0.5, bounce: 0.18)) { showNotifPopout = false }
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                        showSettingsPanel = true
                                    }
                                }
                            )
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isHomeRoot {
                            VitaHomeStudyDock(
                                onFlashcards: { openHomeStudy(.flashcardHome()) },
                                onQBank: { openHomeStudy(.qbank) },
                                onSimulados: { openHomeStudy(.simuladoHome) },
                                onTranscricao: { openHomeStudy(.transcricao) }
                            )
                            .padding(.horizontal, 14)
                            .padding(.bottom, 86)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if !isImmersiveMode || isHomeRoot {
                            VitaTabBar(selectedTab: Binding(
                                get: { router.selectedTab },
                                set: { newTab in
                                    // Switching to a different tab must always start at that tab's
                                    // root — otherwise the NavigationStack re-uses the path from
                                    // the previous tab and the user lands on a stale sub-page
                                    // (bug noted 2026-04-24 when Faculdade re-opened an old screen).
                                    if newTab != router.selectedTab { router.popToRoot() }
                                    router.selectedTab = newTab
                                }
                            ), homeGlass: isHomeRoot, onCenterTap: {
                                withAnimation(.easeInOut(duration: 0.25)) { showChat.toggle() }
                            }, onTabReselect: { _ in
                                router.popToRoot()
                            })
                            .ignoresSafeArea(.keyboard)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // VitaChatScreen movido pro ZStack root (abaixo) pra ficar
                    // ACIMA do backdrop blur global. Rafael 2026-04-27.

                }
            }
            // NotifPopout movido pro ZStack root (abaixo) pra ficar
            // ACIMA do backdrop blur compartilhado.

            // MARK: - Backdrop blur (notif/chat ofuscam conteúdo)
            // Rafael 2026-04-25: ao abrir notif/chat, fundo fica
            // levemente ofuscado pra dar profundidade — padrão Apple
            // Shortcuts / context menus. Tap dismissa qualquer popout.
            // 2026-04-27: showChat também ativa o backdrop — Rafael quer
            // "tudo fora do VitaChat com o efeito do menu hamburguer".
            if showNotifPopout || showChat {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                            showNotifPopout = false
                            // showChat NÃO dismissa via tap-out (Rafael não pediu)
                        }
                    }
                    .zIndex(199)
            }

            // MARK: - VitaChat overlay (acima do backdrop, abaixo dos popouts hambúrguer)
            // Movido pro ZStack root (Rafael 2026-04-27): app inteiro atrás
            // fica ofuscado pelo backdrop blur quando chat aberto.
            if showChat {
                VitaChatScreen(
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) { showChat = false }
                        chatInitialPrompt = nil
                    },
                    initialPrompt: chatInitialPrompt
                )
                .padding(.top, 60)    // espaço pra TopBar continuar visível atrás
                .padding(.bottom, 80) // espaço pra TabBar continuar visível atrás
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(199)
            }

            // MARK: - Notification Popout (acima do backdrop blur)
            if showNotifPopout {
                VitaNotifPopout(
                    onDismiss: {
                        withAnimation(.spring(duration: 0.5, bounce: 0.18)) { showNotifPopout = false }
                    },
                    onSettingsTap: {
                        withAnimation(.spring(duration: 0.5, bounce: 0.18)) { showNotifPopout = false }
                        router.navigate(to: .notifications)
                    },
                    onNavigate: { route in
                        withAnimation(.spring(duration: 0.5, bounce: 0.18)) { showNotifPopout = false }
                        router.navigateToRoute(route)
                    }
                )
                .padding(.top, 72) // TopBar height + padding
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.88, anchor: .topTrailing)).combined(with: .offset(y: -12)),
                    removal: .opacity.combined(with: .scale(scale: 0.88, anchor: .topTrailing)).combined(with: .offset(y: -12))
                ))
                .animation(.spring(duration: 0.5, bounce: 0.18), value: showNotifPopout)
                .zIndex(200)
            }

            // MARK: - Settings Panel (hamburger)
            if showSettingsPanel {
                ConfiguracoesScreen(
                    authManager: container.authManager,
                    onNavigateToPerfil: { openFromSettings(.profile) },
                    onNavigateToAssinatura: { openFromSettings(.paywall) },
                    onNavigateToDisciplinas: { openFromSettings(.disciplinasConfig) },
                    onNavigateToConnections: { openFromSettings(.connections) },
                    onNavigateToNotifications: { openFromSettings(.notifications) },
                    onNavigateToReferral: { openFromSettings(.referral) },
                    onNavigateToFeedback: { openFromSettings(.feedback) },
                    onNavigateToPrivacyDocuments: { openFromSettings(.privacyDocuments) },
                    onBack: { closeSettingsPanel() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .zIndex(260)
            }

            // Notification popout moved inside content ZStack (below TopNav)
        }
        .frame(width: shellGeo.size.width, height: shellGeo.size.height)
        }
        .environment(router)
        .background {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()
        }
        .onAppear {
            if router.currentPath.isEmpty {
                isImmersiveMode = false
            }
        }
        .onPreferenceChange(ImmersivePreferenceKey.self) { value in
            withAnimation(.easeInOut(duration: 0.25)) {
                isImmersiveMode = value
            }
        }
        .onChange(of: router.path.count) { _, _ in
            // Sync routeStack when user swipes back (UIKit modifies path directly)
            router.syncStackToPath()
            if router.currentPath.isEmpty {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isImmersiveMode = false
                }
            }
        }
        .onChange(of: router.selectedTab) { _, _ in
            // Dismiss popouts and chat on tab change
            showSettingsPanel = false
            withAnimation(.easeInOut(duration: 0.25)) {
                isImmersiveMode = false
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.18)) { showNotifPopout = false }
            if showChat {
                withAnimation(.easeInOut(duration: 0.25)) { showChat = false }
            }
            // When switching tabs, pop all pushed routes so user sees the tab root
            if !router.path.isEmpty {
                router.popToRoot()
            }
        }
        .overlay {
            ZStack {
                VitaLevelUpOverlay(event: container.gamificationEvents.levelUpEvent)
                VitaBadgeUnlockOverlay(event: container.gamificationEvents.badgeEvent)
            }
            .allowsHitTesting(false)
        }
        .vitaXpToastHost(container.gamificationEvents.xpToast)
        .task {
            // Populate subtitle from profile API (reliable source)
            if dashboardSubtitle.isEmpty {
                if let profile = try? await container.api.getProfile(),
                   let uni = profile.university, !uni.isEmpty {
                    let sem = profile.semester.map { " · \($0)º Semestre" } ?? ""
                    dashboardSubtitle = uni + sem
                }
            }
            await subStatus.refresh()
            await PushManager.shared.requestPermission()
            Task {
                let stats = try? await container.api.getGamificationStats()
                if let stats {
                    container.gamificationEvents.updateFromStats(stats)
                }
                let previousLevel = stats?.level
                if let result = try? await container.api.logActivity(action: "daily_login") {
                    container.gamificationEvents.handleActivityResponse(result, previousLevel: previousLevel, source: .dailyLogin)
                }
            }
            // Deferred from AppContainer.init — only sync notes/mindmaps when
            // user is fully onboarded and MainTabView is actually visible.
            if #available(iOS 17, *) {
                Task {
                    await container.noteSyncManager.pull()
                    await container.mindMapSyncManager.pull()
                }
            }
            // Pré-aquece os caches no boot: Dashboard (HeroCard), Progresso e
            // Flashcards. Quando o MainTabView aparece, o cache do Dashboard
            // já está quente e o HeroCard renderiza sem spinner. Tabs Progresso
            // e Flashcards idem quando o user tap.
            Task { await container.dashboardViewModel.loadDashboard() }
            Task { await container.progressoViewModel.loadIfNeeded() }
            Task { _ = try? await container.flashcardsListCache.refresh() }
        }
        // Paywall now navigated via router.navigate(to: .paywall) — no fullScreenCover
    }

    // MARK: - Active Tab Content

    private var shouldShowGlobalTopBar: Bool {
        isHomeRoot
    }

    private var isHomeRoot: Bool {
        router.selectedTab == .home && router.currentPath.isEmpty
    }

    private func openHomeStudy(_ route: Route) {
        PixioHaptics.tap()
        withAnimation(.easeInOut(duration: 0.24)) {
            router.navigate(to: route)
        }
    }

    private func closeSettingsPanel() {
        PixioHaptics.tap()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            showSettingsPanel = false
        }
    }

    private func openFromSettings(_ route: Route) {
        PixioHaptics.tap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) {
            showSettingsPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            router.navigateFromMenu(to: route)
        }
    }

    private func returnToHomeTrail() {
        PixioHaptics.tap()
        withAnimation(.easeInOut(duration: 0.24)) {
            router.popToRoot()
            router.selectedTab = .home
        }
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch router.selectedTab {
        case .home:
            // Home = trilha viva estilo Duolingo (decisão Rafael 2026-06-17).
            // A trilha gamificada é o daily driver da Home; a aba Progresso vira
            // Estatísticas/Conquistas. DashboardScreen segue no codebase (não
            // deletado) caso a gente queira fundir alguns cards depois.
            ProgressoScreen()
        case .estudos:
            EstudosScreen(
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) },
                onNavigateToNotebooks: { router.navigate(to: .notebookList) },
                onNavigateToMindMaps: { router.navigate(to: .mindMapList) },
                onNavigateToFlashcardSession: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) },
                onNavigateToFlashcardStats: { router.navigate(to: .flashcardStats) },
                onNavigateToFlashcardHome: { router.navigate(to: .flashcardHome()) },
                onNavigateToPdfViewer: { url in router.navigate(to: .pdfViewer(url: url.absoluteString)) },
                onNavigateToSimulados: { router.navigate(to: .simuladoHome) },
                onNavigateToOsce: { router.navigate(to: .osce) },
                onNavigateToAtlas: { router.navigate(to: .atlas3D) },
                onNavigateToCourseDetail: { disciplineId, disciplineName in
                    router.navigate(to: .disciplineDetail(disciplineId: disciplineId, disciplineName: disciplineName))
                },
                onNavigateToProvas: { router.navigate(to: .provas) },
                onNavigateToQBank: { router.navigate(to: .qbank) },
                onNavigateToTranscricao: { router.navigate(to: .transcricao) },
                onNavigateToTrabalhos: { router.navigate(to: .trabalhos) }
            )
        case .faculdade:
            JornadaScreen()
        case .progresso:
            // Aba Progresso = Estatísticas/Conquistas (decisão Rafael 2026-06-17).
            // A trilha gamificada virou a Home (ver case .home).
            EstatisticasScreen()
        }
    }

    // MARK: - Route Destination

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        routeView(for: route)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                // Clears UIKit hosting view backgrounds so the single
                // shell VitaAmbientBackground shows through seamlessly
                HostingClearerView()
                    .frame(width: 0, height: 0)
            }
    }

    @ViewBuilder
    private func routeView(for route: Route) -> some View {
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
        case .pdfViewer(let urlString, let title, let documentId, let studioSourceId):
            if let url = URL(string: urlString) {
                PdfViewerScreen(
                    url: url,
                    initialTitle: title,
                    documentId: documentId,
                    studioSourceId: studioSourceId,
                    onOpenStudyPack: { sessionId, mode in
                        router.navigate(to: .qbankSession(sessionId: sessionId, mode: mode))
                    },
                    onBack: { router.goBack() }
                )
            } else {
                EmptyView()
            }
        case .flashcardTopics(let deckId, let deckTitle):
            FlashcardTopicsScreen(
                deckId: deckId,
                deckTitle: deckTitle,
                onBack: { router.goBack() },
                onSelectTopic: { tagPrefix in
                    router.navigate(to: .flashcardSession(deckId: deckId, tagFilter: tagPrefix))
                }
            )
        case .flashcardSession(let deckId, let tagFilter):
            FlashcardSessionScreen(
                deckId: deckId,
                tagFilter: tagFilter,
                onBack: { router.goBack() },
                onFinished: { router.goBack() },
                onOpenSettings: { router.navigate(to: .flashcardSettings) }
            )
        case .flashcardSettings:
            FlashcardSettingsScreen(
                onBack: { router.goBack() }
            )
        case .flashcardStats:
            FlashcardStatsView(onBack: { router.goBack() })
        case .simuladoHome:
            // Fase 4 (2026-04-29): SimuladoBuilderScreen reescrito substitui
            // SimuladoHomeScreen + SimuladoConfigScreen. Tela única com toggle
            // Template/Custom no topo, cronômetro visível, filtros lente-aware.
            SimuladoBuilderScreen(
                onBack: { router.goBack() },
                onSessionCreated: { id in
                    router.navigate(to: .simuladoSession(attemptId: id))
                },
                onOpenAttempt: { attempt in
                    if attempt.finishedAt == nil {
                        router.navigate(to: .simuladoSession(attemptId: attempt.id))
                    } else {
                        router.navigate(to: .simuladoResult(attemptId: attempt.id))
                    }
                }
            )
        case .simuladoConfig:
            // Legacy route — quem ainda chama .simuladoConfig cai no Builder.
            // Pode ser removida do enum em sweep futuro.
            SimuladoBuilderScreen(
                onBack: { router.goBack() },
                onSessionCreated: { id in
                    router.replaceTop(with: .simuladoSession(attemptId: id))
                },
                onOpenAttempt: { attempt in
                    if attempt.finishedAt == nil {
                        router.navigate(to: .simuladoSession(attemptId: attempt.id))
                    } else {
                        router.navigate(to: .simuladoResult(attemptId: attempt.id))
                    }
                }
            )
        case .simuladoSession(let attemptId):
            SimuladoSessionScreen(
                attemptId: attemptId,
                onBack: { router.goBack() },
                onFinished: { id in
                    router.replaceTop(with: .simuladoResult(attemptId: id))
                }
            )
        case .simuladoResult(let attemptId):
            SimuladoResultScreen(
                attemptId: attemptId,
                onBack: { returnToHomeTrail() },
                onReview: { router.navigate(to: .simuladoReview(attemptId: attemptId)) },
                onNewSimulado: {
                    router.replaceTop(with: .simuladoConfig)
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
        case .portalConnect(let type, _):
            if type == "canvas" {
                CanvasTokenEntry(onBack: { router.goBack() })
            } else {
                UnsupportedConnectorScreen(
                    connectorName: University.displayName(for: type),
                    onBack: { router.goBack() }
                )
            }
        // Canvas: pivot 2026-05-07 — token-based via AddTokenSheet (inline pra
        // nao depender de novo arquivo no Xcode project)
        case .canvasConnect:
            CanvasTokenEntry(onBack: { router.goBack() })
        case .insights:
            InsightsScreen()
        case .trabalhos:
            TrabalhoScreen(onOpenDetail: { id in router.navigate(to: .trabalhoDetail(id: id)) })
        case .trabalhoDetail(let id):
            TrabalhoDetailScreen(
                assignmentId: id,
                onBack: { router.goBack() },
                onOpenEditor: { assignmentId in
                    // Editor is presented as fullScreenCover inside TrabalhoDetailScreen
                }
            )
        case .about:
            AboutScreen()
        case .agenda:
            AgendaScreen()
        case .appearance:
            AppearanceScreen()
        case .skinAppearance(let shopTier):
            SkinAppearanceScreen(shopTier: shopTier)
        case .notifications:
            NotificationSettingsScreen()
        case .connections:
            ConnectionsScreen(
                onPortalConnect: { type, defaultUrl in
                    router.navigate(to: .portalConnect(type: type, defaultUrl: defaultUrl))
                },
                onBack: { router.goBack() }
            )
        case .paywall:
            VitaPaywallScreen(onDismiss: { router.goBack() })
        case .atlas3D:
            // VitaChat agora abre POR CIMA do Atlas via sheet local na própria
            // AtlasSceneScreen (mesmo padrão do PdfViewer, Rafael 2026-04-28).
            // Não precisamos mais setar chatInitialPrompt + showChat aqui —
            // antes esse handoff fazia goBack() e perdia a peça selecionada.
            AtlasSceneScreen(
                onBack: { router.goBack() }
            )
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
        case .profile:
            ProfileScreen(
                authManager: authManager,
                onNavigateToConfiguracoes: { router.navigate(to: .configuracoes) },
                onNavigateToAchievements: { router.navigate(to: .achievements) }
            )
        case .configuracoes:
            // Menu hamburguer — ordem Rafael 2026-04-26 (gold-standard).
            // Removed from menu: Aparência, Modo foco, Sobre, Privacy Settings
            // (consolidado em PrivacyDocumentsScreen), Export Data (idem).
            // Routes ainda existem caso outras telas precisem (focusSession, etc).
            ConfiguracoesScreen(
                authManager: container.authManager,
                onNavigateToPerfil: { router.navigate(to: .profile) },
                onNavigateToAssinatura: { router.navigate(to: .paywall) },
                onNavigateToDisciplinas: { router.navigate(to: .disciplinasConfig) },
                onNavigateToConnections: { router.navigate(to: .connections) },
                onNavigateToNotifications: { router.navigate(to: .notifications) },
                onNavigateToReferral: { router.navigate(to: .referral) },
                onNavigateToFeedback: { router.navigate(to: .feedback) },
                onNavigateToPrivacyDocuments: { router.navigate(to: .privacyDocuments) },
                onBack: { router.goBack() }
            )
        case .privacyDocuments:
            PrivacyDocumentsScreen(
                onBack: { router.goBack() },
                onExportData: { router.navigate(to: .exportData) }
            )
        case .privacySettings:
            PrivacySettingsScreen(onBack: { router.goBack() })
        case .exportData:
            ExportDataScreen(onBack: { router.goBack() })
        case .feedback:
            FeedbackScreen(onBack: { router.goBack() })
        case .focusSession:
            FocusSessionScreen(onBack: { router.goBack() })
        case .referral:
            ReferralScreen(onBack: { router.goBack() })
        case .disciplinasConfig:
            DisciplinasConfigScreen(onBack: { router.goBack() })
        case .qbank:
            QBankCoordinatorScreen(onBack: { router.goBack() }, onHome: { returnToHomeTrail() })
        case .qbankSession(let sessionId, let mode):
            QBankCoordinatorScreen(
                onBack: { router.goBack() },
                onHome: { returnToHomeTrail() },
                initialSessionId: sessionId,
                initialMode: mode == "simulado" ? .simulado : .pratica
            )
        case .transcricao:
            TranscricaoScreen(
                onBack: { router.goBack() },
                onOpenStudyPack: { sessionId, mode in
                    router.navigate(to: .qbankSession(sessionId: sessionId, mode: mode))
                }
            )
        case .flashcardHome(let subjectId):
            // Fase 5 (2026-04-29): FlashcardBuilderScreen reescrito substitui
            // FlashcardsListScreen como entry point. Hero + Mode (Revisão/Específico/
            // Novos) + Lente + Drill + Decks grid embaixo + CTA sticky.
            // initialSubjectId pré-seleciona disciplina e abre em mode .specific
            // (Onda 5 restaurou — vem de DisciplineDetailScreen).
            FlashcardBuilderScreen(
                initialSubjectId: subjectId,
                onBack: { router.goBack() },
                onOpenDeck: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) }
            )
        case .disciplineDetail(let disciplineId, let disciplineName):
            DisciplineDetailScreen(
                disciplineId: disciplineId,
                disciplineName: disciplineName,
                onBack: { router.goBack() },
                onNavigateToFlashcards: { _ in router.navigate(to: .flashcardHome(subjectId: disciplineId)) },
                onNavigateToQBank: { router.navigate(to: .qbank) },
                onNavigateToSimulado: { router.navigate(to: .simuladoHome) }
            )
        case .faculdadeDisciplinas:
            FaculdadeDisciplinasScreen()
        case .faculdadeMaterias:
            FaculdadeMateriasScreen(
                onBack: { router.goBack() },
                onNavigateToDiscipline: { id, name in router.navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name)) }
            )
        case .faculdadeDocumentos:
            FaculdadeDocumentosScreen(onBack: { router.goBack() })
        case .faculdadeProfessores:
            FaculdadeProfessoresScreen()
        case .materialFolderDetail(let folderId, let folderName, let folderIcon):
            MaterialFolderDetailScreen(
                folderId: folderId,
                folderName: folderName,
                folderIcon: folderIcon,
                onBack: { router.goBack() }
            )
        default:
            EmptyView()
        }
    }
}

private struct VitaHomeStudyDock: View {
    let onFlashcards: () -> Void
    let onQBank: () -> Void
    let onSimulados: () -> Void
    let onTranscricao: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            actionButton("Cards", icon: "rectangle.on.rectangle.angled", tint: VitaColors.toolFlashcards, action: onFlashcards)
            actionButton("Questões", icon: "checklist", tint: VitaColors.accent, action: onQBank)
            actionButton("Simulados", icon: "doc.text.magnifyingglass", tint: VitaColors.toolSimulados, action: onSimulados)
            actionButton("Áudio", icon: "waveform", tint: VitaColors.toolTranscricao, action: onTranscricao)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(TrailWorld.dockFill.opacity(0.82))
                .overlay(
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                TrailWorld.dockFill.opacity(0.10),
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 0.75))
        )
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            Circle().fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.34),
                                        tint.opacity(0.24),
                                        Color.black.opacity(0.05)
                                    ],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: 32
                                )
                            )
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.38), lineWidth: 0.75))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                }
                .frame(width: 38, height: 38)

                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 66, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomeQuickActionPressStyle())
        .accessibilityLabel(title)
    }
}

private struct HomeQuickActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

/// Pivot 2026-05-07: tela leve que apresenta `AddTokenSheet` como sheet sobre
/// fundo transparente. Substitui PortalConnectScreen webview legacy pra Canvas.
/// Inline aqui pra nao precisar adicionar arquivo novo ao .xcodeproj.
private struct CanvasTokenEntry: View {
    let onBack: () -> Void
    @Environment(\.appContainer) private var container
    @State private var showSheet = true

    var body: some View {
        ZStack {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSheet) {
            AddTokenSheet()
                .environmentObject(container)
                .presentationDetents([.large])
        }
        .onChange(of: showSheet) { _, newValue in
            if !newValue { onBack() }
        }
    }
}

private struct UnsupportedConnectorScreen: View {
    let connectorName: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                Text("\(connectorName) ainda não está disponível")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("O Vita agora conecta portais acadêmicos apenas por API/token oficial.")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                VitaButton(
                    text: "Voltar",
                    action: onBack,
                    variant: .secondary,
                    size: .md
                )
                .padding(.top, 8)
            }
            .padding(24)
        }
        .navigationBarHidden(true)
    }
}
