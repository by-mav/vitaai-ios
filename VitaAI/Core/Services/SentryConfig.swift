import Foundation
import Sentry

// MARK: - SentryConfig
//
// Crash reporting and performance monitoring for VitaAI iOS.
//
// Configuration:
//   - Skipped entirely in DEBUG builds (no noise in development)
//   - tracesSampleRate = 0.2 (20% of transactions)
//   - profilesSampleRate = 0.1 (10% of traced transactions)
//   - environment = "production" (release) / "development" (debug)
//   - App hang tracking enabled (equivalent to ANR detection on Android)
//   - Screenshot attachment enabled for crash context

enum SentryConfig {

    // MARK: - DSN
    // Read from Info.plist so it is never hardcoded in source.
    private static var dsn: String {
        Bundle.main.infoDictionary?["SENTRY_DSN"] as? String ?? ""
    }

    // MARK: - Initialize

    /// Bootstraps Sentry SDK. No-op in DEBUG builds.
    static func initialize() {
        #if DEBUG
        // Skip Sentry in debug builds to avoid noise.
        return
        #else
        guard !dsn.isEmpty else {
            // DSN not configured yet -- safe to skip silently.
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = "production"

            // Performance Monitoring
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.1

            // Crash & hang detection
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2.0  // 2 seconds

            // Stack traces & breadcrumbs
            options.attachStacktrace = true
            options.enableSwizzling = true
            options.enableAutoBreadcrumbTracking = true

            // Auto performance tracing (view controllers, HTTP requests)
            options.enableAutoPerformanceTracing = true

            // Session tracking
            options.enableAutoSessionTracking = true

            // Screenshots for crash context
            options.attachScreenshot = true

            // User interaction tracing
            options.enableUserInteractionTracing = true

            // Diagnostics -- only warnings and above
            options.diagnosticLevel = .warning
        }
        #endif
    }

    // MARK: - Capture Helpers

    /// Captures a non-fatal error manually (e.g. network errors, unexpected states).
    static func capture(error: Error, context: [String: Any]? = nil) {
        #if !DEBUG
        SentrySDK.capture(error: error) { scope in
            if let context = context {
                scope.setContext(value: context, key: "custom")
            }
        }
        #endif
    }

    /// Captures a message at a given severity level.
    static func capture(message: String) {
        #if !DEBUG
        SentrySDK.capture(message: message)
        #endif
    }

    // MARK: - User Context

    /// Sets the authenticated user so Sentry events are attributed correctly.
    static func setUser(id: String, email: String?) {
        #if !DEBUG
        let user = User(userId: id)
        user.email = email
        SentrySDK.setUser(user)
        #endif
    }

    /// Clears the user context on logout.
    static func clearUser() {
        #if !DEBUG
        SentrySDK.setUser(nil)
        #endif
    }

    // MARK: - Breadcrumbs

    /// Adds a breadcrumb for debugging context.
    static func addBreadcrumb(message: String, category: String, data: [String: Any]? = nil) {
        #if !DEBUG
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }
}
