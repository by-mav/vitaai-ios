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
        // Aquece o agendamento FSRS salvo no device pra a 1ª abertura de
        // disciplina já ordenar por `due` sem esperar I/O. Idempotente.
        Task { await LocalFlashcardStore.shared.load() }
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

    /// Abre uma DISCIPLINA da Biblioteca. OFFLINE-FIRST: os cards curados vêm do
    /// bundle (VitaContentBundle) — o card SEMPRE abre, sem internet. Cai no
    /// servidor só se o bundle não tiver a disciplina (ex: build antigo).
    ///
    /// Uma disciplina não é um baralho — os cards dela vivem espalhados por
    /// vários (Cardiologia está dentro do acervo "Medicina"). Então não há
    /// `deckId` pra abrir: o que existe é a fila de cards.
    ///
    /// Retorna um marcador de sessão pra navegar; nil quando não há card.
    func openDiscipline(slug: String, title: String, due: Int) async -> String? {
        await Self.openDiscipline(slug: slug, title: title, due: due, api: api)
    }

    /// Mesma abertura, sem depender de uma instância do view model — a tela
    /// central do baralho (DeckHomeScreen via AppRouter) monta a fila da
    /// Biblioteca por aqui. UM caminho só; nada de fila duplicada.
    static func openDiscipline(
        slug: String,
        title: String,
        due: Int,
        api: VitaAPI
    ) async -> String? {
        // 1) Bundle primeiro — offline, instantâneo, nunca falha por rede.
        let bundleCards = await VitaContentBundle.shared.cards(disciplineSlug: slug)
        if !bundleCards.isEmpty {
            // Aplica o agendamento FSRS salvo no device e ORDENA estilo Anki:
            // vencidos primeiro (por `due`), depois novos (teto diário). Sem isto
            // a fila vinha SEMPRE na ordem fixa do JSON e todo card nascia `new`.
            let saved = await LocalFlashcardStore.shared.states(forIds: bundleCards.map(\.id))
            let cards = Self.orderedBundleQueue(bundleCards, saved: saved)
            FlashcardMultiDeckHandoff.shared.setBundleCards(cards, title: title)
            // Marcador não-vazio só pra a tela navegar (a fila real está no handoff).
            return "bundle:\(slug)"
        }

        // 2) Fallback servidor (disciplina fora do bundle / build antigo).
        // `specific` = so REVIEW/LEARNING (card ja estudado). Disciplina virgem —
        // e a Biblioteca inteira eh NEW — devolvia fila VAZIA nesse modo. Tem
        // vencido? revisa. Nao tem? abre os novos.
        let mode = due > 0 ? "due" : "new"
        do {
            var resp = try await api.createFlashcardSession(
                body: FlashcardSessionBody(
                    groupSlugs: [slug],
                    mode: mode,
                    limit: nil,
                    showHints: nil,
                    skipEasy: nil,
                    cardIds: nil,
                    deckId: nil,
                    title: title
                )
            )
            // Teto diario de novos ja batido: `new` volta vazio mesmo tendo card.
            // Cai pra `cram` (tudo da disciplina, sem due) — o aluno pediu ESTA
            // disciplina, entregar tela vazia seria mentira.
            if resp.cardIds.isEmpty {
                resp = try await api.createFlashcardSession(
                    body: FlashcardSessionBody(
                        groupSlugs: [slug],
                        mode: "cram",
                        limit: nil,
                        showHints: nil,
                        skipEasy: nil,
                        cardIds: nil,
                        deckId: nil,
                        title: title
                    )
                )
            }
            guard !resp.cardIds.isEmpty else { return nil }
            FlashcardMultiDeckHandoff.shared.setQuickSession(
                cardIds: resp.cardIds,
                title: title,
                sessionId: resp.sessionId
            )
            return resp.sessionId
        } catch {
            NSLog("[FlashcardBuilder] openDiscipline(%@) error: %@", slug, String(describing: error))
            return nil
        }
    }

    // MARK: - Fila Anki-style (offline, do bundle)

    /// Teto de cards NOVOS por abertura (Anki default = 20/dia). Evita despejar
    /// milhares de cards de uma vez; os novos entram aos poucos.
    private static let dailyNewLimit = 20

    /// Monta a fila de estudo estilo Anki a partir dos cards do bundle + o estado
    /// FSRS salvo no device:
    ///   1. VENCIDOS (due <= agora) primeiro, do mais atrasado pro menos.
    ///   2. depois NOVOS (nunca vistos), na ordem do bundle, com teto diário.
    /// Cards já revisados mas AINDA não vencidos ficam fora da fila de hoje (é o
    /// comportamento do Anki). Se não houver vencido nem novo, cai pra cram (todos
    /// na ordem salva) — disciplina que o aluno TOCOU nunca abre vazia.
    ///
    /// O estado salvo entra pela via dos campos FSRS do `FlashcardCard`
    /// (stability/difficulty/state/scheduledDays/nextReviewAt); o
    /// `FlashcardViewModel.startSession` re-hidrata o `FsrsCardState` a partir
    /// deles. Card sem estado salvo = New.
    static func orderedBundleQueue(
        _ bundle: [VitaContentBundle.BundleCard],
        saved: [String: FsrsCardState],
        now: Date = Date()
    ) -> [FlashcardCard] {
        let newLimit = dailyNewLimit
        var due: [(card: FlashcardCard, due: Date)] = []
        var news: [FlashcardCard] = []
        var future: [FlashcardCard] = []   // revisados, ainda não vencidos

        for bc in bundle {
            guard let s = saved[bc.id] else {
                // Nunca visto = New (difficulty 0 / stability default => vira new no VM).
                news.append(FlashcardCard(id: bc.id, front: bc.front, back: bc.back))
                continue
            }
            let dueDate = LocalFlashcardStore.dueDate(for: s) ?? now
            let card = FlashcardCard(
                id: bc.id,
                front: bc.front,
                back: bc.back,
                stability: s.stability,
                difficulty: s.difficulty,   // FSRS clamp 1–10 => hidrata via ramo nativo
                state: s.status.rawValue,
                scheduledDays: s.scheduledDays,
                nextReviewAt: dueDate
            )
            if dueDate <= now {
                due.append((card, dueDate))
            } else {
                future.append(card)
            }
        }

        due.sort { $0.due < $1.due }   // mais atrasado primeiro
        let cappedNew = Array(news.prefix(max(0, newLimit)))
        let queue = due.map(\.card) + cappedNew
        if !queue.isEmpty { return queue }

        // Nada vencido nem novo (tudo agendado pro futuro): cram — nunca abre vazio.
        if !future.isEmpty { return future }
        return bundle.map { FlashcardCard(id: $0.id, front: $0.front, back: $0.back) }
    }

    private func loadLibrary() async {
        // OFFLINE PRIMEIRO: o que já está BAIXADO no aparelho aparece na hora,
        // sem rede. Sem isto, o aluno em modo avião via só o skeleton — tinha o
        // baralho no device e não conseguia chegar nele (Rafael 2026-07-19).
        let downloaded = await DeckPackStore.shared.allManifests()

        // 🚨 O SERVIDOR é o catálogo; o que está baixado é só ESTADO de cada item
        // (Rafael 2026-07-20: "o único baralho que aparece é anatomia, cadê os
        // outros?"). Antes o local entrava PRIMEIRO e, tendo 1 baralho no
        // aparelho, a tela pintava uma biblioteca de 1 item — o aluno não tinha
        // como descobrir que existem 42 disciplinas. O offline vira FALLBACK:
        // só assume a vitrine quando a rede realmente falhou.
        do {
            state.library = try await api.getFlashcardLibrary()
            state.libraryFailed = false
        } catch {
            // Sem rede: aí sim vale o que está no aparelho (modo avião).
            if !downloaded.isEmpty {
                state.library = Self.offlineLibrary(downloaded)
                state.libraryFailed = false
            } else {
                state.libraryFailed = true
            }
            NSLog("[FlashcardBuilder] loadLibrary error: %@", String(describing: error))
        }
    }

    /// Árvore montada com o que existe NO APARELHO — a Biblioteca offline.
    private static func offlineLibrary(
        _ manifests: [DeckPackStore.Manifest]
    ) -> FlashcardLibraryResponse {
        var area = FlashcardLibraryArea()
        area.slug = "baixados"
        area.name = "No aparelho"
        area.total = manifests.reduce(0) { $0 + $1.cardCount }
        area.disciplines = manifests.map { m in
            var d = FlashcardLibraryDiscipline()
            d.slug = m.slug
            d.name = m.title
            d.total = m.cardCount
            return d
        }
        var lib = FlashcardLibraryResponse()
        lib.areas = [area]
        lib.totalCards = area.total
        return lib
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
