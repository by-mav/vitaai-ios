import Foundation

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
}

struct SubjectProgress: Codable {
    var subjectId: String = ""
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
    var userId: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?
    var cards: [FlashcardEntry] = []
}

struct FlashcardEntry: Codable, Identifiable {
    // Fields from the REAL API (/api/mockup/flashcards)
    var id: String = ""
    var front: String = ""
    var back: String = ""
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
    var disciplineId: String?
    var sourceQuestionId: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?

    // Backwards compat
    var repetitions: Int { reps }
    var easeFactor: Double { difficulty ?? 2.5 }
    var interval: Int { scheduledDays ?? 0 }
}

struct FlashcardRecommended: Decodable, Identifiable {
    var id: String { deckId }
    var title: String = ""
    var dueCount: Int = 0
    var totalCards: Int = 0
    var deckId: String = ""
}
