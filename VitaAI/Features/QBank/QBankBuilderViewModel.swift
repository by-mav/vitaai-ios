import Foundation
import Observation

// MARK: - QBankBuilderViewModel — Fase 3 reescrita gold-standard
//
// Substitui QBankViewModel + QBankHomeContent + QBankConfigContent.
// State único pra tela Builder: Hero + Lente + Filtros + Recents + CTA.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §6
//
// API:
//  - GET  /api/qbank/filters?lens=  → groups + institutions + topics + years + difficulties
//  - POST /api/qbank/preview        → count dinâmico (debounced 300ms)
//  - GET  /api/qbank/progress       → hero stats
//  - GET  /api/qbank/sessions       → recentes
//  - POST /api/qbank/sessions       → cria sessão e navega

// MARK: - State

struct QBankBuilderState {
    // Filters carregados do backend (lens-aware)
    var groups: [QBankGroup] = []
    var institutions: [QBankInstitution] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var stage: String? = nil

    // Seleções do user
    var selectedGroupSlugs: Set<String> = []
    /// Slugs do level 2 (clusters PBL ou topic IDs Tradicional). Composto
    /// como "parent/child" pra permitir mesmo cluster em múltiplos sistemas.
    var selectedSubgroupIds: Set<String> = []  // formato: "parentSlug/childSlug"
    /// Sistemas/disciplinas com children expandidos na UI.
    var expandedGroupSlugs: Set<String> = []
    var selectedInstitutionIds: Set<Int> = []
    var selectedYearMin: Int? = nil
    var selectedYearMax: Int? = nil
    var selectedDifficulties: Set<String> = []
    var selectedFormats: Set<String> = []  // 'objective' | 'discursive' | 'withImage'

    // Toggles avançadas
    var hideAnswered: Bool = false
    var hideAnnulled: Bool = false
    var hideReviewed: Bool = false
    var excludeNoExplanation: Bool = true
    var includeSynthetic: Bool = false  // default false: oficial only

    // Configuração da sessão
    var questionCount: Int = 20
    var mode: QBankMode = .pratica

    // Preview live count
    var previewCount: Int? = nil
    var previewLoading: Bool = false
    var previewFacets: QBankPreviewFacets? = nil
    var formatCounts: [String: Int] = [:]
    var yearCounts: [String: Int] = [:]

    // Hero (progress)
    var progressTotal: Int = 0
    var progressAnswered: Int = 0
    var progressAccuracy: Double = 0.0
    /// Spec §3.1 — ofensiva no Hero. Default 0 ⇒ stat oculto (sem fake).
    /// Hidratado quando endpoint expor; hoje só fica visível se backend popular
    /// via outro caminho (p.ex. progress payload futuro).
    var streakDays: Int = 0

    // Recents
    var recentSessions: [QBankSessionSummary] = []

    // Loading flags
    var filtersLoading: Bool = true
    var creatingSession: Bool = false
    var error: String? = nil

    /// Display count: SEMPRE reflete preview API (count real com filtros aplicados).
    /// Reclamação Rafael #14: 'o 2327 questões não sai dali, independente do que tá selecionado'.
    /// Bug antigo: fallback em `totalQuestions` (count do banco com filtros vazios) ficava fixo
    /// quando user mudava filtro e preview ainda não retornou. Agora retorna 0 enquanto loading
    /// — UI já tem `previewLoading` flag pra esconder o número e mostrar shimmer.
    /// Se preview ainda não foi chamado (state.previewCount nil + !previewLoading), cai no
    /// progressTotal (hero stats) que reflete o que o user tem disponível no banco — não
    /// hardcode, é dinâmico via getQBankProgress.
    var displayCount: Int {
        if let live = previewCount { return live }
        if previewLoading { return 0 }
        return progressTotal
    }

