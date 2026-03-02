import Foundation
import Observation

// MARK: - Session State

enum FlashcardSessionPhase {
    case loading
    case studying
    case reviewing     // brief pause animating to next card
    case finished
    case empty         // no cards due
    case error(String)
}

// MARK: - FlashcardViewModel

@Observable
final class FlashcardViewModel {

    // MARK: Public state (read by views)

    private(set) var phase: FlashcardSessionPhase = .loading
    private(set) var deckTitle: String = ""
    private(set) var cards: [FlashcardCard] = []
    private(set) var currentIndex: Int = 0
    private(set) var isFlipped: Bool = false
    private(set) var totalReviewed: Int = 0
    private(set) var correctCount: Int = 0
    private(set) var result: FlashcardSessionResult? = nil

    // SM-2 per-card state (parallel arrays, indexed by cards)
    private(set) var easeFactors: [Double] = []
    private(set) var repetitions: [Int] = []
    private(set) var intervals: [Int] = []

    // Session timing
    private(set) var sessionStartDate: Date = Date()
    private(set) var cardStartDate: Date = Date()

    // MARK: Private
    private let api: VitaAPI

    // MARK: Computed helpers

    var currentCard: FlashcardCard? {
        cards.indices.contains(currentIndex) ? cards[currentIndex] : nil
    }

    var progress: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(totalReviewed + 1) / Double(cards.count)
    }

    var progressLabel: String { "\(min(totalReviewed + 1, cards.count))/\(cards.count)" }

    var elapsedSeconds: Int { Int(Date().timeIntervalSince(sessionStartDate)) }

    /// SM-2 interval previews for the current card's rating buttons
    var intervalPreviews: [ReviewRating: Int] {
        guard cards.indices.contains(currentIndex) else { return [:] }
        return SM2Scheduler.previewIntervals(
            easeFactor: easeFactors[currentIndex],
            repetitions: repetitions[currentIndex],
            currentInterval: intervals[currentIndex]
        )
    }

    // MARK: - Init

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func loadDeck(_ deckId: String) {
        phase = .loading
        isFlipped = false
        currentIndex = 0
        totalReviewed = 0
        correctCount = 0
        result = nil
        sessionStartDate = Date()
        cardStartDate = Date()

        Task { @MainActor in
            do {
                let deck = try await fetchDeck(deckId: deckId)
                startSession(deck: deck)
            } catch {
                // Always fallback to mock so the user is never stuck on a spinner
                let mock = FlashcardDeck.mockDeck(id: deckId)
                startSession(deck: mock)
            }
        }
    }

    // MARK: - User actions

    func flipCard() {
        guard case .studying = phase else { return }
        isFlipped.toggle()
    }

    func rateCard(_ rating: ReviewRating) {
        guard case .studying = phase, let card = currentCard else { return }
        guard cards.indices.contains(currentIndex) else { return }

        phase = .reviewing

        // Apply SM-2 locally (instant, offline-capable)
        let output = SM2Scheduler.compute(
            rating: rating,
            easeFactor: easeFactors[currentIndex],
            repetitions: repetitions[currentIndex],
            currentInterval: intervals[currentIndex]
        )
        easeFactors[currentIndex] = output.newEaseFactor
        intervals[currentIndex] = output.nextIntervalDays
        repetitions[currentIndex] = rating.isCorrect ? repetitions[currentIndex] + 1 : 0

        // Fire-and-forget API review — session always advances even on failure
        let cardId = card.id
        let responseTimeMs = Int64(Date().timeIntervalSince(cardStartDate) * 1000)
        Task.detached { [api = self.api] in
            _ = try? await api.reviewFlashcard(
                cardId: cardId,
                rating: rating.rawValue,
                responseTimeMs: responseTimeMs
            )
        }

        // Brief pause for reviewing state visual feedback, then advance
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            advanceCard(rating: rating)
        }
    }

    func clearError() {
        if case .error = phase { phase = .studying }
    }

    // MARK: - Private

    private func startSession(deck: FlashcardDeck) {
        guard !deck.cards.isEmpty else {
            deckTitle = deck.title
            result = FlashcardSessionResult(totalCards: 0, correctCount: 0, timeSpentMs: 0, streakCount: 0)
            phase = .empty
            return
        }

        deckTitle = deck.title
        cards = deck.cards
        currentIndex = 0
        isFlipped = false
        totalReviewed = 0
        correctCount = 0
        sessionStartDate = Date()
        cardStartDate = Date()

        // Initialize SM-2 state from card metadata
        easeFactors = cards.map { max(1.3, $0.stability == 0 ? 2.5 : $0.stability) }
        repetitions = cards.map { $0.state > 0 ? 1 : 0 }
        intervals   = cards.map { $0.scheduledDays }

        phase = .studying
    }

    private func advanceCard(rating: ReviewRating) {
        correctCount += rating.isCorrect ? 1 : 0
        totalReviewed += 1
        let nextIndex = currentIndex + 1

        if nextIndex >= cards.count {
            let elapsed = Int64(Date().timeIntervalSince(sessionStartDate) * 1000)
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: elapsed,
                streakCount: correctCount
            )
            phase = .finished
        } else {
            currentIndex = nextIndex
            isFlipped = false
            cardStartDate = Date()
            phase = .studying
        }
    }

    // MARK: - API fetch with domain mapping

    private func fetchDeck(deckId: String) async throws -> FlashcardDeck {
        async let allTask = api.getFlashcardDecks()
        async let dueTask = api.getFlashcardDecks(dueOnly: true)
        let (allDecks, dueDecks) = try await (allTask, dueTask)

        guard let deck = allDecks.first(where: { $0.id == deckId }) else {
            throw URLError(.resourceUnavailable)
        }

        // Prefer due cards; fall back to all cards in the deck
        let dueDeck = dueDecks.first(where: { $0.id == deckId })
        let sourceCards = (dueDeck.map { !$0.cards.isEmpty } == true) ? dueDeck!.cards : deck.cards

        return FlashcardDeck(
            id: deck.id,
            title: deck.title,
            cards: sourceCards.map { $0.toDomain() }
        )
    }
}
