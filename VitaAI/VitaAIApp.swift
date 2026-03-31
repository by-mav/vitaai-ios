import SwiftUI
import SwiftData
import UserNotifications

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
}

@main
struct VitaAIApp: App {
    @UIApplicationDelegateAdaptor(VitaAppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()

    init() {
        // Initialize Sentry for crash reporting and performance monitoring.
        // No-op in DEBUG builds. Requires SENTRY_DSN in Info.plist.
        SentryConfig.initialize()

        #if DEBUG
        bootstrapLaunchState()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRouter(authManager: container.authManager)
                .environment(\.appContainer, container)
                .environment(\.subscriptionStatus, container.subscriptionStatus)
                // SwiftData (iOS 17+) - notes/mindmaps local persistence
                .modifier(ModelContainerModifier(container: container))
                .preferredColorScheme(.dark)
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
            if let name = injected.name { defaults.set(name, forKey: "vita_user_name") }
            if let email = injected.email { defaults.set(email, forKey: "vita_user_email") }
            if let image = injected.image { defaults.set(image, forKey: "vita_user_image") }
            return
        }

        guard AppConfig.isE2EDemoMode else { return }

        // Demo mode should look authenticated to the app without leaking a fake API token.
        keychain.delete(key: "vita_session_token")
        keychain.save(key: "vita_user_name", value: AppConfig.demoUserName)
        keychain.save(key: "vita_user_email", value: AppConfig.demoUserEmail)
        defaults.set(AppConfig.demoUserName, forKey: "vita_user_name")
        defaults.set(AppConfig.demoUserEmail, forKey: "vita_user_email")
        defaults.removeObject(forKey: "vita_user_image")

        if !AppConfig.shouldResetOnboarding {
            AppConfig.setOnboardingComplete(true, in: defaults)
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