    var hasActiveFilters: Bool {
        !selectedGroupSlugs.isEmpty
            || !selectedInstitutionIds.isEmpty
            || !selectedDifficulties.isEmpty
            || !selectedFormats.isEmpty
            || selectedYearMin != nil
            || selectedYearMax != nil
            || hideAnswered || hideAnnulled || hideReviewed
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class QBankBuilderViewModel {
    var state = QBankBuilderState()

    private let api: VitaAPI
    private let dataManager: AppDataManager

    /// Debounce de preview (cancela request anterior se user mexer rápido).
    private var previewTask: Task<Void, Never>?

    init(api: VitaAPI, dataManager: AppDataManager) {
        self.api = api
        self.dataManager = dataManager
    }

    // MARK: - Boot

    /// Hidrata lente do profile + carrega filters + progress + recents em paralelo.
    func boot() {
        Task { await loadAll() }
    }

    private func loadAll() async {
        state.filtersLoading = true
        state.previewLoading = true
        // Boot paralelo: filtros + progresso + recents + preview inicial em uma onda só.
        // Antes era sequencial (filters→progress→recents→DEBOUNCE 300ms→preview), causava
        // grupos/áreas piscando vazio. Reclamação Rafael #13: "tu não colocou tudo no promise.all?"
        async let filtersTask: Void = loadFilters()
        async let progressTask: Void = loadProgress()
        async let recentsTask: Void = loadRecents()
        async let previewTask: Void = loadInitialPreview()
        _ = await (filtersTask, progressTask, recentsTask, previewTask)
        state.filtersLoading = false
    }

    /// Preview inicial sem debounce — roda em paralelo com filters no boot.
    /// Subsequent reloads em mutações de filtro continuam via `scheduleRefreshPreview()` (debounced).
    private func loadInitialPreview() async {
        await refreshPreview()
    }

    // MARK: - Filters

    func loadFilters() async {
        do {
            let resp = try await api.getQBankFilters(stage: "all")
            NSLog("[QBankBuilder] loadFilters areas=%d insts=%d total=%d",
                  resp.groups.count,
                  resp.institutions.count,
                  resp.totalQuestions)
            if let first = resp.groups.first {
                NSLog("[QBankBuilder] first group: %@ (%d Q)", first.name, first.count)
            }
            state.groups = resp.groups
            state.institutions = resp.institutions
            state.years = resp.years
            state.difficulties = resp.difficulties
            state.totalQuestions = resp.totalQuestions
            applyPreviewFacets(state.previewFacets)
        } catch {
            NSLog("[QBankBuilder] loadFilters ERROR: %@", String(describing: error))
            state.error = "Não foi possível carregar filtros"
        }
    }

    private func loadProgress() async {
        do {
            let resp = try await api.getQBankProgress(disciplineSlugs: [])
            state.progressTotal = resp.totalAvailable
            state.progressAnswered = resp.totalAnswered
            state.progressAccuracy = resp.normalizedAccuracy
        } catch {
            print("[QBankBuilder] loadProgress: \(error)")
        }
    }

    private func loadRecents() async {
        do {
            let resp = try await api.getQBankSessions(limit: 5)
            state.recentSessions = resp.sessions
        } catch {
            print("[QBankBuilder] loadRecents: \(error)")
        }
    }


    // MARK: - Filters mutations

    func toggleGroup(slug: String) {
        if state.selectedGroupSlugs.contains(slug) {
            state.selectedGroupSlugs.remove(slug)
            // Ao desselecionar group, derruba subgroups dele
            state.selectedSubgroupIds = state.selectedSubgroupIds.filter { !$0.hasPrefix("\(slug)/") }
        } else {
            state.selectedGroupSlugs.insert(slug)
        }
        scheduleRefreshPreview()
    }

    func toggleExpand(slug: String) {
        if state.expandedGroupSlugs.contains(slug) {
            state.expandedGroupSlugs.remove(slug)
        } else {
            state.expandedGroupSlugs.insert(slug)
        }
    }

    /// Toggla um subgroup (cluster/topic). Auto-seleciona o group pai se ainda não.
    func toggleSubgroup(parentSlug: String, childSlug: String) {
        let id = "\(parentSlug)/\(childSlug)"
        if state.selectedSubgroupIds.contains(id) {
            state.selectedSubgroupIds.remove(id)
        } else {
            state.selectedSubgroupIds.insert(id)
            // Auto-seleciona pai
            state.selectedGroupSlugs.insert(parentSlug)
        }
        scheduleRefreshPreview()
    }

    func toggleInstitution(id: Int) {
        if state.selectedInstitutionIds.contains(id) {
            state.selectedInstitutionIds.remove(id)
        } else {
            state.selectedInstitutionIds.insert(id)
        }
        scheduleRefreshPreview()
    }

    func toggleDifficulty(_ d: String) {
        if state.selectedDifficulties.contains(d) {
            state.selectedDifficulties.remove(d)
        } else {
            state.selectedDifficulties.insert(d)
        }
        scheduleRefreshPreview()
    }

    func toggleFormat(_ f: String) {
        if state.selectedFormats.contains(f) {
            state.selectedFormats.remove(f)
        } else {
            state.selectedFormats.insert(f)
        }
        scheduleRefreshPreview()
    }

    func setYearRange(min: Int?, max: Int?) {
        state.selectedYearMin = min
        state.selectedYearMax = max
        scheduleRefreshPreview()
    }

    func setHideAnswered(_ v: Bool) { state.hideAnswered = v; scheduleRefreshPreview() }
    func setHideAnnulled(_ v: Bool) { state.hideAnnulled = v; scheduleRefreshPreview() }
    func setHideReviewed(_ v: Bool) { state.hideReviewed = v; scheduleRefreshPreview() }
    func setExcludeNoExplanation(_ v: Bool) { state.excludeNoExplanation = v; scheduleRefreshPreview() }
    func setIncludeSynthetic(_ v: Bool) { state.includeSynthetic = v; scheduleRefreshPreview() }

    func setQuestionCount(_ n: Int) { state.questionCount = max(1, min(100, n)) }
    func setMode(_ m: QBankMode) { state.mode = m }

    func clearAllFilters() {
        state.selectedGroupSlugs.removeAll()
        state.selectedSubgroupIds.removeAll()
        state.expandedGroupSlugs.removeAll()
        state.selectedInstitutionIds.removeAll()
        state.selectedDifficulties.removeAll()
        state.selectedFormats.removeAll()
        state.selectedYearMin = nil
        state.selectedYearMax = nil
        state.hideAnswered = false
        state.hideAnnulled = false
        state.hideReviewed = false
        scheduleRefreshPreview()
    }

    // MARK: - Preview (debounced)

    func scheduleRefreshPreview() {
        previewTask?.cancel()
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            await self.refreshPreview()
        }
    }

    private func refreshPreview() async {
        state.previewLoading = true
        defer { state.previewLoading = false }

        // Arvore unica: nivel 1 (`groups`) = as 6 AREAS, nivel 2 (`children`) = DISCIPLINAS.
        let areaSlugs = Array(state.selectedGroupSlugs)
        // Nivel 2 vem composto "area/disciplina" (mesma disciplina pode aparecer sob
        // mais de uma area) — o backend quer so o slug da disciplina.
        let disciplineSlugs = state.selectedSubgroupIds.compactMap { id -> String? in
            id.split(separator: "/", maxSplits: 1).last.map(String.init)
        }
        NSLog("[QBankBuilder] preview body areas=%@ disciplinas=%@ insts=%@ diffs=%@",
              String(describing: areaSlugs),
              String(describing: disciplineSlugs),
              String(describing: Array(state.selectedInstitutionIds)),
              String(describing: Array(state.selectedDifficulties)))

        let body = QBankPreviewBody(
            areaSlugs: areaSlugs.nilIfEmpty,
            disciplineSlugs: disciplineSlugs.nilIfEmpty,
            institutionIds: Array(state.selectedInstitutionIds).nilIfEmpty,
            topicIds: nil,
            years: yearsBody(),
            difficulties: Array(state.selectedDifficulties).nilIfEmpty,
            format: Array(state.selectedFormats).nilIfEmpty,
            hideAnswered: state.hideAnswered ? true : nil,
            hideAnnulled: state.hideAnnulled ? true : nil,
            hideReviewed: state.hideReviewed ? true : nil,
            excludeNoExplanation: state.excludeNoExplanation,
            includeSynthetic: state.includeSynthetic,
            stage: "all"
        )

        do {
            let resp = try await api.previewQBankPool(body: body)
            NSLog("[QBankBuilder] preview RESPONSE total=%d (areas=%@ disciplinas=%@)",
                  resp.total,
                  String(describing: areaSlugs),
                  String(describing: disciplineSlugs))
            state.previewCount = resp.total
            applyPreviewFacets(resp.facets)
        } catch {
            NSLog("[QBankBuilder] preview ERROR: %@", String(describing: error))
            state.previewCount = nil
        }
    }

    private func applyPreviewFacets(_ facets: QBankPreviewFacets?) {
        guard let facets else { return }
        state.previewFacets = facets
        // Só sobrescreve cada faceta quando o backend manda algo (não-vazio).
        // Assim as contagens de FILTROS (formato/ano/instituição/dificuldade)
        // ficam vivas (minus-self) sem zerar Disciplinas quando groups vem vazio.
        if !facets.formats.isEmpty { state.formatCounts = facets.formats }
        if !facets.years.isEmpty { state.yearCounts = facets.years }
        if !facets.groups.isEmpty || !facets.subgroups.isEmpty {
            state.groups = state.groups.map { current in
                var group = current
                group.count = facets.groups[group.slug] ?? group.count
                group.children = group.children.map { currentChild in
                    var child = currentChild
                    child.count = facets.subgroups[child.id] ?? child.count
                    return child
                }
                return group
            }
        }
        if !facets.institutions.isEmpty {
            state.institutions = state.institutions.map { current in
                var institution = current
                institution.count = facets.institutions[String(institution.id)] ?? institution.count
                return institution
            }
        }
        if !facets.difficulties.isEmpty {
            state.difficulties = state.difficulties.map { current in
                var difficulty = current
                difficulty.count = facets.difficulties[difficulty.difficulty] ?? difficulty.count
                return difficulty
            }
        }
    }

    private func yearsBody() -> QBankPreviewYears? {
        if state.selectedYearMin == nil && state.selectedYearMax == nil { return nil }
        return QBankPreviewYears(min: state.selectedYearMin, max: state.selectedYearMax)
    }

    private func selectedYears() -> [Int]? {
        guard state.selectedYearMin != nil || state.selectedYearMax != nil else { return nil }
        let minYear = state.selectedYearMin ?? state.years.min()
        let maxYear = state.selectedYearMax ?? state.years.max()
        if !state.years.isEmpty {
            return state.years
                .filter { year in
                    (minYear.map { year >= $0 } ?? true) && (maxYear.map { year <= $0 } ?? true)
                }
                .sorted()
                .nilIfEmpty
        }
        guard let minYear, let maxYear, minYear <= maxYear else { return nil }
        return Array(minYear...maxYear)
    }

    private func selectedSubgroupSlugs() -> [String]? {
        state.selectedSubgroupIds
            .compactMap { id in id.split(separator: "/", maxSplits: 1).last.map(String.init) }
            .sorted()
            .nilIfEmpty
    }

    // MARK: - Create session

    /// Cria sessão com filtros aplicados. Retorna sessionId pra navegação.
    func createSession() async -> String? {
        state.creatingSession = true
        defer { state.creatingSession = false }

        // Cada nivel da arvore no SEU campo. Antes a lente escolhia pra qual campo os
        // slugs iam (disciplineSlugs|pblSystemSlugs|examGreatAreaSlugs) — com 1 arvore
        // isso deixa de ser condicional: nivel 1 = area, nivel 2 = disciplina.
        let req = QBankCreateSessionRequest(
            questionCount: state.questionCount,
            institutionIds: Array(state.selectedInstitutionIds).nilIfEmpty,
            years: selectedYears(),
            difficulties: Array(state.selectedDifficulties).nilIfEmpty,
            areaSlugs: Array(state.selectedGroupSlugs).nilIfEmpty,
            disciplineSlugs: selectedSubgroupSlugs(),
            topicIds: nil,
            disciplineIds: nil,
            mode: state.mode.rawValue,
            onlyResidence: nil,
            onlyUnanswered: state.hideAnswered ? true : nil,
            title: nil,
            stage: "all",
            status: nil,
            excludeNoExplanation: state.excludeNoExplanation,
            includeSynthetic: state.includeSynthetic,
            // Spec §11.4 — Avançadas. Backend já aceita (placeholder no-op
            // até table de revisão). Enviar somente quando true (nil omite).
            hideAnnulled: state.hideAnnulled ? true : nil,
            hideReviewed: state.hideReviewed ? true : nil,
            format: Array(state.selectedFormats).nilIfEmpty
        )

        do {
            let session = try await api.createQBankSession(request: req)
            return session.id
        } catch {
            print("[QBankBuilder] createSession: \(error)")
            state.error = "Não foi possível iniciar a sessão"
            return nil
        }
    }
}

// MARK: - Helpers

private extension Array where Element: Hashable {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? { isEmpty ? nil : self }
}

private extension Array where Element == Int {
    var nilIfEmpty: [Int]? { isEmpty ? nil : self }
}
