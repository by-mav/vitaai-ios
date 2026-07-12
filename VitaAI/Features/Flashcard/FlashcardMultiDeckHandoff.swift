import Foundation

/// Handoff explícito builder → sessão pra estudar VÁRIOS baralhos juntos, SEM
/// tocar no AppRouter (arquivo com WIP de outro agente). O builder grava os ids
/// selecionados aqui e navega com o primeiro; `FlashcardViewModel.loadDeck`
/// consome e faz merge dos cards de todos os decks.
///
/// TODO: virar Route com `[deckId]` quando o AppRouter estiver livre. Rafael 2026-07-10.
@MainActor
final class FlashcardMultiDeckHandoff {
    static let shared = FlashcardMultiDeckHandoff()
    private init() {}

    private var pending: [String] = []

    func set(_ ids: [String]) { pending = ids }

    /// Retorna os ids pendentes e LIMPA (idempotente). Vazio = sessão normal de 1 deck.
    func consume() -> [String] {
        let ids = pending
        pending = []
        return ids
    }

    // MARK: - Sessão rápida (issue #188 I1)
    //
    // Chips "Só os que errei"/"Véspera de prova": o backend calcula a fila
    // (POST /api/study/flashcards/session) e devolve cardIds na ordem FSRS.
    // O builder grava aqui e o FlashcardViewModel monta a sessão EXATA.

    private var pendingQuickCardIds: [String] = []
    private var pendingQuickTitle: String? = nil

    func setQuickSession(cardIds: [String], title: String) {
        pendingQuickCardIds = cardIds
        pendingQuickTitle = title
    }

    /// Fila da sessão rápida e LIMPA. cardIds vazio = fluxo normal por deck.
    func consumeQuickSession() -> (cardIds: [String], title: String?) {
        let out = (pendingQuickCardIds, pendingQuickTitle)
        pendingQuickCardIds = []
        pendingQuickTitle = nil
        return out
    }
}
