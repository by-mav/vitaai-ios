import Foundation

// MARK: - Filters

struct QBankFiltersResponse: Decodable {
    /// Nivel 1 da arvore: as 6 grandes areas, cada uma com `children` = disciplinas.
    var groups: [QBankGroup] = []
    var institutions: [QBankInstitution] = []
    var topics: [QBankTopic] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var disciplines: [QBankDiscipline] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = (try? c.decode([QBankGroup].self, forKey: .groups)) ?? []
        institutions = (try? c.decode([QBankInstitution].self, forKey: .institutions)) ?? []
        topics = (try? c.decode([QBankTopic].self, forKey: .topics)) ?? []
        years = (try? c.decode([Int].self, forKey: .years))
            ?? (try? c.decode([QBankYearStat].self, forKey: .years).map(\.year))
            ?? []
        difficulties = (try? c.decode([QBankDifficultyStat].self, forKey: .difficulties)) ?? []
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        disciplines = (try? c.decode([QBankDiscipline].self, forKey: .disciplines)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case groups, institutions, topics, years, difficulties, totalQuestions, disciplines
    }
}

private struct QBankYearStat: Decodable {
    var year: Int
}

/// Grupo de Q conforme lente (Tradicional/PBL/CNRM-Areas). Schema novo
/// adicionado em 2026-04-28 — `slug` + `name` + `count` é o mínimo.
/// `children` (2026-04-29) traz hierarquia 2-level:
///   - tradicional: filhos = topics (qbank_topics) com slug = topicId.toString()
///   - pbl: filhos = clusters de sintoma (pbl_symptom_clusters)
///   - great-areas: vazio (Onda 2)
struct QBankGroup: Identifiable, Hashable, Decodable {
    var slug: String
    var name: String
    var count: Int
    var icon: String?
    var displayOrder: Int?
    var children: [QBankGroupChild] = []

    var id: String { slug }

    private enum CodingKeys: String, CodingKey {
        case slug, name, count, icon, displayOrder, children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        icon = try? c.decode(String.self, forKey: .icon)
        displayOrder = try? c.decode(Int.self, forKey: .displayOrder)
        children = (try? c.decode([QBankGroupChild].self, forKey: .children)) ?? []
    }
}

struct QBankGroupChild: Identifiable, Hashable, Decodable {
    var slug: String
    var name: String
    var count: Int
    var parentSlug: String

    var id: String { "\(parentSlug)/\(slug)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        parentSlug = (try? c.decode(String.self, forKey: .parentSlug)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case slug, name, count, parentSlug
    }
}

// MARK: - QBank Preview (count dinâmico)

struct QBankPreviewBody: Encodable {
    // Taxonomia = 1 arvore (vita-shell §1.1): um campo por nivel, sem lente.
    /// Nivel 1 — as 6 grandes areas (`vita.exam_great_areas`).
    var areaSlugs: [String]?
    /// Nivel 2 — disciplina (`vita.disciplines.slug`).
    var disciplineSlugs: [String]?
    var institutionIds: [Int]?
    /// Nivel 3 — tema (`vita.qbank_topics`).
    var topicIds: [Int]?
    var years: QBankPreviewYears?
    var difficulties: [String]?
    var format: [String]?
    var hideAnswered: Bool?
    var hideAnnulled: Bool?
    var hideReviewed: Bool?
    var excludeNoExplanation: Bool?
    var includeSynthetic: Bool?
    /// `all` no Builder de Questões; nil herda o momento acadêmico do perfil.
    var stage: String?
}

struct QBankPreviewYears: Encodable {
    var min: Int?
    var max: Int?
}

struct QBankPreviewResp: Decodable {
    var total: Int = 0
    var byDifficulty: [String: Int] = [:]
    var facets: QBankPreviewFacets? = nil
    var appliedJourneyBoost: String? = nil

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        byDifficulty = (try? c.decode([String: Int].self, forKey: .byDifficulty)) ?? [:]
        facets = try? c.decode(QBankPreviewFacets.self, forKey: .facets)
        appliedJourneyBoost = try? c.decode(String.self, forKey: .appliedJourneyBoost)
    }

    private enum CodingKeys: String, CodingKey {
        case total, byDifficulty, facets, appliedJourneyBoost
    }
}

