import Foundation

// MIGRATION: Dashboard models migrated to OpenAPI generated types.
// Dashboard (generated) replaces DashboardResponse
// DashboardHeroCard, DashboardHeroCardAction, DashboardHeroCardPillsInner, DashboardSubject,
// DashboardAgendaItem, DashboardXp are all generated.
// DashboardExam, DashboardRecommendation have no generated equivalents — kept manual.

typealias DashboardResponse = Dashboard
typealias DashboardPill = DashboardHeroCardPillsInner
typealias DashboardAction = DashboardHeroCardAction
typealias DashboardXP = DashboardXp

// MARK: - Identifiable conformance for generated types

extension DashboardHeroCard: Identifiable {
    public var id: String { "\(type.rawValue)-\(title)" }
}

extension DashboardSubject: Identifiable {
    public var id: String { name ?? "" }
}

// MARK: - Legacy models (no generated equivalent)

struct DashboardExam: Decodable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var subject: String = ""
    var daysUntil: Int = 0
    var description: String?
    var conceptCards: Int = 0
    var practiceCards: Int = 0
}

struct DashboardRecommendation: Decodable {
    var title: String = ""
    var dueCount: Int = 0
    var deckId: String = ""
}
