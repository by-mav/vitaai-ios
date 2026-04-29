import Foundation
import Observation

// MARK: - FlashcardBuilderViewModel — Fase 5 reescrita gold-standard
//
// Substitui o builder embutido em FlashcardsListScreen.
// Tela única: Hero + ModeSelector (Revisão/Específico/Novos) + (se Específico)
// Lente + drill-down + Origem + Avançadas + Decks grid + CTA sticky.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.3 + §11.3
//
// API:
//  - GET  /api/study/flashcards?subjectId&due&cardsLimit&deckLimit  → [FlashcardDeckEntry]
//  - GET  /api/study/flashcards/stats                               → FlashcardStatsResponse
//  - POST /api/study/flashcards/generate (autoSeed)                 → AutoSeedResponse
//
// `POST /api/study/flashcards/session` (A5 wave) ainda não existe; createSession()
// faz fallback graceful: se 404, abre primeiro deck due via `firstDueDeckId()`.

// MARK: - Mode

enum FlashcardSessionMode: String, CaseIterable, Identifiable {
    case due       // SRS — revisão pendente (default)
    case specific  // filtros lente-aware
    case newCards  // nunca vistos

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .due: return "Revisão Pendente"
        case .specific: return "Estudar Específico"
        case .newCards: return "Cards Novos"
        }
    }

    var systemIcon: String {
        switch self {
        case .due: return "clock.arrow.circlepath"
        case .specific: return "slider.horizontal.3"
        case .newCards: return "sparkles"
        }
    }

    var subtitle: String {
        switch self {
        case .due: return "SRS"
        case .specific: return "Filtros"
        case .newCards: return "Nunca vistos"
        }
    }
}

enum FlashcardOrigin: String, CaseIterable, Identifiable {
    case all
    case ai          // Vita gerou via IA
    case manual      // criado pelo aluno
    case overlays    // overlays (anotações próprias)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "Todas"
        case .ai: return "Vita IA"
        case .manual: return "Eu criei"
        case .overlays: return "Overlays"
        }
    }

    var systemIcon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .ai: return "sparkles"
        case .manual: return "pencil"
        case .overlays: return "highlighter"
        }
    }
}

enum FlashcardSessionLimit: Int, CaseIterable, Identifiable {
    case ten = 10
    case twenty = 20
    case forty = 40
    case unlimited = 0  // 0 = sem limite

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .ten: return "10"
        case .twenty: return "20"
        case .forty: return "40"
        case .unlimited: return "Sem limite"
        }
    }
}

// MARK: - State

struct FlashcardBuilderState {
    // Mode
    var mode: FlashcardSessionMode = .due

    // Lente (só vale quando mode = .specific)
    var lens: ContentOrganizationMode = .greatAreas

    // Filtros (só `.specific`)
    var groups: [QBankGroup] = []                       // populado via QBank filters (compartilhado)
    var selectedGroupSlugs: Set<String> = []
    var selectedSubgroupIds: Set<String> = []           // "parent/child"
    var origin: FlashcardOrigin = .all

    // Avançadas
    var sessionLimit: FlashcardSessionLimit = .twenty
    var showHints: Bool = true
    var skipTooEasy: Bool = false

    // Hero / stats
    var dueNow: Int = 0
    var totalCards: Int = 0
    var reviewedToday: Int = 0
    var streakDays: Int = 0

    // Preview (GET /api/study/flashcards/preview) — render no Hero/CTA
    var previewDue: Int = 0
    var previewLearning: Int = 0
    var previewNew: Int = 0
    var previewProjectedMinutes: Int = 0
    var previewLoading: Bool = false

    // Sessão criada (POST /api/study/flashcards/session)
    var lastSessionId: String? = nil
    var lastSessionCardIds: [String] = []

    // Decks
    var decks: [FlashcardDeckEntry] = []

    // Loading flags
    var statsLoading: Bool = true
    var decksLoading: Bool = true
    var creatingSession: Bool = false
    var error: String? = nil

    /// Display count pro CTA: muda conforme mode.
    var displayCount: Int {
        switch mode {
        case .due: return dueNow
        case .specific:
            // Soma dueCount dos decks que casam com selectedGroupSlugs (best-effort).
            // Se nada selecionado, usa total visível.
            if selectedGroupSlugs.isEmpty {
                return decks.reduce(0) { $0 + ($1.dueCount ?? 0) }
            }
            return decks
                .filter { d in
                    guard let slug = d.disciplineSlug else { return false }
                    return selectedGroupSlugs.contains(slug)
                }
                .reduce(0) { $0 + ($1.dueCount ?? 0) }
        case .newCards:
            // Cards novos = total - dueNow - reviewedToday (proxy).
            return max(0, totalCards - dueNow - reviewedToday)
        }
    }