/// Facetas condicionais: cada mapa aplica todos os filtros, exceto sua própria família.
/// As opções estáticas de `/qbank/filters` continuam sendo a fonte dos rótulos.
struct QBankPreviewFacets: Codable, Hashable {
    var groups: [String: Int] = [:]
    var subgroups: [String: Int] = [:]
    var institutions: [String: Int] = [:]
    var years: [String: Int] = [:]
    var difficulties: [String: Int] = [:]
    var formats: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = (try? container.decode([String: Int].self, forKey: .groups)) ?? [:]
        subgroups = (try? container.decode([String: Int].self, forKey: .subgroups)) ?? [:]
        institutions = (try? container.decode([String: Int].self, forKey: .institutions)) ?? [:]
        years = (try? container.decode([String: Int].self, forKey: .years)) ?? [:]
        difficulties = (try? container.decode([String: Int].self, forKey: .difficulties)) ?? [:]
        formats = (try? container.decode([String: Int].self, forKey: .formats)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case groups, subgroups, institutions, years, difficulties, formats
    }
}

struct QBankDiscipline: Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var slug: String? = nil
    var parentId: Int? = nil
    var level: Int = 0
    var questionCount: Int = 0
    var children: [QBankDiscipline] = []
}

extension QBankDiscipline: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, name, slug, parentId, level, questionCount, children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try? c.decode(String.self, forKey: .slug)
        // Backend new payload sends {slug, name, ...} without `id`; derive a stable
        // per-session hash so Set<Int> and Identifiable still work.
        if let rawId = try? c.decode(Int.self, forKey: .id) {
            id = rawId
        } else if let s = slug {
            id = abs(s.hashValue)
        }
        // Backend uses `name`, legacy payload uses `title`. Accept either.
        title = (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? ""
        parentId = try? c.decode(Int.self, forKey: .parentId)
        level = (try? c.decode(Int.self, forKey: .level)) ?? 0
        questionCount = (try? c.decode(Int.self, forKey: .questionCount)) ?? 0
        children = (try? c.decode([QBankDiscipline].self, forKey: .children)) ?? []
    }
}

struct QBankInstitution: Identifiable, Hashable {
    var id: Int = 0
    var name: String = ""
    var slug: String = ""
    var state: String? = nil
    var isResidence: Bool = false
    var count: Int?
}

extension QBankInstitution: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, state, isResidence, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        state = try? c.decode(String.self, forKey: .state)
        isResidence = (try? c.decode(Bool.self, forKey: .isResidence)) ?? false
        count = try? c.decode(Int.self, forKey: .count)
    }
}

struct QBankTopic: Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var disciplineId: Int? = nil
    var disciplineSlug: String? = nil
    /// Self-ref pra hierarquia 4 níveis (ÁREA-DISCIPLINA-TEMA-CONTEÚDO).
    /// nil = root (ÁREA). Backend retorna desde 2026-04-26.
    var parentTopicId: Int? = nil
    var name: String?
    var disciplineName: String?
    var count: Int?
    var iconSlug: String?

    var displayTitle: String { name ?? (title.isEmpty ? "Tópico \(id)" : title) }
}

extension QBankTopic: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, disciplineId, disciplineSlug, parentTopicId, name, disciplineName, count, iconSlug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        disciplineId = try? c.decode(Int.self, forKey: .disciplineId)
        disciplineSlug = try? c.decode(String.self, forKey: .disciplineSlug)
        parentTopicId = try? c.decode(Int.self, forKey: .parentTopicId)
        name = try? c.decode(String.self, forKey: .name)
        disciplineName = try? c.decode(String.self, forKey: .disciplineName)
        count = try? c.decode(Int.self, forKey: .count)
        iconSlug = try? c.decode(String.self, forKey: .iconSlug)
    }
}

struct QBankDifficultyStat: Decodable, Identifiable {
    var difficulty: String = ""
    var label: String = ""
    var count: Int = 0
    var id: String { difficulty }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = (try? c.decode(String.self, forKey: .difficulty)) ?? ""
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case difficulty, label, count
    }

    /// Display label: use API-provided label if available, else localize the key
    var displayLabel: String {
        if !label.isEmpty { return label }
        return difficulty.difficultyLabel
    }
}

