import Foundation

// MARK: - VitaEvent
//
// Canonical product analytics event names. The SDK-backed implementation was
// removed, but this enum stays useful as a local taxonomy for future sinks.

enum VitaEvent: String {
    // Cross-cutting tool error (instrumented via tracked() helper).
    // See Tracked.swift + incidents/vitaai/2026-04-30_silent-tool-catches.md.
    case toolError = "tool_error"
    case handwritingConverted = "handwriting_converted"
    case shapeSnapped = "shape_snapped"

    // Auth lifecycle
    case userSignedUp = "user_signed_up"
    case userLoggedIn = "user_logged_in"
    case userLoggedOut = "user_logged_out"

    // Onboarding funnel
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingChoiceSelected = "onboarding_choice_selected"
    case onboardingCompleted = "onboarding_completed"

    // Monetization
    case paywallShown = "paywall_shown"
    case subscriptionStarted = "subscription_started"
    case subscriptionCanceled = "subscription_canceled"

    // Study features
    case studySessionCompleted = "study_session_completed"
    case simuladoStarted = "simulado_started"
    case simuladoCompleted = "simulado_completed"
    case flashcardReviewCompleted = "flashcard_review_completed"
    case qbankQuestionAnswered = "qbank_question_answered"

    // Portal connectors
    case portalConnectStarted = "portal_connect_started"
    case portalConnectSucceeded = "portal_connect_succeeded"
    case portalConnectFailed = "portal_connect_failed"

    // AI / content
    case aiChatMessageSent = "ai_chat_message_sent"
    case documentUploaded = "document_uploaded"
}

// MARK: - AnalyticsTracker
//
// Shared product analytics tracker. Currently logs locally through
// `VitaAnalytics`; no third-party SDK is linked.

final class AnalyticsTracker {
    static let shared = AnalyticsTracker()

    private init() {}

    /// Emits a typed product event. Use `VitaEvent` enum to keep the
    /// event taxonomy clean.
    func event(_ name: VitaEvent, properties: [String: Any] = [:]) {
        VitaAnalytics.capture(event: name.rawValue, properties: properties)
    }
}
