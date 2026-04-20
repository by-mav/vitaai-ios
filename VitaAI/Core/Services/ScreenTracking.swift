import SwiftUI
import OSLog
import Sentry

// MARK: - ScreenTracking — unified Sentry + PostHog instrumentation per screen
//
// SwiftUI doesn't have per-screen UIViewControllers so auto-instrumentation
// (viewDidAppear) does not fire. This modifier closes that gap:
//
// - Starts a Sentry transaction "ui.load.<name>" on .onAppear
// - Finishes it when the screen's initial data load completes (finishLoad())
// - Fires PostHog screen view with explicit name + properties
// - Adds a Sentry breadcrumb at appear
//
// Usage on any screen:
//
//   DashboardScreen { ... }
//       .trackScreen("Dashboard") { tx in
//           // Optional: give the transaction child spans or tags
//           tx.setTag(value: subjectId, key: "subject_id")
//       }
//
// To mark "data finished loading", call `ScreenLoadContext.finish()` inside
// the screen's .task {} right after data hydration. Example:
//
//   .task {
//       await appData.refreshDashboard()
//       ScreenLoadContext.finish(for: "Dashboard")
//   }
//
// If you don't explicitly finish, the transaction auto-finishes on disappear
// with an 'auto-finished' tag so P95 is still meaningful.

/// Global registry of in-flight screen load transactions, keyed by screen name.
/// Only tracks ONE in-flight transaction per screen at a time — the most recent.
@MainActor
final class ScreenLoadContext {
    static let shared = ScreenLoadContext()

    private var active: [String: Span] = [:]
    private let logger = Logger(subsystem: "com.bymav.vitaai", category: "screen")

    private init() {}

    static func start(name: String, extra: [String: String] = [:]) -> Span {
        shared.logger.notice("[screen.start] \(name, privacy: .public)")
        let tx = SentrySDK.startTransaction(name: "ui.load.\(name)", operation: "ui.load")
        for (k, v) in extra {
            tx.setTag(value: v, key: k)
        }
        shared.active[name] = tx
        return tx
    }

    static func finish(for name: String, status: SentrySpanStatus = .ok) {
        guard let tx = shared.active.removeValue(forKey: name) else { return }
        tx.status = status
        tx.finish()
        shared.logger.notice("[screen.finish] \(name, privacy: .public) status=\(status.rawValue, privacy: .public)")
    }

    static func autoFinishIfAlive(name: String) {
        guard let tx = shared.active.removeValue(forKey: name) else { return }
        tx.setTag(value: "auto-finished-on-disappear", key: "finish_reason")
        tx.finish()
    }
}

// MARK: - View modifier

extension View {
    /// Track this screen with Sentry + PostHog. Call `ScreenLoadContext.finish(for:)`
    /// when your `.task {}` finishes loading data for a real ms duration.
    func trackScreen(
        _ name: String,
        extra: [String: String] = [:],
        _ customize: ((Span) -> Void)? = nil
    ) -> some View {
        self.modifier(ScreenTrackingModifier(
            screenName: name,
            extra: extra,
            customize: customize
        ))
    }
}

private struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    let extra: [String: String]
    let customize: ((Span) -> Void)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let tx = ScreenLoadContext.start(name: screenName, extra: extra)
                customize?(tx)
                // PostHog screen event with explicit name so analytics groups correctly
                var props: [String: Any] = [:]
                for (k, v) in extra { props[k] = v }
                VitaPostHogConfig.screen(name: screenName, properties: props.isEmpty ? nil : props)
                // Sentry breadcrumb so crash reports show which screen the user was on
                SentryConfig.addBreadcrumb(
                    message: "appeared \(screenName)",
                    category: "screen",
                    data: extra.isEmpty ? nil : extra.reduce(into: [String: Any]()) { $0[$1.key] = $1.value }
                )
            }
            .onDisappear {
                ScreenLoadContext.autoFinishIfAlive(name: screenName)
            }
    }
}
