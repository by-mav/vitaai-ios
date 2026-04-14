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
@MainActor
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

    // FSRS-5 per-card state (parallel array, indexed by cards)
    private(set) var fsrsStates: [FsrsCardState] = []

    // Session timing
    private(set) var sessionStartDate: Date = Date()
    private(set) var cardStartDate: Date = Date()

    // Undo support
    private(set) var canUndo: Bool = false
    private var undoSnapshot: UndoSnapshot?

    // MARK: Private

    private let api: VitaAPI
    private let gamificationEvents: GamificationEventManager
    private var scheduler = FsrsScheduler()
    private var leechThreshold: Int = 8

    private struct UndoSnapshot {
        let cardIndex: Int
        let fsrsState: FsrsCardState
        let wasFlipped: Bool
        let totalReviewed: Int
        let correctCount: Int
    }

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

    /// FSRS-5 interval previews for the current card's rating buttons
    var intervalPreviews: [ReviewRating: Int] {
        guard fsrsStates.indices.contains(currentIndex) else { return [:] }
        let preview = scheduler.preview(card: fsrsStates[currentIndex])
        return [
            .again: preview.again,
            .hard:  preview.hard,
            .good:  preview.good,
            .easy:  preview.easy,
        ]
    }

    // MARK: - Init

    init(api: VitaAPI, gamificationEvents: GamificationEventManager) {
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Load

    func loadDeck(_ deckId: String, tagFilter: String? = nil) {
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
                let deck = try await fetchDeck(deckId: deckId, tagFilter: tagFilter)
                startSession(deck: deck)
            } catch {
                phase = .error("Erro ao carregar flashcards: \(error.localizedDescription)")
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
        guard fsrsStates.indices.contains(currentIndex) else { return }

        // Save undo snapshot before modifying state
        undoSnapshot = UndoSnapshot(
            cardIndex: currentIndex,
            fsrsState: fsrsStates[currentIndex],
            wasFlipped: isFlipped,
            totalReviewed: totalReviewed,
            correctCount: correctCount
        )
        canUndo = true

        phase = .reviewing

        // Apply FSRS-5 locally (instant, offline-capable)
        let result = scheduler.schedule(
            card: fsrsStates[currentIndex],
            rating: rating,
            now: Date()
        )
        fsrsStates[currentIndex] = result.card

        // Leech detection: auto-suspend cards that exceed the lapse threshold
        if result.card.lapses >= leechThreshold && leechThreshold < 999 {
            let leechCardId = card.id
            Task.detached { [api = self.api] in
                for attempt in 0..<2 {
                    do {
                        _ = try await api.suspendFlashcard(cardId: leechCardId)
                        break
                    } catch {
                        if attempt == 0 { try? await Task.sleep(for: .milliseconds(500)) }
                    }
                }
            }
        }

        // API review with retry — session advances regardless, but we retry failures
        let cardId = card.id
        let responseTimeMs = Int64(Date().timeIntervalSince(cardStartDate) * 1000)
        let action = rating.isCorrect ? "flashcard_easy" : "flashcard_review"
        Task.detached { [api = self.api] in
            for attempt in 0..<3 {
                do {
                    _ = try await api.reviewFlashcard(
                        cardId: cardId,
                        rating: rating.rawValue,
                        responseTimeMs: responseTimeMs
                    )
                    break
                } catch {
                    if attempt < 2 {
                        try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
                    } else {
                        print("[Flashcard] Review sync failed after 3 attempts for card \(cardId)")
                    }
                }
            }
        }

        // Track activity for gamification (XP, streak, study time)
        Task { [api, gamificationEvents] in
            if let result = try? await api.logActivity(action: action) {
                gamificationEvents.handleActivityResponse(result, previousLevel: nil)
            }
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

    /// Remove the current card from the session (suspend)
    func suspendCurrentCard() {
        guard case .studying = phase, let card = currentCard else { return }

        // Fire-and-forget API call to suspend on server
        let cardId = card.id
        Task.detached { [api = self.api] in
            _ = try? await api.suspendFlashcard(cardId: cardId)
        }

        // Remove from local session
        cards.remove(at: currentIndex)
        fsrsStates.remove(at: currentIndex)

        if cards.isEmpty {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(Date().timeIntervalSince(sessionStartDate) * 1000),
                streakCount: correctCount
            )
            phase = .finished
        } else if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }
        isFlipped = false
        cardStartDate = Date()
    }

    /// Undo the last rating — go back to previous card
    func undoLastRating() {
        guard let snapshot = undoSnapshot else { return }
        guard case .studying = phase else { return }

        // Restore state
        currentIndex = snapshot.cardIndex
        fsrsStates[snapshot.cardIndex] = snapshot.fsrsState
        totalReviewed = snapshot.totalReviewed
        correctCount = snapshot.correctCount
        isFlipped = false
        cardStartDate = Date()

        undoSnapshot = nil
        canUndo = false
    }

    /// Bury current card — hide until tomorrow (remove from session, don't delete)
    func buryCurrentCard() {
        guard case .studying = phase, let card = currentCard else { return }

        // Fire-and-forget API call to bury on server
        let cardId = card.id
        Task.detached { [api = self.api] in
            _ = try? await api.buryFlashcard(cardId: cardId)
        }

        // Remove from local session
        cards.remove(at: currentIndex)
        fsrsStates.remove(at: currentIndex)

        if cards.isEmpty {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(Date().timeIntervalSince(sessionStartDate) * 1000),
                streakCount: correctCount
            )
            phase = .finished
        } else if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }
        isFlipped = false
        cardStartDate = Date()
    }

    /// Apply settings from the settings sheet
    func applySettings(_ settings: FlashcardSettings) {
        // Update FSRS scheduler with desired retention
        scheduler = FsrsScheduler(params: FsrsParameters(requestedRetention: settings.desiredRetention))
        leechThreshold = settings.leechThreshold

        // Sort order
        switch settings.sortOrder {
        case .random:
            let combined = Array(zip(cards, fsrsStates))
            let shuffled = combined.shuffled()
            cards = shuffled.map { $0.0 }
            fsrsStates = shuffled.map { $0.1 }
        case .dueDate:
            // Sort by FSRS scheduled days (ascending = most overdue first)
            let combined = Array(zip(cards, fsrsStates)).sorted { $0.1.scheduledDays < $1.1.scheduledDays }
            cards = combined.map { $0.0 }
            fsrsStates = combined.map { $0.1 }
        case .added:
            break // Keep original order
        }
        currentIndex = 0
        isFlipped = false

        // Filter by session mode
        switch settings.sessionMode {
        case .newOnly:
            let filtered = (0..<cards.count).filter { fsrsStates[$0].status == .new }
            cards = filtered.map { cards[$0] }
            fsrsStates = filtered.map { fsrsStates[$0] }
        case .reviewOnly:
            let filtered = (0..<cards.count).filter { fsrsStates[$0].status != .new }
            cards = filtered.map { cards[$0] }
            fsrsStates = filtered.map { fsrsStates[$0] }
        case .all:
            break
        }

        // Apply daily limits
        let newLimit = settings.dailyNewLimit
        let reviewLimit = settings.dailyReviewLimit
        var newCount = 0
        var reviewCount = 0
        var keep: [Int] = []
        for i in 0..<cards.count {
            if fsrsStates[i].status == .new {
                if newCount < newLimit { keep.append(i); newCount += 1 }
            } else {
                if reviewCount < reviewLimit { keep.append(i); reviewCount += 1 }
            }
        }
        cards = keep.map { cards[$0] }
        fsrsStates = keep.map { fsrsStates[$0] }

        currentIndex = min(currentIndex, max(0, cards.count - 1))

        if cards.isEmpty {
            phase = .empty
        }
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

        // Initialise FSRS-5 state from card metadata.
        // Cards that previously used SM-2 fields (easeFactor/interval) are migrated
        // via FsrsCardState.migratedFromSM2() — data is never lost.
        fsrsStates = cards.map { card in
            if card.difficulty > 0 && card.stability > 0 {
                // Already has FSRS-5 native state
                return FsrsCardState(
                    stability:     card.stability,
                    difficulty:    card.difficulty,
                    elapsedDays:   0,
                    scheduledDays: card.scheduledDays,
                    reps:          card.state > 0 ? 1 : 0,
                    lapses:        0,
                    status:        FsrsCardStatus(rawValue: card.state) ?? .new,
                    lastReviewDate: card.nextReviewAt.map { Calendar.current.date(byAdding: .day, value: -card.scheduledDays, to: $0) } ?? nil
                )
            } else {
                // Legacy SM-2 card — migrate gracefully
                return FsrsCardState.migratedFromSM2(
                    easeFactor:     max(1.3, card.stability == 0 ? 2.5 : card.stability),
                    repetitions:    card.state > 0 ? 1 : 0,
                    interval:       card.scheduledDays,
                    lastReviewDate: card.nextReviewAt.map {
                        Calendar.current.date(byAdding: .day, value: -card.scheduledDays, to: $0)
                    } ?? nil
                )
            }
        }

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

            // Log deck completion with study duration
            let durationMinutes = Int(elapsed / 60_000)
            Task { [api, gamificationEvents] in
                if let result = try? await api.logActivity(
                    action: "deck_completed",
                    metadata: ["durationMinutes": String(durationMinutes)]
                ) {
                    gamificationEvents.handleActivityResponse(result, previousLevel: nil)
                }
            }
        } else {
            currentIndex = nextIndex
            isFlipped = false
            cardStartDate = Date()
            phase = .studying
        }
    }

    // MARK: - API fetch with domain mapping

    private func fetchDeck(deckId: String, tagFilter: String? = nil) async throws -> FlashcardDeck {
        // When filtering by tag, request all matching cards (no server-side limit)
        let limit = tagFilter != nil ? 9999 : nil
        async let allTask = api.getFlashcardDecks(tag: tagFilter, cardsLimit: limit)
        async let dueTask = api.getFlashcardDecks(dueOnly: true, tag: tagFilter, cardsLimit: limit)
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
