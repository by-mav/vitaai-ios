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
    let subgroupSlugs: [String]?
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
    let facets: QBankPreviewFacets?
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
    let cardIds: [String]?
    let deckId: String?
    let title: String?

    init(
        lens: String?,
        groupSlugs: [String]?,
        mode: String,
        limit: Int?,
        showHints: Bool?,
        skipEasy: Bool?,
        cardIds: [String]? = nil,
        deckId: String? = nil,
        title: String? = nil
    ) {
        self.lens = lens
        self.groupSlugs = groupSlugs
        self.mode = mode
        self.limit = limit
        self.showHints = showHints
        self.skipEasy = skipEasy
        self.cardIds = cardIds
        self.deckId = deckId
        self.title = title
    }
}

struct FlashcardSessionResp: Codable {
    let sessionId: String
    let cardIds: [String]
    let totalCards: Int
    let expectedMinutes: Int
}

struct FlashcardStudySession: Codable {
    let id: String
    let title: String
    let mode: String
    let deckId: String?
    let cardIds: [String]
    let ratings: [Int]
    let currentIndex: Int
    let totalCards: Int
    let correctCount: Int
    let elapsedSeconds: Int
    let status: String
    let finishedAt: String?
    let createdAt: String
    let updatedAt: String
}

struct FlashcardStudySessionProgress: Codable {
    let cardIds: [String]
    let ratings: [Int]
    let currentIndex: Int
    let correctCount: Int
    let elapsedSeconds: Int
}

enum ActiveStudySessionKind: String, Codable, Hashable {
    case questoes
    case simulado
    case flashcards
}

enum ActiveStudySessionEngine: String, Codable, Hashable {
    case qbank
    case simulado
    case flashcards
}

struct ActiveStudySession: Codable, Identifiable, Hashable {
    let id: String
    let kind: ActiveStudySessionKind
    let engine: ActiveStudySessionEngine
    let mode: String?
    let title: String
    let current: Int
    let total: Int
    let deckId: String?
    let updatedAt: String
}

struct ActiveStudySessionsResponse: Codable {
    let sessions: [ActiveStudySession]
}

// MARK: - Flashcard From Question (issue #188 I2)

struct FlashcardFromQuestionResp: Codable {
    let existing: Bool
    let cardId: String
    let deckId: String
    /// Título do deck destino ("Questões erradas") — presente só no 201.
    let deckTitle: String?
}
