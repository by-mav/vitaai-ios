import SwiftUI
import OSLog
import SwiftData
import UserNotifications
import BackgroundTasks

// MARK: - AppDelegate (Push Notifications)

class VitaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Silent portal crawler pushes were removed with the Canvas PAT/API pivot.
    /// Data sync now runs server-side from stored tokens, not from background
    /// WKWebView sessions.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let type = userInfo["type"] as? String ?? ""
        NSLog("[PushBG] Silent push received: type=%@", type)
        completionHandler(.noData)
    }

    // Show push banners while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            PushManager.shared.willPresent(notification, completionHandler: completionHandler)
        }
    }

    // Handle notification tap — navigate via deep link
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Backend sends "deepLink": "vitaai://trabalho/{id}" in push payload
        if let deepLinkStr = userInfo["deepLink"] as? String,
           let url = URL(string: deepLinkStr) {
            Task { @MainActor in
                // Post via onOpenURL handler already wired in AppRouter
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }
}

@main
struct VitaAIApp: App {
    @UIApplicationDelegateAdaptor(VitaAppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()

    init() {
        // Make scroll views transparent so VitaAmbientBackground shows through content gaps
        UIScrollView.appearance().backgroundColor = .clear

        // Boot observability FIRST so nothing else is invisible.
        SentryConfig.initialize()
        VitaAnalytics.initialize()
        Self.logBootConfig()

        #if DEBUG
        bootstrapLaunchState()
        #endif
    }

    /// Logs the active backend URL and build environment at boot.
    /// Visible via `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.bymav.vitaai"'`
    /// (no Xcode debugger needed). Also breadcrumbed to Sentry for every session.
    private static func logBootConfig() {
        let logger = Logger(subsystem: "com.bymav.vitaai", category: "boot")
        let env = AppConfig.environment == .development ? "DEV" : "PROD"
        let api = AppConfig.apiBaseURL
        let auth = AppConfig.authBaseURL
        logger.notice("[BOOT] env=\(env, privacy: .public) api=\(api, privacy: .public) auth=\(auth, privacy: .public)")
        SentryConfig.addBreadcrumb(
            message: "app boot",
            category: "boot",
            data: ["environment": env, "apiBaseURL": api, "authBaseURL": auth]
        )
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            #if GALLERY_MODE
            GalleryView()
            #else
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--preview-onboarding") {
                    VitaOnboarding(
                        userName: "Rafael",
                        onLogout: nil,
                        onComplete: {}
                    )
                } else {
                    AppRouter(authManager: container.authManager)
                }
                #else
                AppRouter(authManager: container.authManager)
                #endif
            }
                .environment(\.appContainer, container)
                .environment(\.appData, container.dataManager)
                .environment(\.subscriptionStatus, container.subscriptionStatus)
                // SwiftData (iOS 17+) - notes/mindmaps local persistence
                .modifier(ModelContainerModifier(container: container))
                .preferredColorScheme(.dark)
            #endif
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // Foreground gold-standard 2026 (camadas em cascata):
                // 1. RealtimeStream SSE — push em ms quando algo muda no backend
                // 2. Polling 30s — fallback se SSE der down
                // 3. silentRefresh imediato — cobre app vindo de bg apos longo tempo
                container.realtimeStream.connect()
                Task { await container.dataManager.silentRefresh() }
                container.dataManager.startForegroundPolling()
            case .background:
                // Para tudo; BGAppRefreshTask cuida dos refreshes oportunistas
                container.realtimeStream.disconnect()
                container.dataManager.stopForegroundPolling()
                Self.scheduleBackgroundRefresh()
            case .inactive:
                container.dataManager.stopForegroundPolling()
            @unknown default:
                break
            }
        }
        .backgroundTask(.appRefresh(Self.bgRefreshIdentifier)) {
            // iOS chamou nossa task: refetcha dados e re-agenda pra proxima.
            // Window de execucao: ~30s. silentRefresh respeita throttle 60s
            // mas em BG queremos forcar — bypass via forceRefresh.
            await container.dataManager.forceRefresh()
            Self.scheduleBackgroundRefresh()
        }
    }

    // MARK: - Background refresh scheduling

    static let bgRefreshIdentifier = "com.bymav.vitaai.refresh"

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgRefreshIdentifier)
        // earliestBeginDate = hint pro iOS, nao guarantia. iOS decide quando
        // realmente executa (depende de battery, network, padrao de uso).
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NSLog("[bg-refresh] failed to schedule: \(error)")
        }
    }
}

private extension VitaAIApp {
    func bootstrapLaunchState() {
        let defaults = UserDefaults.standard
        let keychain = KeychainHelper.shared

        if AppConfig.shouldResetOnboarding {
            AppConfig.setOnboardingComplete(false, in: defaults)
        }

        if let injected = AppConfig.injectedSession {
            keychain.save(key: "vita_session_token", value: injected.token)
            // Sessão injetada é um caminho explícito de QA/CI: sem este estado,
            // o app salva o token mas volta para o splash no próximo relaunch.
            AppConfig.setOnboardingComplete(true, in: defaults)
            if let name = injected.name { defaults.set(name, forKey: "vita_user_name") }
            if let email = injected.email { defaults.set(email, forKey: "vita_user_email") }
            if let image = injected.image { defaults.set(image, forKey: "vita_user_image") }
        }
    }
}

// MARK: - SwiftData Compatibility (iOS 17+)
struct ModelContainerModifier: ViewModifier {
    let container: AppContainer

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.modelContainer(container.modelContainer)
        } else {
            content // SwiftData not available on iOS 16
        }
    }
}