// MARK: - Questions List

struct QBankQuestionsResponse: Decodable {
    var questions: [QBankQuestionSummary] = []
    var pagination: QBankPagination = .init()
}

struct QBankQuestionSummary: Decodable, Identifiable {
    var id: Int = 0
    var statement: String = ""
    var difficulty: String = ""
    var year: Int? = nil
    var isResidence: Bool = false
    var isCancelled: Bool = false
    var institutionName: String? = nil
}

struct QBankPagination: Decodable {
    var page: Int = 1
    var limit: Int = 20
    var total: Int = 0
    var totalPages: Int = 0
}

// MARK: - Question Detail

struct QBankQuestionDetail: Identifiable {
    var id: Int = 0
    var statement: String = ""
    var explanation: String? = nil
    var difficulty: String = ""
    var year: Int? = nil
    var isResidence: Bool = false
    var isCancelled: Bool = false
    var isDiscursive: Bool = false
    var isOutdated: Bool = false
    var institutionName: String? = nil
    var alternatives: [QBankAlternative] = []
    var images: [QBankImage] = []
    var topics: [QBankTopic] = []
    var statistics: [QBankStatistic] = []
    var userAnswer: QBankUserAnswer? = nil
}

extension QBankQuestionDetail: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, statement, explanation, difficulty, year, isResidence, isCancelled
        case isDiscursive, isOutdated, institutionName, alternatives, images, topics
        case statistics, userAnswer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        statement = (try? c.decode(String.self, forKey: .statement)) ?? ""
        explanation = try? c.decode(String.self, forKey: .explanation)
        difficulty = (try? c.decode(String.self, forKey: .difficulty)) ?? ""
        year = try? c.decode(Int.self, forKey: .year)
        isResidence = (try? c.decode(Bool.self, forKey: .isResidence)) ?? false
        isCancelled = (try? c.decode(Bool.self, forKey: .isCancelled)) ?? false
        isDiscursive = (try? c.decode(Bool.self, forKey: .isDiscursive)) ?? false
        isOutdated = (try? c.decode(Bool.self, forKey: .isOutdated)) ?? false
        institutionName = try? c.decode(String.self, forKey: .institutionName)
        alternatives = (try? c.decode([QBankAlternative].self, forKey: .alternatives)) ?? []
        images = (try? c.decode([QBankImage].self, forKey: .images)) ?? []
        topics = (try? c.decode([QBankTopic].self, forKey: .topics)) ?? []
        statistics = (try? c.decode([QBankStatistic].self, forKey: .statistics)) ?? []
        userAnswer = try? c.decode(QBankUserAnswer.self, forKey: .userAnswer)
    }
}

struct QBankAlternative: Identifiable {
    var id: Int = 0
    var text: String = ""
    var isCorrect: Bool = false
    var sortOrder: Int = 0
}

extension QBankAlternative: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, text, description, isCorrect, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        // API returns "text", legacy model used "description"
        text = (try? c.decode(String.self, forKey: .text))
            ?? (try? c.decode(String.self, forKey: .description))
            ?? ""
        isCorrect = (try? c.decode(Bool.self, forKey: .isCorrect)) ?? false
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
    }
}

struct QBankImage: Identifiable {
    var id: Int = 0
    var imageUrl: String = ""
    var originalUrl: String? = nil
    var questionId: Int? = nil
    var alternativeId: Int? = nil
    var caption: String? = nil
    var filename: String? = nil
    var mimeType: String? = nil
}

extension QBankImage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, imageUrl, originalUrl, questionId, alternativeId, caption, filename, mimeType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        originalUrl = try? c.decode(String.self, forKey: .originalUrl)
        imageUrl = (try? c.decode(String.self, forKey: .imageUrl))
            ?? originalUrl
            ?? ""
        questionId = try? c.decode(Int.self, forKey: .questionId)
        alternativeId = try? c.decode(Int.self, forKey: .alternativeId)
        caption = try? c.decode(String.self, forKey: .caption)
        filename = try? c.decode(String.self, forKey: .filename)
        mimeType = try? c.decode(String.self, forKey: .mimeType)
    }
}

struct QBankStatistic: Decodable {
    var alternativeId: Int = 0
    var percentage: Double = 0
}

