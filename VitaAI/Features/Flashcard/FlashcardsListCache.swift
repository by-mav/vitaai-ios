import Foundation

/// Cache singleton de `getFlashcardDecks(deckLimit:1000, summary:true)`.
///
/// FlashcardsListScreen ficava 1-3s no spinner toda vez que o usuário
/// voltava pra aba. SWR (Stale-While-Revalidate): hidrata o state
/// imediatamente do cache se estiver fresco (<TTL); revalidate em
/// background. Cache TTL 60s.
@MainActor
@Observable
final class FlashcardsListCache {
    private let api: VitaAPI
    private let cacheTTL: TimeInterval = 60

    private(set) var decks: [FlashcardDeckEntry] = []
    private(set) var lastFetched: Date?

    init(api: VitaAPI) { self.api = api }

    var isFresh: Bool {
        guard let lastFetched else { return false }
        return Date().timeIntervalSince(lastFetched) < cacheTTL && !decks.isEmpty
    }

    func refresh() async throws -> [FlashcardDeckEntry] {
        let fetched = try await api.getFlashcardDecks(deckLimit: 1000, summary: true)
        decks = fetched
        lastFetched = Date()
        return fetched
    }
}
