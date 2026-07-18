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
    private var pendingQuickSessionId: String? = nil

    /// Grava a fila que o servidor montou (POST /api/study/flashcards/session).
    /// Quem abre uma DISCIPLINA da Biblioteca usa isto: os cards dela vêm de
    /// vários baralhos, então não há um `deckId` pra abrir — o que existe é a
    /// fila. Sem este setter o `consumeQuickSession` abaixo nunca tinha o que
    /// consumir (o produtor não existia).
    func setQuickSession(cardIds: [String], title: String?, sessionId: String?) {
        pendingQuickCardIds = cardIds
        pendingQuickTitle = title
        pendingQuickSessionId = sessionId
    }

    /// Fila da sessão rápida e LIMPA. cardIds vazio = fluxo normal por deck.
    func consumeQuickSession() -> (cardIds: [String], title: String?, sessionId: String?) {
        let out = (pendingQuickCardIds, pendingQuickTitle, pendingQuickSessionId)
        pendingQuickCardIds = []
        pendingQuickTitle = nil
        pendingQuickSessionId = nil
        return out
    }

    // MARK: - Sessão OFFLINE do bundle (conteúdo curado, sem rede)
    //
    // Abrir uma disciplina da Biblioteca lê os cards DIRETO do bundle
    // (VitaContentBundle) — os cards já vêm completos (front/back), então não há
    // 2ª ida ao servidor pra resolver. É o offline de verdade: o card sempre
    // abre, sem internet (Rafael 2026-07-17). Diferente do quick session acima,
    // que traz só ids e depende do servidor.

    private var pendingBundleCards: [FlashcardCard] = []
    private var pendingBundleTitle: String? = nil

    func setBundleCards(_ cards: [FlashcardCard], title: String?) {
        pendingBundleCards = cards
        pendingBundleTitle = title
    }

    func consumeBundleCards() -> (cards: [FlashcardCard], title: String?) {
        let out = (pendingBundleCards, pendingBundleTitle)
        pendingBundleCards = []
        pendingBundleTitle = nil
        return out
    }
}
