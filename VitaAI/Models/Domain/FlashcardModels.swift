import Foundation

// MARK: - Flashcard Domain Models

/// A flashcard deck containing multiple cards
struct FlashcardDeck: Identifiable, Hashable {
    let id: String
    let title: String
    var cards: [FlashcardCard]
    var dueCount: Int { cards.filter { $0.isDue }.count }
}

/// A single flashcard with front/back content and FSRS-5 scheduling state.
/// Backward-compatible with SM-2 legacy fields from the API layer:
///   stability  ← easeFactor (SM-2) or stability (FSRS-5)
///   difficulty ← FSRS-5 difficulty 1–10 (0 = unmigrated legacy card)
///   state      ← FsrsCardStatus raw value (0=New,1=Learning,2=Review,3=Relearning)
struct FlashcardCard: Identifiable, Hashable {
    let id: String
    let front: String
    let back: String

    // FSRS-5 spaced repetition state
    var stability: Double = 2.5      // FSRS S (or SM-2 EF for legacy cards)
    var difficulty: Double = 0.0     // FSRS D 1–10 (0 = legacy card, will be migrated)
    var state: Int = 0               // FsrsCardStatus raw value
    var scheduledDays: Int = 0
    var nextReviewAt: Date?

    var isDue: Bool {
        guard let next = nextReviewAt else { return true }
        return next <= Date()
    }
}

/// Rating choices for spaced repetition (maps to FSRS/Anki standard)
enum ReviewRating: Int, CaseIterable {
    case again = 1   // Failed, show again soon
    case hard  = 2   // Difficult but recalled
    case good  = 3   // Recalled with effort
    case easy  = 4   // Recalled instantly

    var label: String {
        switch self {
        case .again: return "Erro"
        case .hard:  return "Difícil"
        case .good:  return "Bom"
        case .easy:  return "Fácil"
        }
    }

    var isCorrect: Bool { self.rawValue >= 3 }
}

/// Result of a completed review session
struct FlashcardSessionResult {
    let totalCards: Int
    let correctCount: Int
    let timeSpentMs: Int64
    let streakCount: Int

    var accuracy: Int {
        guard totalCards > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalCards)) * 100)
    }

    var isPerfect: Bool { accuracy == 100 && totalCards > 0 }

    var timeSpentSeconds: Int { Int(timeSpentMs / 1000) }

    func formattedDuration() -> String {
        let secs = timeSpentSeconds
        let m = secs / 60
        let s = secs % 60
        if m == 0 { return "\(s)s" }
        return "\(m)m \(String(format: "%02d", s))s"
    }
}


// MARK: - API Request/Response (thin Codable wrappers for VitaAPI)

struct FlashcardReviewRequest: Codable {
    let rating: Int
    let responseTimeMs: Int64?
    let reviewId: String
}

// MARK: - Domain mapping from API layer

extension FlashcardEntry {
    /// Maps the Codable API model to the domain model used by session logic.
    func toDomain() -> FlashcardCard {
        FlashcardCard(
            id: id,
            front: front.isEmpty ? "Frente não disponível" : front,
            // Cloze: back vazio é NORMAL (a resposta é a frase revelada do front) —
            // não injeta placeholder, senão vira "Resposta não disponível" no verso.
            back:  back.isEmpty
                ? (front.range(of: #"\{\{c\d+::"#, options: .regularExpression) != nil ? "" : "Resposta não disponível")
                : back,
            stability:    easeFactor,
            difficulty:   0.0,
            state:        repetitions > 0 ? 2 : 0,
            scheduledDays: interval,
            nextReviewAt:  nextReviewAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}
