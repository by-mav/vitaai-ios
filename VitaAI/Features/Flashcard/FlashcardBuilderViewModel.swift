import Foundation
import Observation

// MARK: - FlashcardBuilderViewModel
//
// Carrega os baralhos (Biblioteca + do aluno) pra home de flashcards. O builder
// rico antigo (modo/lente/filtro/preview/criação de sessão) foi removido — a home
// hoje é lista limpa de baralhos que abre a sessão ao tocar o baralho.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.3
//
// API: GET /api/study/flashcards?deckLimit&summary → [FlashcardDeckEntry]

// MARK: - Mode

enum FlashcardSessionMode: String, CaseIterable, Identifiable {
    case due       // SRS — revisão pendente (default)
    case specific  // disciplina pré-selecionada (entrada por DisciplineDetailScreen)
    case newCards  // nunca vistos

    var id: String { rawValue }
}

// MARK: - State

struct FlashcardBuilderState {
    var mode: FlashcardSessionMode = .due
    /// Disciplina(s) pré-selecionada(s) ao entrar por DisciplineDetailScreen.
    var selectedGroupSlugs: Set<String> = []

    var decks: [FlashcardDeckEntry] = []
    var decksLoading: Bool = true

    /// Biblioteca Vita pela arvore (area → disciplina). Os decks `library` sao
    /// acervos ("Medicina" = 6.391 cards de varias disciplinas); a lista mostra
    /// as DISCIPLINAS deles, nao a pilha.
    var library: FlashcardLibraryResponse? = nil
    /// A leitura da biblioteca FALHOU (≠ biblioteca vazia). Sem isso, erro de
    /// rede vira "nao tem nada aqui" — foi assim que um 500 escondeu 6.556 cards
    /// atras de "Voce ainda nao criou baralhos" (2026-07-17).
    var libraryFailed: Bool = false

    // Derivados dos decks (elimina a corrida stats-vs-decks). Rafael 2026-07-09.
    var dueNow: Int { decks.reduce(0) { $0 + ($1.dueCount ?? 0) } }
    var newNow: Int { decks.reduce(0) { $0 + max(0, ($1.totalCards ?? 0) - ($1.dueCount ?? 0)) } }
}

// MARK: - ViewModel

@Observable
@MainActor
final class FlashcardBuilderViewModel {
    var state = FlashcardBuilderState()

    private let api: VitaAPI
    nonisolated(unsafe) private var reconnectObserver: NSObjectProtocol?

    init(api: VitaAPI) {
        self.api = api
        // Auto-heal: SSE reconectou (servidor voltou) -> re-carrega decks frescos
        // sem o aluno reabrir o app. Rafael 2026-07-09.
        reconnectObserver = NotificationCenter.default.addObserver(
            forName: .realtimeReconnected, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.loadAll() }
        }
    }

    deinit {
        if let o = reconnectObserver { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Boot

    /// Re-busca decks quando a tela REAPARECE (volta da sessão) — senão a
    /// contagem "hoje" fica congelada no valor do boot. Rafael 2026-07-10.
    func refresh() async {
        await loadAll()
    }

    func boot() {
        Task { await loadAll() }
    }

    /// Pré-seleciona uma disciplina (vem de DisciplineDetailScreen → flashcardHome).
    /// Idempotente: chamar 2x não duplica. Onda 5 (2026-04-29).
    func setInitialSubject(slug: String?) {
        guard let slug, !slug.isEmpty else { return }
        guard !state.selectedGroupSlugs.contains(slug) else { return }
        state.mode = .specific
        state.selectedGroupSlugs.insert(slug)
    }

    private func loadAll() async {
        // Em paralelo: a arvore da Biblioteca e os baralhos do aluno sao
        // independentes — sequencial so somaria latencia.
        async let lib: Void = loadLibrary()
        async let decks: Void = loadDecks()
        _ = await (lib, decks)
        // Default inteligente: sem pendentes mas com novos -> abre em "Novos"
        // (senão o aluno cai em "Pendentes" vazio com milhares de cards novos).
        if state.mode == .due, state.dueNow == 0, state.newNow > 0 {
            state.mode = .newCards
        }
    }

    private func loadLibrary() async {
        do {
            state.library = try await api.getFlashcardLibrary()
            state.libraryFailed = false
        } catch {
            state.libraryFailed = true
            NSLog("[FlashcardBuilder] loadLibrary error: %@", String(describing: error))
        }
    }

    private func loadDecks() async {
        state.decksLoading = true
        defer { state.decksLoading = false }
        do {
            // summary=true: hidratação on-demand ao tocar o deck. deckLimit alto:
            // o aluno pode ter centenas de baralhos. Rafael 2026-07-09.
            let decks = try await api.getFlashcardDecks(deckLimit: 2000, summary: true)
            // Baralho vazio do aluno fica visível (acabou de criar no "+"); só a
            // Biblioteca esconde vazios.
            state.decks = decks.filter { $0.cardCount > 0 || !($0.userId ?? "").isEmpty }
        } catch {
            NSLog("[FlashcardBuilder] loadDecks error: %@", String(describing: error))
        }
    }

    // MARK: - Decks filtering (grid / seleção múltipla pro estudo em conjunto)

    /// Decks visíveis considerando mode + disciplina pré-selecionada.
    func visibleDecks() -> [FlashcardDeckEntry] {
        switch state.mode {
        case .due:
            return state.decks.filter { ($0.dueCount ?? 0) > 0 }
        case .specific:
            if state.selectedGroupSlugs.isEmpty { return state.decks }
            return state.decks.filter { d in
                guard let slug = d.disciplineSlug else { return false }
                return state.selectedGroupSlugs.contains(slug)
            }
        case .newCards:
            return state.decks.filter { ($0.dueCount ?? 0) == 0 }
        }
    }
}
