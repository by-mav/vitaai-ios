import Foundation
import SwiftUI

// MARK: - DisciplineDetailViewModel
// All data from API. Parallel loading via async let.
// Uses /grades/current as primary source for grades/attendance.

@MainActor
@Observable
final class DisciplineDetailViewModel {
    private let api: VitaAPI
    let disciplineId: String
    let disciplineName: String

    // MARK: - State

    private(set) var isLoading = true
    private(set) var error: String?

    private(set) var subjectProgress: SubjectProgress?
    private(set) var gradeSubject: GradeSubject?
    private(set) var exams: [ExamEntry] = []
    private(set) var flashcardDecks: [FlashcardDeckEntry] = []
    private(set) var documents: [VitaDocument] = []
    private(set) var classSchedule: [AgendaClassBlock] = []

    // MARK: - Init

    init(api: VitaAPI, disciplineId: String, disciplineName: String) {
        self.api = api
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
    }

    // MARK: - Computed: identity

    var subjectColor: Color {
        SubjectColors.colorFor(subject: disciplineName)
    }

    // MARK: - Computed: exams

    var subjectExams: [ExamEntry] {
        exams
            .filter { matchesDiscipline($0.subjectName) || matchesDiscipline($0.title) }
            .sorted { $0.date < $1.date }
    }

    var nextExam: ExamEntry? {
        subjectExams.first { $0.daysUntil >= 0 }
    }

    var pastExams: [ExamEntry] {
        subjectExams.filter { $0.daysUntil < 0 || $0.result != nil }
    }

    // MARK: - Computed: grades (from /grades/current — canonical source)
    // Weights come from API (backend returns weight1/weight2/weight3 from portal config)

    var grade1: Double? { gradeSubject?.grade1 }
    var grade2: Double? { gradeSubject?.grade2 }
    var grade3: Double? { gradeSubject?.grade3 }
    var finalGrade: Double? { gradeSubject?.finalGrade }
    var attendance: Int? { gradeSubject?.attendance }
    var absences: Int? { gradeSubject?.absences }
    var workload: Int? { gradeSubject?.workload }
    var subjectStatus: String? { gradeSubject?.status }

    var weight1: Double { gradeSubject?.weight1 ?? 2 }
    var weight2: Double { gradeSubject?.weight2 ?? 3 }
    var weight3: Double { gradeSubject?.weight3 ?? 5 }

    /// Normalizes a raw grade to 0-10 scale given its weight
    static func normalized(_ value: Double, weight: Double) -> Double {
        guard weight > 0 else { return 0 }
        return (value / weight) * 10.0
    }

    /// Grade slots with their weights for display: (value, weight, normalized)
    var gradeSlots: [(label: String, value: Double?, weight: Double)] {
        return [
            ("P1", grade1, weight1),
            ("P2", grade2, weight2),
            ("P3", grade3, weight3),
        ]
    }

    var hasAnyGrade: Bool {
        grade1 != nil || grade2 != nil || grade3 != nil || finalGrade != nil || attendance != nil
    }

    var hasGradeRisk: Bool {
        for slot in gradeSlots {
            guard let v = slot.value else { continue }
            if Self.normalized(v, weight: slot.weight) < 5.0 { return true }
        }
        return false
    }

    /// Weighted average on 0-10 scale
    var currentAverage: Double? {
        var totalScore = 0.0
        var totalWeight = 0.0
        for slot in gradeSlots {
            guard let v = slot.value else { continue }
            totalScore += v
            totalWeight += slot.weight
        }
        guard totalWeight > 0 else { return nil }
        return (totalScore / totalWeight) * 10.0
    }

    // MARK: - Computed: flashcards

    var subjectDecks: [FlashcardDeckEntry] {
        flashcardDecks.filter { deck in
            if let sid = deck.subjectId, sid == disciplineId { return true }
            return matchesDiscipline(deck.title)
        }
    }

