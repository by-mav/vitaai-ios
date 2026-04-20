import SwiftUI
import OSLog
import Sentry
import SentrySwiftUI

// MARK: - ScreenTracking — gold-standard per-screen instrumentation
//
// Wraps the SDK-official `SentryTracedView(_, waitForFullDisplay: true)` with
// the BYMAV conventions (PostHog screen event + breadcrumb + logger).
// Each screen call:
//
//     SomeScreen { ... }
//         .trackScreen("SomeScreen")
//
// produces automatically:
//   * Sentry `ui.load.<Name>` transaction with a `ttid` span (first frame)
//     and a `ttfd` span (closed by `SentrySDK.reportFullyDisplayed()`).
//     If `reportFullyDisplayed()` is NOT called within 30s, the TTFD span
//     finishes with DEADLINE_EXCEEDED automatically — no manual timeout.
//   * PostHog `$screen` event with explicit name (not SwiftUI's generic
//     "ContentView") + the `extra` dictionary as properties.
//   * Sentry breadcrumb so crash reports show the user's last screen.
//
// RULE: inside the screen's `.task {}` call `SentrySDK.reportFullyDisplayed()`
// as soon as data is hydrated, so TTFD measures load time, not time-on-screen.

extension View {
    /// Track this screen with Sentry TTID/TTFD + PostHog screen view.
    /// Inside `.task {}`, call `SentrySDK.reportFullyDisplayed()` when data is ready.
    func trackScreen(_ name: String, extra: [String: String] = [:]) -> some View {
        self.modifier(ScreenTrackingModifier(screenName: name, extra: extra))
    }
}

private struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    let extra: [String: String]

    func body(content: Content) -> some View {
        // SentryTracedView measures TTID (on appear) + TTFD (on
        // reportFullyDisplayed()) automatically. Only the root transaction
        // tracks these — nested SentryTracedViews are ignored for TTID/TTFD.
        SentryTracedView(screenName, waitForFullDisplay: true) {
            content
                .onAppear {
                    // PostHog screen event with explicit name so dashboards
                    // group correctly (SwiftUI auto-name is generic).
                    var props: [String: Any] = [:]
                    for (k, v) in extra { props[k] = v }
                    VitaPostHogConfig.screen(
                        name: screenName,
                        properties: props.isEmpty ? nil : props
                    )

                    // Sentry breadcrumb — crash reports show last screen.
                    SentryConfig.addBreadcrumb(
                        message: "appeared \(screenName)",
                        category: "screen",
                        data: extra.isEmpty ? nil : extra.reduce(into: [String: Any]()) { $0[$1.key] = $1.value }
                    )
                }
        }
    }
}

// MARK: - Backward compat shim
//
// Old callers used `ScreenLoadContext.finish(for: "Name")` — now aliased to the
// SDK-official `SentrySDK.reportFullyDisplayed()`. Kept so we don't have to
// touch every screen file in a single PR. New screens should call the SDK API
// directly.

@MainActor
enum ScreenLoadContext {
    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "screen")

    /// Deprecated: call `SentrySDK.reportFullyDisplayed()` directly.
    /// This wrapper exists only for screens not yet migrated. Log + forward.
    static func finish(for name: String) {
        logger.notice("[screen.finish] \(name, privacy: .public) (via reportFullyDisplayed)")
        SentrySDK.reportFullyDisplayed()
    }

    /// Deprecated no-op. Kept so old onDisappear calls don't break compile.
    static func autoFinishIfAlive(name: String) {
        // SentryTracedView handles lifecycle; no manual cleanup needed.
    }
}
