import Foundation

struct DashboardResponse: Decodable {
    var greeting: String = ""
    var subtitle: String = ""
    var exams: [DashboardExam] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var studyRecommendations: [DashboardRecommendation] = []
    var xp: DashboardXP?
    var todayReviewed: Int = 0
}

struct DashboardExam: Decodable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var subject: String = ""
    var daysUntil: Int = 0
    var description: String?
    var conceptCards: Int = 0
    var practiceCards: Int = 0
}

struct DashboardSubject: Decodable, Identifiable {
    // API returns: name, shortName, difficulty, vitaScore, vitaTier (no id)
    var name: String = ""
    var shortName: String?
    var difficulty: String?
    var vitaScore: Double?
    var vitaTier: String?

    var id: String { name }
}

struct DashboardAgendaItem: Decodable {
    var type: String = ""
    var title: String = ""
    var daysUntil: Int = 0
    var date: String = ""
}

struct DashboardRecommendation: Decodable {
    // API returns: title, dueCount, deckId
    var title: String = ""
    var dueCount: Int = 0
    var deckId: String = ""
}

struct DashboardXP: Decodable {
    // API returns: {total: 55, level: 1}
    var total: Int = 0
    var level: Int = 0
}
