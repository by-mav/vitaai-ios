import Foundation

// MIGRATION: Progress/Flashcard models kept manual.
// Generated UserProgress has only 6 of 18 fields in ProgressResponse.
// Generated Grade, Exam, FlashcardStats, FlashcardDeck, Flashcard all lack significant fields.
// Manual types match actual API responses more closely than OpenAPI spec.

struct ProgressResponse: Codable {
    var streakDays: Int = 0
    var totalStudyHours: Double = 0.0
    var avgAccuracy: Double = 0.0
    var flashcardsDue: Int = 0
    var totalCards: Int = 0
    var learnedCards: Int = 0
    var totalAnswered: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayStudyMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var weekGrades: [GradeEntry] = []
    var upcomingExams: [ExamEntry] = []
    var heatmap: [Int] = []
    var weeklyHours: [Double] = Array(repeating: 0, count: 7)
    var weeklyGoalHours: Double = 0
    var weeklyActualHours: Double = 0
    var dailyStudyGoalMinutes: Int = 120

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        totalStudyHours = (try? c.decode(Double.self, forKey: .totalStudyHours)) ?? 0
        avgAccuracy = (try? c.decode(Double.self, forKey: .avgAccuracy)) ?? 0
        flashcardsDue = (try? c.decode(Int.self, forKey: .flashcardsDue)) ?? 0
        totalCards = (try? c.decode(Int.self, forKey: .totalCards)) ?? 0
        learnedCards = (try? c.decode(Int.self, forKey: .learnedCards)) ?? 0
        totalAnswered = (try? c.decode(Int.self, forKey: .totalAnswered)) ?? 0
        todayCompleted = (try? c.decode(Int.self, forKey: .todayCompleted)) ?? 0
        todayTotal = (try? c.decode(Int.self, forKey: .todayTotal)) ?? 0
        todayStudyMinutes = (try? c.decode(Int.self, forKey: .todayStudyMinutes)) ?? 0
        subjects = (try? c.decode([SubjectProgress].self, forKey: .subjects)) ?? []
        weekGrades = (try? c.decode([GradeEntry].self, forKey: .weekGrades)) ?? []
        upcomingExams = (try? c.decode([ExamEntry].self, forKey: .upcomingExams)) ?? []
        heatmap = (try? c.decode([Int].self, forKey: .heatmap)) ?? []
        weeklyHours = (try? c.decode([Double].self, forKey: .weeklyHours)) ?? Array(repeating: 0, count: 7)
        weeklyGoalHours = (try? c.decode(Double.self, forKey: .weeklyGoalHours)) ?? 0
        weeklyActualHours = (try? c.decode(Double.self, forKey: .weeklyActualHours)) ?? 0
        dailyStudyGoalMinutes = (try? c.decode(Int.self, forKey: .dailyStudyGoalMinutes)) ?? 120
    }
}

struct SubjectProgress: Codable {
    var subjectId: String = ""
    var name: String = ""
    var accuracy: Double = 0.0
    var hoursSpent: Double = 0.0
    var cardsDue: Int = 0
    var questionCount: Int = 0
}

struct GradeEntry: Codable, Identifiable {
    var id: String = ""
    var userId: String = ""
    var subjectId: String = ""
    var label: String = ""
    var value: Double = 0.0
    var maxValue: Double = 10.0
    var notes: String?
    var date: String?
}

struct ExamEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var subjectId: String?
    var subjectName: String?
    var examType: String?
    var date: String = ""
    var result: Double?
    var notes: String?
    var daysUntil: Int = 0
    var weight: Double?
    var pointsPossible: Double?
    var conceptCards: Int?
    var practiceCards: Int?
    var userId: String?
    var createdAt: String?
    var deletedAt: String?

    // Compat: display name from title or subjectName
    var displayName: String { title.isEmpty ? (subjectName ?? "Prova") : title }
}

struct ExamsResponse: Codable {
    var exams: [ExamEntry] = []
}

struct StudyEventsResponse: Codable {
    var events: [StudyEventEntry] = []
}

struct StudyEventEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var description: String?
    var eventType: String = ""
    var startAt: String = ""
    var endAt: String?
    var source: String?
    var courseName: String?
    var courseId: String?
}

// MARK: - Flashcard Stats API Response

struct FlashcardStatsResponse: Codable {
    var totalCards: Int = 0
    var newCards: Int = 0
    var youngCards: Int = 0
    var matureCards: Int = 0
    var totalReviews: Int = 0
    var retentionRate: Double = 0.0
    var streakDays: Int = 0
    var totalStudyMinutes: Int = 0
    var todayReviews: Int = 0
    var reviewsPerDay: [String: Int] = [:]
    var forecastNext7Days: [Int] = []
    var dailyRetention: [DailyRetentionEntry] = []

