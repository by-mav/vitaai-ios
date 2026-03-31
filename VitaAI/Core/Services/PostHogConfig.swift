import Foundation
import PostHog

// MARK: - PostHogConfig
//
// Product analytics and session replay for VitaAI iOS.
//
// Configuration:
//   - Skipped entirely in DEBUG builds
//   - Session replay enabled with masked text inputs
//   - Host: PostHog US cloud

enum VitaPostHogConfig {

    // MARK: - Keys

    private static let apiKey = "phc_Lp1EkqO9t2IRymz41phAJUAP3Jm0opa9RyGQfvcsy2t"
    private static let host = "https://us.i.posthog.com"

    // MARK: - Initialize

    /// Bootstraps PostHog SDK. No-op in DEBUG builds.
    static func initialize() {
        #if DEBUG
        return
        #else
        let config = PostHog.PostHogConfig(apiKey: apiKey, host: host)

        // Session replay
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false

        // Capture application lifecycle events (app open, background, etc.)
        config.captureApplicationLifecycleEvents = true

        // Capture screen views automatically
        config.captureScreenViews = true

        // Flush events every 30 seconds
        config.flushAt = 20

        PostHogSDK.shared.setup(config)
        #endif
    }

    // MARK: - User Identification

    /// Identifies the current user for analytics attribution.
    static func identify(userId: String, properties: [String: Any]? = nil) {
        #if !DEBUG
        PostHogSDK.shared.identify(userId, userProperties: properties)
        #endif
    }

    /// Resets user identity on logout.
    static func reset() {
        #if !DEBUG
        PostHogSDK.shared.reset()
        #endif
    }

    // MARK: - Events

    /// Captures a custom analytics event.
    static func capture(event: String, properties: [String: Any]? = nil) {
        #if !DEBUG
        PostHogSDK.shared.capture(event, properties: properties)
        #endif
    }

    /// Captures a screen view event.
    static func screen(name: String, properties: [String: Any]? = nil) {
        #if !DEBUG
        PostHogSDK.shared.screen(name, properties: properties)
        #endif
    }

    // MARK: - Feature Flags

    /// Checks if a feature flag is enabled.
    static func isFeatureEnabled(_ flag: String) -> Bool {
        #if DEBUG
        return false
        #else
        return PostHogSDK.shared.isFeatureEnabled(flag)
        #endif
    }

    /// Reloads feature flags from PostHog.
    static func reloadFeatureFlags() {
        #if !DEBUG
        PostHogSDK.shared.reloadFeatureFlags()
        #endif
    }
}