struct QBankUserAnswer: Decodable {
    var alternativeId: Int = 0
    var isCorrect: Bool = false
}

// MARK: - Answer

struct QBankAnswerRequest: Encodable {
    let alternativeId: Int
    let responseTimeMs: Int64?
    let sessionId: String?
}

struct QBankAnswerResponse: Decodable {
    var isCorrect: Bool = false
    var answerId: Int = 0
    var award: LogActivityResponse?
    var xpAwarded: Int = 0
    var totalXp: Int = 0
    var level: Int = 0
    var currentLevelXp: Int = 0
    var xpToNextLevel: Int = 0
    var newBadges: [NewBadge] = []
    var tier: String = ""
    var cycle: String = ""
    var iconPath: String = ""

    var activityResponse: LogActivityResponse? {
        if let award { return award }
        guard xpAwarded > 0 || totalXp > 0 else { return nil }
        return LogActivityResponse(
            xpAwarded: xpAwarded,
            totalXp: totalXp,
            level: level,
            currentLevelXp: currentLevelXp,
            xpToNextLevel: xpToNextLevel,
            newBadges: newBadges,
            tier: tier,
            cycle: cycle,
            iconPath: iconPath
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isCorrect, answerId, award, xpAwarded, totalXp, level, currentLevelXp, xpToNextLevel
        case newBadges, tier, cycle, iconPath
    }

    init(
        isCorrect: Bool = false,
        answerId: Int = 0,
        award: LogActivityResponse? = nil,
        xpAwarded: Int = 0,
        totalXp: Int = 0,
        level: Int = 0,
        currentLevelXp: Int = 0,
        xpToNextLevel: Int = 0,
        newBadges: [NewBadge] = [],
        tier: String = "",
        cycle: String = "",
        iconPath: String = ""
    ) {
        self.isCorrect = isCorrect
        self.answerId = answerId
        self.award = award
        self.xpAwarded = xpAwarded
        self.totalXp = totalXp
        self.level = level
        self.currentLevelXp = currentLevelXp
        self.xpToNextLevel = xpToNextLevel
        self.newBadges = newBadges
        self.tier = tier
        self.cycle = cycle
        self.iconPath = iconPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isCorrect = (try? c.decode(Bool.self, forKey: .isCorrect)) ?? false
        answerId = (try? c.decode(Int.self, forKey: .answerId)) ?? 0
        award = try? c.decode(LogActivityResponse.self, forKey: .award)
        xpAwarded = (try? c.decode(Int.self, forKey: .xpAwarded)) ?? 0
        totalXp = (try? c.decode(Int.self, forKey: .totalXp)) ?? 0
        level = (try? c.decode(Int.self, forKey: .level)) ?? 0
        currentLevelXp = (try? c.decode(Int.self, forKey: .currentLevelXp)) ?? 0
        xpToNextLevel = (try? c.decode(Int.self, forKey: .xpToNextLevel)) ?? 0
        newBadges = (try? c.decode([NewBadge].self, forKey: .newBadges)) ?? []
        tier = (try? c.decode(String.self, forKey: .tier)) ?? ""
        cycle = (try? c.decode(String.self, forKey: .cycle)) ?? ""
        iconPath = (try? c.decode(String.self, forKey: .iconPath)) ?? ""
    }
}

struct QBankFinishSessionResponse: Decodable {
    var correctCount: Int = 0
    var totalQuestions: Int = 0
    var score: Int = 0
    var byDiscipline: [QBankDisciplineBreakdown] = []
    var avgTimeMs: Int? = nil
    var award: LogActivityResponse?

    var activityResponse: LogActivityResponse? { award }