    var hasActiveFilters: Bool {
        mode == .specific && (
            !selectedGroupSlugs.isEmpty ||
            !selectedSubgroupIds.isEmpty ||
            origin != .all
        )
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class FlashcardBuilderViewModel {
    var state = FlashcardBuilderState()

    private let api: VitaAPI
    private let dataManager: AppDataManager

    init(api: VitaAPI, dataManager: AppDataManager) {
        self.api = api
        self.dataManager = dataManager
    }

    // MARK: - Boot

    func boot() {
        if let lens = dataManager.profile?.contentOrganizationMode {
            state.lens = lens
        }
        Task { await loadAll() }
    }

    /// Pré-seleciona uma disciplina (vem de DisciplineDetailScreen → flashcardHome).
    /// Switcha mode pra `.specific` (faz sentido — user veio de tela de disciplina,
    /// quer estudar AQUELA disciplina, não revisão geral). Idempotente: chamar 2x
    /// não duplica nem volta a desmarcar.
    /// Onda 5 (2026-04-29) — restaura comportamento perdido na Onda 3 router rewire.
    func setInitialSubject(slug: String?) {
        guard let slug, !slug.isEmpty else { return }
        guard !state.selectedGroupSlugs.contains(slug) else { return }
        state.mode = .specific
        state.selectedGroupSlugs.insert(slug)
        Task { await refreshPreview() }
    }

    private func loadAll() async {
        // Boot paralelo (decks + stats + filters/groups + preview). Render progressivo
        // assim que cada um chega — Hero render imediato com stats, decks
        // hidratam grid embaixo, filtros lente-aware ficam prontos pro modo
        // .specific. Se algum falha, o resto continua.
        async let decksTask: Void = loadDecks()
        async let statsTask: Void = loadStats()
        async let filtersTask: Void = loadFilters()
        async let previewTask: Void = refreshPreview()
        _ = await (decksTask, statsTask, filtersTask, previewTask)
    }

    /// GET /api/study/flashcards/preview — atualiza counts due/learning/new
    /// + projectedSessionTime sem criar sessão. Chamar quando mode/lens/groupSlug
    /// mudar. Spec: openapi.yaml linha 5132.
    func refreshPreview() async {
        state.previewLoading = true
        defer { state.previewLoading = false }
        let firstGroup = state.selectedGroupSlugs.first
        let modeStr: String
        switch state.mode {
        case .due: modeStr = "due"
        case .specific: modeStr = "specific"
        case .newCards: modeStr = "new"
        }
        do {
            let resp = try await api.previewFlashcards(
                lens: state.lens.rawValue,
                groupSlug: firstGroup,
                mode: modeStr
            )
            state.previewDue = resp.due
            state.previewLearning = resp.learning
            state.previewNew = resp.new
            state.previewProjectedMinutes = resp.projectedSessionTime
        } catch {
            NSLog("[FlashcardBuilder] previewFlashcards error: %@", String(describing: error))
        }
    }

    private func loadDecks() async {
        state.decksLoading = true
        defer { state.decksLoading = false }
        do {
            // summary=true: 182KB pra ~530 decks. Hidratação on-demand
            // quando user tapa o deck (FlashcardSessionScreen carrega cards).
            let decks = try await api.getFlashcardDecks(summary: true)
            state.decks = decks.filter { $0.cardCount > 0 }
        } catch {
            NSLog("[FlashcardBuilder] loadDecks error: %@", String(describing: error))
            state.error = "Não foi possível carregar baralhos"
        }
    }

    private func loadStats() async {
        state.statsLoading = true
        defer { state.statsLoading = false }
        do {
            let stats = try await api.getFlashcardStats()
            state.totalCards = stats.totalCards
            state.reviewedToday = stats.todayReviews
            state.streakDays = stats.streakDays
            // dueNow vem do studyOverviewStore (canon) OU derivado dos decks.
            state.dueNow = state.decks.reduce(0) { $0 + ($1.dueCount ?? 0) }
        } catch {
            NSLog("[FlashcardBuilder] loadStats error: %@", String(describing: error))
        }
    }

    /// Carrega groups do endpoint QBank (compartilhado entre as 3 telas Estudos).
    /// Lens-aware: tradicional/pbl/great-areas. Não bloqueia render — só usado
    /// quando mode = .specific.
    private func loadFilters() async {
        do {
            let resp = try await api.getQBankFilters(lens: state.lens.rawValue)
            state.groups = resp.groups
        } catch {
            NSLog("[FlashcardBuilder] loadFilters error: %@", String(describing: error))
        }
    }

    // MARK: - Mutations

    func setMode(_ m: FlashcardSessionMode) {
        guard state.mode != m else { return }
        state.mode = m
        Task { await refreshPreview() }
    }

    func setLens(_ lens: ContentOrganizationMode) {
        guard state.lens != lens else { return }
        state.lens = lens
        state.selectedGroupSlugs.removeAll()
        state.selectedSubgroupIds.removeAll()
        Task {
            await loadFilters()
            await refreshPreview()
        }
    }

    func setOrigin(_ o: FlashcardOrigin) {
        state.origin = o
    }

    func setSessionLimit(_ l: FlashcardSessionLimit) {
        state.sessionLimit = l
    }

    func setShowHints(_ v: Bool) { state.showHints = v }
    func setSkipTooEasy(_ v: Bool) { state.skipTooEasy = v }

    func toggleGroup(slug: String) {
        if state.selectedGroupSlugs.contains(slug) {
            state.selectedGroupSlugs.remove(slug)
            state.selectedSubgroupIds = state.selectedSubgroupIds.filter { !$0.hasPrefix("\(slug)/") }
        } else {
            state.selectedGroupSlugs.insert(slug)
        }
        Task { await refreshPreview() }
    }

    func toggleSubgroup(parentSlug: String, childSlug: String) {
        let id = "\(parentSlug)/\(childSlug)"
        if state.selectedSubgroupIds.contains(id) {
            state.selectedSubgroupIds.remove(id)
        } else {
            state.selectedSubgroupIds.insert(id)
            state.selectedGroupSlugs.insert(parentSlug)
        }
        Task { await refreshPreview() }
    }

    func clearAllFilters() {
        state.selectedGroupSlugs.removeAll()
        state.selectedSubgroupIds.removeAll()
        state.origin = .all
        Task { await refreshPreview() }
    }

    // MARK: - Create session

    /// Cria sessão SRS via POST /api/study/flashcards/session (FSRS scheduling).
    /// Hidrata `state.lastSessionId` + `state.lastSessionCardIds`. Retorna
    /// deckId do primeiro deck que casa com o mode pra compat com a navegação
    /// atual (`FlashcardSessionScreen(deckId:)`); refactor pra cardIds[]/sessionId
    /// é trabalho do A2/A3 quando reescrevem a Session screen.
    /// Spec: openapi.yaml linha 5169.
    func createSession() async -> String? {
        state.creatingSession = true
        defer { state.creatingSession = false }

        let modeStr: String
        switch state.mode {
        case .due: modeStr = "due"
        case .specific: modeStr = "specific"
        case .newCards: modeStr = "new"
        }
        let limit = state.sessionLimit.rawValue == 0 ? nil : state.sessionLimit.rawValue
        let body = FlashcardSessionBody(
            lens: state.lens.rawValue,
            groupSlugs: state.selectedGroupSlugs.isEmpty ? nil : Array(state.selectedGroupSlugs),
            mode: modeStr,
            limit: limit,
            showHints: state.showHints,
            skipEasy: state.skipTooEasy
        )

        do {
            let resp = try await api.createFlashcardSession(body: body)
            state.lastSessionId = resp.sessionId
            state.lastSessionCardIds = resp.cardIds
        } catch {
            NSLog("[FlashcardBuilder] createFlashcardSession error: %@", String(describing: error))
            // Não bloqueia UX — segue pro fallback deck-based.
        }

        return firstDeckId(for: state.mode)
    }

    /// Primeiro deck que casa com o mode atual. Usado por createSession()
    /// fallback E pelo grid (tap direto no deck).
    func firstDeckId(for mode: FlashcardSessionMode) -> String? {
        switch mode {
        case .due:
            return state.decks.first(where: { ($0.dueCount ?? 0) > 0 })?.id
                ?? state.decks.first?.id
        case .specific:
            if state.selectedGroupSlugs.isEmpty {
                return state.decks.first(where: { ($0.dueCount ?? 0) > 0 })?.id
                    ?? state.decks.first?.id
            }
            return state.decks.first(where: { d in
                guard let slug = d.disciplineSlug else { return false }
                return state.selectedGroupSlugs.contains(slug)
            })?.id
        case .newCards:
            return state.decks.first(where: { ($0.dueCount ?? 0) == 0 })?.id
                ?? state.decks.first?.id
        }
    }

    // MARK: - Decks filtering (pro grid embaixo)

    /// Decks visíveis no grid considerando mode + filtros.
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
