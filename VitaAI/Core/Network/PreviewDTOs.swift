import Foundation

// MARK: - Preview/Session DTOs (Simulado + Flashcard) — Added 2026-04-29
//
// Endpoints novos no backend (commits 06c88ba, 7dd33ba, b7103db):
//  - POST /api/simulados/preview          → SimuladoPreviewResp
//  - GET  /api/study/flashcards/preview   → FlashcardsPreviewResp
//  - POST /api/study/flashcards/session   → FlashcardSessionResp
//
// Models locais até `./scripts/sync-api-spec.sh` regenerar Generated/.
// Spec: openapi.yaml §components.schemas (SimuladoPreviewRequest/Response,
// FlashcardsPreviewResponse, FlashcardSessionRequest/Response).

// MARK: - Simulado Preview

struct SimuladoPreviewYears: Codable, Hashable {
    let min: Int?
    let max: Int?
}

struct SimuladoPreviewBody: Codable {
    let lens: String?
    let groupSlugs: [String]?
    let institutionIds: [Int]?
    let years: SimuladoPreviewYears?
    let difficulties: [String]?
    let format: [String]?
    let hideAnswered: Bool?
    let hideAnnulled: Bool?
    let excludeNoExplanation: Bool?
    let includeSynthetic: Bool?
    let questionCount: Int?
    let timed: Bool?
    let timeLimitMinutes: Int?
}

struct SimuladoPreviewTopGroup: Codable, Hashable {
    let slug: String?
    let name: String?
    let count: Int?
}

struct SimuladoPreviewResp: Codable {
    let total: Int
    let estimatedMinutes: Int
    let byDifficulty: [String: Int]?
    let byYear: [String: Int]?
    let topGroups: [SimuladoPreviewTopGroup]?
    let appliedJourneyBoost: String?
}

// MARK: - Flashcards Preview

struct FlashcardsPreviewTopDeck: Codable, Hashable {
    let disciplineSlug: String?
    let due: Int?
}

struct FlashcardsPreviewResp: Codable {
    let due: Int
    let learning: Int
    let new: Int
    let projectedSessionTime: Int
    let topDecks: [FlashcardsPreviewTopDeck]?
}

// MARK: - Flashcard Session

struct FlashcardSessionBody: Codable {
    let lens: String?
    let groupSlugs: [String]?
    let mode: String          // "due" | "specific" | "new"
    let limit: Int?
    let showHints: Bool?
    let skipEasy: Bool?
}

struct FlashcardSessionResp: Codable {
    let sessionId: String
    let cardIds: [String]
    let totalCards: Int
    let expectedMinutes: Int
}