    init() {}
    // Decode TOLERANTE: o sintetizado do Swift lanca se o /stats omitir qualquer
    // campo -> zerava TUDO (heroi 0 mesmo com 5083 cards). Por-campo com try?
    // deixa totalCards/streakDays passar mesmo em resposta parcial. Rafael 2026-07-09.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalCards = (try? c.decode(Int.self, forKey: .totalCards)) ?? 0
        newCards = (try? c.decode(Int.self, forKey: .newCards)) ?? 0
        youngCards = (try? c.decode(Int.self, forKey: .youngCards)) ?? 0
        matureCards = (try? c.decode(Int.self, forKey: .matureCards)) ?? 0
        totalReviews = (try? c.decode(Int.self, forKey: .totalReviews)) ?? 0
        retentionRate = (try? c.decode(Double.self, forKey: .retentionRate)) ?? 0
        streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        totalStudyMinutes = (try? c.decode(Int.self, forKey: .totalStudyMinutes)) ?? 0
        todayReviews = (try? c.decode(Int.self, forKey: .todayReviews)) ?? 0
        reviewsPerDay = (try? c.decode([String: Int].self, forKey: .reviewsPerDay)) ?? [:]
        forecastNext7Days = (try? c.decode([Int].self, forKey: .forecastNext7Days)) ?? []
        dailyRetention = (try? c.decode([DailyRetentionEntry].self, forKey: .dailyRetention)) ?? []
    }
}

struct DailyRetentionEntry: Codable, Identifiable {
    var date: String = ""
    var count: Int = 0
    var retention: Double = 0.0
    var id: String { date }
}

struct FlashcardDeckEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var subjectId: String?
    var disciplineId: String?
    /// Canonical discipline slug (e.g. "farmacologia", "cardiologia"). Preferred
    /// over subjectId for matching with the user's enrolled disciplines, because
    /// most decks created by auto-seed have subjectId=null and only disciplineSlug.
    var disciplineSlug: String?
    var userId: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?
    var cards: [FlashcardEntry] = []
    var totalCards: Int?
    var dueCount: Int?

    /// Real card count — uses server-side totalCards when available, falls back to cards array length.
    var cardCount: Int { totalCards ?? cards.count }
}

// MARK: - Biblioteca Vita pela arvore canonica (GET /api/study/flashcards/library)
//
// O deck da Biblioteca eh um ACERVO ("Medicina" = 6.391 cards de Reumato, Nefro,
// Cardio, Dermato...). Aqui ele vem quebrado na taxonomia (vita-shell §1.1):
// AREA → DISCIPLINA, com a contagem real de cada uma.

struct FlashcardLibraryResponse: Decodable {
    var areas: [FlashcardLibraryArea] = []
    var totalCards: Int = 0
    var totalDue: Int = 0
}

struct FlashcardLibraryArea: Decodable, Identifiable {
    var slug: String = ""
    var name: String = ""
    /// Cards da area inteira (soma das disciplinas).
    var total: Int = 0
    /// Vencidos (state != NEW e nextReviewAt <= agora).
    var due: Int = 0
    var disciplines: [FlashcardLibraryDiscipline] = []

    var id: String { slug }
}

struct FlashcardLibraryDiscipline: Decodable, Identifiable {
    /// `vita.disciplines.slug` — o mesmo que questoes e simulados filtram.
    var slug: String = ""
    var name: String = ""
    var total: Int = 0
    var due: Int = 0

    var id: String { slug }
}

struct FlashcardEntry: Codable, Identifiable {
    var id: String = ""
    var front: String = ""
    var back: String = ""
    /// Grupo de lacuna deste card (o N de {{cN::}}). Ausente = card comum.
    var clozeOrd: Int?
    var nextReviewAt: String?
    var lastReviewAt: String?
    var stability: Double?
    var difficulty: Double?
    var reps: Int = 0
    var lapses: Int = 0
    var state: String?
    var scheduledDays: Int?
    var tag: String?
    var deckId: String?
    var disciplineId: FlexString?
    var topicId: Int?
    var language: String?
    var sourceQuestionId: FlexString?
    var sourceNid: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?

    // Backwards compat
    var repetitions: Int { reps }
    var easeFactor: Double { difficulty ?? 2.5 }
    var interval: Int { scheduledDays ?? 0 }
}

/// Decodes both String and Int JSON values into a String
struct FlexString: Codable, Hashable {
    let value: String
    init(_ value: String) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(Int(d)) }
        else { value = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

struct FlashcardTopic: Decodable, Identifiable {
    var name: String = ""
    var totalCards: Int = 0
    var dueCount: Int = 0
    var tags: [String] = []
    var id: String { name }
}

struct FlashcardRecommended: Decodable, Identifiable {
    var id: String { deckId }
    var title: String = ""
    var dueCount: Int = 0
    var totalCards: Int = 0
    var deckId: String = ""
}


// MARK: - Prova (avaliacao academica agendada pelo aluno) — /api/study/provas
struct Prova: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var title: String
    var subjectId: String?
    var date: String
    var notes: String?
    var createdAt: String?
}

struct CreateProvaRequest: Encodable {
    let title: String
    let subjectId: String?
    let date: String
    let notes: String?
}


struct UpdateProvaRequest: Encodable {
    let title: String?
    let date: String?
    let type: String?
}


// MARK: - Aula da grade semanal — /api/study/aulas
struct Aula: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var subjectId: String
    var dayOfWeek: Int          // 1=segunda ... 7=domingo (mesma convencao da agenda)
    var startTime: String       // "08:00"
    var endTime: String         // "09:40"
    var room: String?
    var professor: String?
}

/// Serve criar e editar: no PATCH todo campo e opcional.
struct AulaRequest: Encodable {
    let subjectId: String?
    let dayOfWeek: Int?
    let startTime: String?
    let endTime: String?
    let room: String?
    let professor: String?
}
