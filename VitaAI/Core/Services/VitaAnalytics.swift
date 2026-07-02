import Foundation
import OSLog
import SwiftUI

// MARK: - VitaAnalytics
//
// Local analytics facade. VitaAI does not link a third-party product analytics
// SDK right now; this keeps semantic event call sites compile-safe for a
// future first-party sink.

enum VitaAnalytics {

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "analytics")

    // MARK: - Initialize

    static func initialize() {
        logger.info("Analytics facade initialized without third-party SDK")
    }

    // MARK: - User Identification

    static func identify(userId: String, properties: [String: Any]? = nil) {
        logger.debug("analytics.identify user=\(userId, privacy: .private)")
    }

    static func reset() {
        logger.debug("analytics.reset")
    }

    // MARK: - Events

    static func capture(event: String, properties: [String: Any]? = nil) {
        logger.debug("analytics.event \(event, privacy: .public)")
    }

    static func screen(name: String, properties: [String: Any]? = nil) {
        logger.debug("analytics.screen \(name, privacy: .public)")
    }

    // MARK: - Feature Flags

    /// Canonical feature flags for VitaAI. No remote flag backend is linked in
    /// the current app, so these helpers intentionally default to off/nil.
    enum Flag: String {
        /// Kill switch for PDF scanner (iOS Vision API). Flip to false if
        /// Vision latency spikes or Apple changes the API.
        case pdfScannerEnabled = "pdf_scanner_enabled"

        /// AI coach model selector. Multivariate:
        ///   - `haiku-max` → Claude Haiku via OAuth Max (default)
        ///   - `sonnet-max` → Claude Sonnet via OAuth Max (premium test)
        ///   - `local-vllm` → Qwen3.5-35B-A3B self-hosted
        /// NUNCA adicionar Anthropic API key — só OAuth Max.
        case aiCoachModel = "ai_coach_model"

        /// Portal extractor version selector for safe rollout:
        ///   - `v1-legacy` → hardcoded parsers (deprecated)
        ///   - `v2-fingerprint` → fingerprint-based parseWithMap
        ///   - `v3-teacher` → Haiku teacher generates fingerprints
        case portalExtractorVersion = "portal_extractor_version"

        /// Pricing plan variant for A/B (BRL):
        ///   - `49-99-149` (control)
        ///   - `39-79-119` (aggressive)
        case pricingPlanVariant = "pricing_plan_variant"

        /// Onboarding v2 — dogfood before 100% rollout. 10% initially.
        case newOnboardingV2 = "new_onboarding_v2"
    }

    /// Checks if a typed feature flag is enabled.
    static func isEnabled(_ flag: Flag) -> Bool {
        false
    }

    /// Gets a multivariate flag's string payload (for `aiCoachModel`, etc.).
    static func variant(_ flag: Flag) -> String? {
        nil
    }

    /// Raw flag check (legacy — prefer `isEnabled(_:)` with Flag enum).
    static func isFeatureEnabled(_ flag: String) -> Bool {
        false
    }

    static func reloadFeatureFlags() {
        logger.debug("analytics.reloadFeatureFlags ignored")
    }
}

extension View {
    func privacyAnalyticsMask() -> some View {
        self
    }
}
