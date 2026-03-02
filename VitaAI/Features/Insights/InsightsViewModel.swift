import Foundation
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    private let api: VitaAPI

    // MARK: - Study progress stats (from /progress)
    var streakDays: Int = 0
    var avgAccuracy: Double = 0
    var totalHours: Double = 0
    var totalCards: Int = 0
    var flashcardsDue: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var upcomingExams: [ExamEntry] = []

    // MARK: - Grades data (from /grades + /canvas/courses + /webaluno/grades)
    var studyStats: StudyStats? = nil
    var courseGrades: [CourseGrade] = []
    var webalunoGrades: [WebalunoGrade] = []
    var webalunoSummary: WebalunoGradesSummary? = nil
    var webalunoConnected: Bool = false

    // MARK: - UI state
    var isLoading: Bool = true
    var error: String? = nil

    // MARK: - Computed

    /// Best available average: WebAluno average if present, else avgAccuracy from progress
    var displayAverage: Double {
        webalunoSummary?.averageGrade ?? avgAccuracy
    }

    var isEmptyState: Bool {
        !isLoading && error == nil && studyStats == nil && courseGrades.isEmpty && webalunoGrades.isEmpty
    }

    var isErrorState: Bool {
        !isLoading && error != nil && studyStats == nil
    }

    init(api: VitaAPI) { self.api = api }

    // MARK: - Load

    func load() async {
        // Reset stagger animations by clearing studyStats before loading
        studyStats = nil
        isLoading = true
        error = nil

        // Load mock immediately so skeleton → data feels snappy
        loadMock()

        do {
            // Fire all requests concurrently
            async let progressTask = api.getProgress()
            async let gradesTask: [GradeEntry] = api.getGrades(limit: 100)
            async let coursesTask = api.getCourses()
            async let webalunoTask = tryFetchWebalunoGrades()

            let (progress, grades, coursesResp, webalunoResp) = try await (
                progressTask, gradesTask, coursesTask, webalunoTask
            )

            // Update progress stats
            streakDays = progress.streakDays
            avgAccuracy = progress.avgAccuracy
            totalHours = progress.totalStudyHours
            totalCards = progress.totalCards
            flashcardsDue = progress.flashcardsDue
            todayCompleted = progress.todayCompleted
            todayTotal = progress.todayTotal
            todayMinutes = progress.todayStudyMinutes
            subjects = progress.subjects
            upcomingExams = progress.upcomingExams

            // Build StudyStats for overview card
            studyStats = StudyStats(
                totalHoursThisWeek: progress.totalStudyHours,
                averageGrade: progress.avgAccuracy,
                completedAssignments: progress.todayCompleted,
                pendingAssignments: progress.todayTotal - progress.todayCompleted,
                streak: progress.streakDays
            )

            // Build CourseGrades from Canvas courses + grade entries
            let gradesBySubject = Dictionary(grouping: grades, by: \.subjectId)
            courseGrades = coursesResp.courses.map { course in
                let subjectGrades = gradesBySubject[course.id] ?? []
                let avgGrade: Double
                if subjectGrades.isEmpty {
                    avgGrade = 0.0
                } else {
                    avgGrade = subjectGrades.reduce(0.0) { $0 + $1.value } / Double(subjectGrades.count)
                }
                return CourseGrade(
                    id: course.id,
                    courseName: course.name,
                    grade: avgGrade,
                    assignments: course.assignmentsCount,
                    completed: subjectGrades.count
                )
            }

            // WebAluno grades
            webalunoGrades = webalunoResp?.grades ?? []
            webalunoSummary = webalunoResp?.summary
            webalunoConnected = webalunoResp != nil

        } catch {
            self.error = error.localizedDescription
            // Keep mock data so screen isn't blank if we had it
        }

        isLoading = false
    }

    /// Fetches WebAluno grades, returning nil on error (WebAluno is optional / may not be connected).
    private func tryFetchWebalunoGrades() async -> WebalunoGradesResponse? {
        do { return try await api.getWebalunoGrades() } catch { return nil }
    }

    // MARK: - Mock data (shown during initial load)

    private func loadMock() {
        streakDays = 7
        avgAccuracy = 72.0
        totalHours = 48.5
        totalCards = 234
        flashcardsDue = 12
        todayCompleted = 3
        todayTotal = 5
        todayMinutes = 95
        subjects = [
            SubjectProgress(subjectId: "cm-cardio", accuracy: 78.0, hoursSpent: 12.5, cardsDue: 3),
            SubjectProgress(subjectId: "cm-pneumo", accuracy: 65.0, hoursSpent: 8.0, cardsDue: 5),
            SubjectProgress(subjectId: "cm-gastro", accuracy: 82.0, hoursSpent: 10.0, cardsDue: 1),
            SubjectProgress(subjectId: "cir-geral", accuracy: 55.0, hoursSpent: 6.0, cardsDue: 8),
            SubjectProgress(subjectId: "ped-geral", accuracy: 70.0, hoursSpent: 5.0, cardsDue: 2),
        ]
        upcomingExams = [
            ExamEntry(id: "e1", subjectName: "Cardiologia", examType: "Prova", date: "2025-02-15", daysUntil: 12),
            ExamEntry(id: "e2", subjectName: "Internato", examType: "OSCE", date: "2025-02-28", daysUntil: 25),
        ]
        // studyStats is left nil — the skeleton shows until real data arrives
    }

    // MARK: - Helpers

    func accuracyColor(for accuracy: Double) -> Color {
        if accuracy >= 70 { return VitaColors.dataGreen }
        if accuracy >= 50 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    func subjectName(for id: String) -> String {
        let names: [String: String] = [
            "cm-cardio": "Cardiologia",
            "cm-pneumo": "Pneumologia",
            "cm-gastro": "Gastroenterologia",
            "cm-nefro": "Nefrologia",
            "cm-endocrino": "Endocrinologia",
            "cm-reumato": "Reumatologia",
            "cm-hemato": "Hematologia",
            "cm-infecto": "Infectologia",
            "cm-neuro": "Neurologia",
            "cir-geral": "Cirurgia Geral",
            "cir-trauma": "Cirurgia do Trauma",
            "ped-geral": "Pediatria",
            "go-obstetricia": "Obstetrícia",
            "go-ginecologia": "Ginecologia",
            "prev-epidemio": "Epidemiologia",
            "prev-bioestat": "Bioestatística",
        ]
        return names[id] ?? id
    }
}