    enum CodingKeys: String, CodingKey {
        case correctCount, totalQuestions, score, byDiscipline, avgTimeMs, award
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        correctCount = (try? c.decode(Int.self, forKey: .correctCount)) ?? 0
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        byDiscipline = (try? c.decode([QBankDisciplineBreakdown].self, forKey: .byDiscipline)) ?? []
        avgTimeMs = try? c.decode(Int.self, forKey: .avgTimeMs)
        award = try? c.decode(LogActivityResponse.self, forKey: .award)
    }
}

/// Quebra de acertos por disciplina no resultado (backend #189 T1).
struct QBankDisciplineBreakdown: Decodable, Identifiable {
    var slug: String = ""
    var name: String = ""
    var total: Int = 0
    var correct: Int = 0
    var pct: Int = 0
    var id: String { slug }
}

// MARK: - Session

struct QBankCreateSessionRequest: Encodable {
    let questionCount: Int
    let institutionIds: [Int]?
    let years: [Int]?
    let difficulties: [String]?
    // Taxonomia = 1 arvore (vita-shell §1.1): AREA -> DISCIPLINA -> TEMA, um campo por
    // nivel, mesmos nomes de /api/qbank/preview. `lens`/`pblSystemSlugs`/`subgroupSlugs`
    // morreram em 2026-07-16 — o backend nao le mais (mandava-los era filtrar nada).
    /// Nivel 1 — as 6 grandes areas (`vita.exam_great_areas`).
    let areaSlugs: [String]?
    /// Nivel 2 — disciplina (`vita.disciplines.slug`).
    let disciplineSlugs: [String]?
    /// Nivel 3 — tema (`vita.qbank_topics`).
    let topicIds: [Int]?
    let disciplineIds: [Int]?
    let mode: String?
    let onlyResidence: Bool?
    let onlyUnanswered: Bool?
    let title: String?
    let stage: String?
    let status: String?
    /// Quality filter — drop questions com explanation NULL ou length<=50.
    /// Default true client-side (Rafael 2026-04-27): "questões boas têm gabarito".
    let excludeNoExplanation: Bool?
    /// Quality filter — when false, drop LLM-generated questions
    /// (isSynthetic=true, year>=2025, source=medsimple). Default true (only oficiais).
    let includeSynthetic: Bool?
    /// Spec §11.4 — Avançadas. Backend aceita os campos (placeholder no-op
    /// enquanto a table de revisão consolidada não existe). Enviar somente
    /// quando true; nil/false ⇒ campo omitido do JSON via `init` default.
    let hideAnnulled: Bool?
    let hideReviewed: Bool?
    /// Spec §3.1 — formato (objective/discursive/withImage). Multi-select.
    let format: [String]?
    /// "1 sessão aberta global": quando true, o backend encerra a sessão aberta
    /// existente (de qualquer tipo) antes de criar esta. nil ⇒ respeita o guard (409).
    let abandonExisting: Bool?

    init(
        questionCount: Int,
        institutionIds: [Int]? = nil,
        years: [Int]? = nil,
        difficulties: [String]? = nil,
        areaSlugs: [String]? = nil,
        disciplineSlugs: [String]? = nil,
        topicIds: [Int]? = nil,
        disciplineIds: [Int]? = nil,
        mode: String? = nil,
        onlyResidence: Bool? = nil,
        onlyUnanswered: Bool? = nil,
        title: String? = nil,
        stage: String? = nil,
        status: String? = nil,
        excludeNoExplanation: Bool? = nil,
        includeSynthetic: Bool? = nil,
        hideAnnulled: Bool? = nil,
        hideReviewed: Bool? = nil,
        format: [String]? = nil,
        abandonExisting: Bool? = nil
    ) {
        self.questionCount = questionCount
        self.institutionIds = institutionIds
        self.years = years
        self.difficulties = difficulties
        self.areaSlugs = areaSlugs
        self.disciplineSlugs = disciplineSlugs
        self.topicIds = topicIds
        self.disciplineIds = disciplineIds
        self.mode = mode
        self.onlyResidence = onlyResidence
        self.onlyUnanswered = onlyUnanswered
        self.title = title
        self.stage = stage
        self.status = status
        self.excludeNoExplanation = excludeNoExplanation
        self.includeSynthetic = includeSynthetic
        self.hideAnnulled = hideAnnulled
        self.hideReviewed = hideReviewed
        self.format = format
        self.abandonExisting = abandonExisting
    }
}

/// Corpo do 409 `open_session_exists` — "1 sessão aberta global". O create-route
/// devolve isso quando já há um treino aberto (de qualquer tipo). O app oferece
/// "encerrar e começar" (recria com abandonExisting) ou cancelar.
struct OpenSessionConflict: Decodable {
    let error: String
    let openSession: OpenSessionInfo
}

struct OpenSessionInfo: Decodable, Identifiable, Equatable {
    let type: String   // "questions" | "flashcards" | "simulado"
    let id: String
    let title: String?
    let currentIndex: Int
    let total: Int
    let startedAt: String?

