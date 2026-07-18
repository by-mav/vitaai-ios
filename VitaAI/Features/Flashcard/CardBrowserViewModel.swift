import Foundation

// MARK: - CardBrowserViewModel
//
// Estado do navegador de cards de UM baralho (CardBrowserScreen), estilo Anki:
// lista, busca, filtros, multi-seleção, criar/editar/excluir/suspender e
// reordenar. Feature store própria (padrão do app pra features isoladas —
// recibos/mesada), NÃO duplicata de AppDataManager.
//
// Fonte dos cards: getFlashcardDecks(...) → o deck com id == deckId → .cards
// (mesmo caminho que FlashcardViewModel.fetchDeck usa). Não há endpoint que
// devolva "os cards de 1 deck" isolado; filtramos por subjectId (quando o deck
// tem) pra o payload não vir com todos os baralhos.

@MainActor
@Observable
final class CardBrowserViewModel {

    // MARK: Filtros (chips)
    enum Filter: String, CaseIterable, Identifiable {
        case all, due, new, recent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:    return "Todos"
            case .due:    return "Pendentes"
            case .new:    return "Novos"
            case .recent: return "Recentes"
            }
        }
    }

    // MARK: Estado observável
    private(set) var cards: [FlashcardEntry] = []
    private(set) var isLoading = true
    private(set) var loadFailed = false
    private(set) var isMutating = false
    /// Baralho curado da Biblioteca Vita (userId nil) = read-only: os endpoints
    /// de mutação respondem 403 ("own cards only"). Nesse caso a tela vira
    /// só-navegação (sem +/editar/excluir/selecionar/reordenar).
    private(set) var isReadOnly = false
    var errorMessage: String?

    var searchText = ""
    var filter: Filter = .all
    var isSelecting = false
    var selection: Set<String> = []

    // MARK: Dependências / contexto
    private var api: VitaAPI?
    private(set) var deckId = ""
    private(set) var deckTitle = ""
    private var subjectId: String?
    private var disciplineSlug: String?
    private var didLoad = false

    // MARK: Setup

    func bind(api: VitaAPI) { self.api = api }

    func configure(deckId: String, deckTitle: String, subjectId: String?, disciplineSlug: String? = nil) {
        self.deckId = deckId
        self.deckTitle = deckTitle
        self.subjectId = subjectId
        self.disciplineSlug = disciplineSlug
    }

    // MARK: Derivados

    /// Só é seguro arrastar pra reordenar quando a lista visível == lista real
    /// (sem busca e sem filtro), senão os índices de origem/destino não batem
    /// com o array `cards`.
    var canReorder: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty && filter == .all && !isSelecting
    }

    var filteredCards: [FlashcardEntry] {
        var result = cards

        switch filter {
        case .all:
            break
        case .due:
            result = result.filter { $0.browserStatus == .due || $0.browserStatus == .today }
        case .new:
            result = result.filter { $0.browserStatus == .new }
        case .recent:
            result = result.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        }

        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let needle = q.folded
            result = result.filter {
                $0.front.folded.contains(needle) || $0.back.folded.contains(needle)
            }
        }
        return result
    }

    var selectedCount: Int { selection.count }
    var allVisibleSelected: Bool {
        let ids = Set(filteredCards.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selection)
    }

    // MARK: Carregar

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await load()
    }

    func load() async {
        // Biblioteca offline: os cards da disciplina vivem no bundle, não no servidor.
        // Lê do VitaContentBundle (read-only — deck curado, ninguém edita direto).
        if let slug = disciplineSlug, !slug.isEmpty {
            let bundle = await VitaContentBundle.shared.cards(disciplineSlug: slug)
            cards = bundle.map { FlashcardEntry(id: $0.id, front: $0.front, back: $0.back) }
            isReadOnly = true
            didLoad = true
            isLoading = false
            return
        }

        guard let api else { return }
        isLoading = cards.isEmpty
        loadFailed = false
        do {
            let decks = try await api.getFlashcardDecks(
                subjectId: subjectId,
                cardsLimit: 9999,
                deckLimit: 1000
            )
            let deck = decks.first(where: { $0.id == deckId })
            cards = deck?.cards ?? []
            isReadOnly = (deck?.userId ?? "").isEmpty
            didLoad = true
        } catch {
            loadFailed = cards.isEmpty
            print("[CardBrowser] load error: \(error)")
        }
        isLoading = false
    }

    func refresh() async { await load() }

    // MARK: Seleção

    func enterSelection(preselect id: String? = nil) {
        isSelecting = true
        if let id { selection = [id] }
    }

    func cancelSelection() {
        isSelecting = false
        selection.removeAll()
    }

    func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func selectAllVisible() {
        selection.formUnion(filteredCards.map(\.id))
    }

    func clearSelection() { selection.removeAll() }

    // MARK: Mutações

    /// Cria 1 card NESTE baralho (reusa createFlashcard por título — o server
    /// resolve o deck existente pelo nome). Recarrega pra pegar o id do server.
    func createCard(front: String, back: String) async -> Bool {
        guard let api else { return false }
        let f = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty, !b.isEmpty else { return false }
        isMutating = true; defer { isMutating = false }
        do {
            _ = try await api.createFlashcard(front: f, back: b, deckTitle: deckTitle, subjectId: subjectId)
            await load()
            return true
        } catch {
            errorMessage = "Não foi possível criar o card."
            return false
        }
    }

    /// Edita frente/verso (otimista: aplica local, reverte no erro).
    func updateCard(id: String, front: String, back: String) async -> Bool {
        guard let api else { return false }
        let f = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty, !b.isEmpty else { return false }
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return false }

        let snapshot = cards[idx]
        cards[idx].front = f
        cards[idx].back = b
        isMutating = true; defer { isMutating = false }
        do {
            try await api.updateFlashcard(cardId: id, front: f, back: b)
            return true
        } catch {
            cards[idx] = snapshot  // reverte
            errorMessage = "Não foi possível salvar a edição."
            return false
        }
    }

    /// Exclui 1 card. NÃO-otimista: só some depois do server confirmar, pra
    /// nunca "ressuscitar" num re-fetch.
    func delete(id: String) async {
        guard let api else { return }
        isMutating = true; defer { isMutating = false }
        do {
            try await api.deleteFlashcard(cardId: id)
            cards.removeAll { $0.id == id }
            selection.remove(id)
        } catch {
            errorMessage = "Não foi possível excluir o card."
        }
    }

    func deleteSelected() async {
        let ids = Array(selection)
        for id in ids { await delete(id: id) }
        if selection.isEmpty { isSelecting = false }
    }

    /// Suspende os selecionados (endpoint existente suspendFlashcard). Suspenso
    /// = fora da fila de estudo até reativar; continua listado.
    func suspendSelected() async {
        guard let api else { return }
        isMutating = true; defer { isMutating = false }
        for id in Array(selection) {
            do { try await api.suspendFlashcard(cardId: id) }
            catch { errorMessage = "Não foi possível suspender algum card." }
        }
        await load()
        cancelSelection()
    }

    /// Reordena LOCALMENTE (drag na lista). ⚠️ GAP DOCUMENTADO: não há endpoint
    /// de ordem manual de flashcards — a ordem de estudo é derivada do FSRS
    /// (nextReviewAt/stability), não de um campo `position`/`sortOrder`. Logo
    /// esta reordenação é só visual nesta sessão e NÃO persiste no backend.
    /// Quando existir POST/PATCH de ordem (ex.: .../reorder com [cardId]),
    /// plugar aqui a chamada após o move local.
    func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Preview
    #if DEBUG
    func seedForPreview(cards: [FlashcardEntry], deckTitle: String) {
        self.deckTitle = deckTitle
        self.cards = cards
        self.isLoading = false
        self.didLoad = true
    }
    #endif
}

// MARK: - Status de card (derivado, estilo Anki)

enum CardBrowserStatus {
    case new      // nunca estudado
    case today    // vence hoje
    case due      // vencido (atrasado)
    case scheduled // agendado pro futuro
}

extension FlashcardEntry {
    var browserStatus: CardBrowserStatus {
        if (state?.uppercased() == "NEW") || reps == 0 { return .new }
        guard let next = nextReviewAt.flatMap(ISO8601DateParser.date(from:)) else { return .new }
        let now = Date()
        if next <= now { return .due }
        if Calendar.current.isDateInToday(next) { return .today }
        return .scheduled
    }
}

// Parser tolerante (com e sem frações de segundo) — as datas do backend vêm ISO.
enum ISO8601DateParser {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func date(from raw: String) -> Date? {
        withFraction.date(from: raw) ?? plain.date(from: raw)
    }
}

private extension String {
    /// lowercase + sem acento, pra busca tolerante.
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