    var flashcardsDue: Int {
        subjectDecks.reduce(0) { total, deck in
            let due = deck.cards.filter { card in
                guard let next = card.nextReviewAt,
                      let date = ISO8601DateFormatter().date(from: next) else {
                    return card.reps == 0
                }
                return date <= Date()
            }.count
            return total + due
        }
    }

    var flashcardsTotal: Int {
        subjectDecks.reduce(0) { $0 + $1.cards.count }
    }

    // MARK: - Computed: documents

    var subjectDocuments: [VitaDocument] {
        guard !documents.isEmpty else { return [] }
        return documents.filter { doc in
            if let sid = doc.subjectId, sid == disciplineId { return true }
            return matchesDiscipline(doc.title)
        }
    }

    // MARK: - Computed: schedule & professor

    var subjectSchedule: [AgendaClassBlock] {
        classSchedule
            .filter { matchesDiscipline($0.subjectName) }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    var professorName: String? {
        subjectSchedule.compactMap(\.professor).first { !$0.isEmpty }
    }

    var room: String? {
        subjectSchedule.compactMap(\.room).first { !$0.isEmpty }
    }

    // MARK: - Computed: VitaScore (0-100)
    // 45% difficulty (1 - accuracy), 35% gradeRisk, 20% urgency

    var vitaScore: Int {
        let accuracy = subjectProgress?.accuracy ?? 0.5
        let diffScore = (1.0 - accuracy) * 45.0

        let slotsWithValue = gradeSlots.filter { $0.value != nil }
        let gradeRisk: Double
        if slotsWithValue.isEmpty {
            gradeRisk = 0
        } else {
            let below = slotsWithValue.filter { Self.normalized($0.value!, weight: $0.weight) < 5.0 }.count
            gradeRisk = Double(below) / Double(slotsWithValue.count) * 35.0
        }

        let urgency: Double
        if let days = nextExam?.daysUntil {
            if days <= 3 { urgency = 20.0 }
            else if days <= 7 { urgency = 14.0 }
            else if days <= 14 { urgency = 7.0 }
            else { urgency = 2.0 }
        } else {
            urgency = 0
        }

        return min(100, Int(diffScore + gradeRisk + urgency))
    }

    // MARK: - Load (each call independent — one failure doesn't block others)

    func load() async {
        isLoading = true
        error = nil

        async let progressTask: ProgressResponse? = try? api.getProgress()
        async let gradesTask: GradesCurrentResponse? = try? api.getGradesCurrent()
        async let examsTask: ExamsResponse? = try? api.getExams()
        async let decksTask: [FlashcardDeckEntry]? = try? api.getFlashcardDecks()
        async let docsTask: [VitaDocument]? = try? api.getDocuments(subjectId: nil)
        async let agendaTask: AgendaResponse? = try? api.getAgenda()

        let (progressResponse, gradesResponse, examsResponse, decks, docs, agenda) = await (
            progressTask,
            gradesTask,
            examsTask,
            decksTask,
            docsTask,
            agendaTask
        )

        if let progressResponse {
            subjectProgress = progressResponse.subjects.first {
                matchesDiscipline($0.name) || matchesDiscipline($0.subjectId)
            }
        }

        if let gradesResponse {
            gradeSubject = gradesResponse.current.first { matchesDiscipline($0.subjectName) }
                ?? gradesResponse.completed.first { matchesDiscipline($0.subjectName) }
        }

        if let examsResponse {
            exams = examsResponse.exams
        }

        flashcardDecks = decks ?? []
        documents = docs ?? []
        classSchedule = agenda?.schedule ?? []

        isLoading = false
    }

    // MARK: - Helper

    private func matchesDiscipline(_ candidate: String?) -> Bool {
        guard let candidate, !candidate.isEmpty else { return false }
        let a = disciplineName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let b = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return a == b || b.contains(a) || a.contains(b)
    }
}