    /// Rótulo PT-BR do tipo de treino aberto.
    var typeLabel: String {
        switch type {
        case "flashcards": return "Flashcards"
        case "simulado": return "Simulado"
        default: return "Questões"
        }
    }
}

struct QBankSession: Decodable, Identifiable {
    var id: String = ""
    var title: String? = nil
    var questionIds: [Int] = []
    var totalQuestions: Int = 0
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var createdAt: String? = nil
}

// MARK: - Progress

struct QBankProgressResponse: Decodable {
    // API returns accuracy as 0-100 (percentage). UI code expects 0.0-1.0 (fraction).
    var normalizedAccuracy: Double { accuracy > 1.0 ? accuracy / 100.0 : accuracy }
    var totalAvailable: Int = 0
    var totalAnswered: Int = 0
    var totalCorrect: Int = 0
    var accuracy: Double = 0
    var byDifficulty: [QBankProgressByDifficulty] = []
    var byTopic: [QBankProgressByTopic] = []
    /// Desempenho por ÁREA (6 grandes áreas) → disciplinas canônicas. A fonte
    /// goldstandard da seção "Onde melhorar" (via qbank_topics.disciplineSlug).
    var byArea: [QBankProgressByArea] = []
    /// "global" when totals reflect the whole catalogue (stage-scoped), "enrolled" when the
    /// request was filtered by `disciplineSlugs[]`. Added 2026-04-17b.
    var scope: String? = nil
    /// Echo of the slugs the server used to scope this response (empty for "global").
    var scopedSlugs: [String]? = nil
}

struct QBankProgressByArea: Decodable, Identifiable {
    var area: String = ""          // slug da grande área de prova (exam_great_areas)
    var areaName: String = ""      // nome pronto do catálogo (ex "Clínica Médica")
    var answered: Int = 0
    var accuracy: Int = 0          // 0-100, média da área
    var disciplines: [QBankProgressByDiscipline] = []
    var id: String { area }
}

struct QBankProgressByDiscipline: Decodable, Identifiable {
    var slug: String = ""
    var name: String = ""
    var answered: Int = 0
    var accuracy: Int = 0          // 0-100
    var id: String { slug }
}

struct QBankProgressByDifficulty: Decodable, Identifiable {
    var difficulty: String = ""
    var answered: Int = 0
    var correct: Int = 0
    var id: String { difficulty }

    var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 0
    }
}

struct QBankProgressByTopic: Decodable, Identifiable {
    var topicId: Int = 0
    var topicTitle: String = ""
    var answered: Int = 0
    var correct: Int = 0
    var id: Int { topicId }

    var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 0
    }
}

// MARK: - Sessions List

struct QBankSessionsResponse: Decodable {
    var sessions: [QBankSessionSummary] = []

    init() {}

    init(from decoder: Decoder) throws {
        // API may return bare array or {"sessions": [...]}
        if let c = try? decoder.container(keyedBy: CodingKeys.self) {
            sessions = (try? c.decode([QBankSessionSummary].self, forKey: .sessions)) ?? []
        } else if let arr = try? decoder.singleValueContainer().decode([QBankSessionSummary].self) {
            sessions = arr
        }
    }

    private enum CodingKeys: String, CodingKey { case sessions }
}

struct QBankSessionSummary: Decodable, Identifiable {
    var id: String = ""
    var title: String? = nil
    var totalQuestions: Int = 0
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var completedAt: String? = nil
    var createdAt: String = ""
    /// Display labels for the disciplines this session was scoped to.
    /// Used as a fallback when `title` is nil; also feeds the chips on the session card.
    var disciplineTitles: [String]? = nil

    var isActive: Bool { completedAt == nil }
}

// MARK: - Query Filters (ViewModel-side helper)

struct QBankQueryFilters {
    var institutionIds: [Int] = []
    var years: [Int] = []
    var difficulties: [String] = []
    var topicIds: [Int] = []
    var status: String? = nil      // "unanswered" | "correct" | "incorrect" | nil
    var onlyResidence: Bool = false
}
