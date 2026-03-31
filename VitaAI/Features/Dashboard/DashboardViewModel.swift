import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private let api: VitaAPI

    // Data from unified /api/mockup/dashboard endpoint
    var greeting: String = ""
    var subtitle: String = ""
    var upcomingExams: [UpcomingExam] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var xpLevel: Int = 1
    var isLoading = true
    var error: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        // Load dashboard (greeting, exams, subjects, agenda)
        do {
            let resp = try await api.getDashboard()
            apply(dashboard: resp)
        } catch {
            // Silently continue — progress may still work
        }

        // Load progress data (subjects, exams, flashcards)
        do {
            let progress = try await api.getProgress()
            apply(progress: progress, preserveExistingSubjects: true)
        } catch {
            // Silently continue — dashboard data may be enough
        }

        if subjects.isEmpty && upcomingExams.isEmpty && greeting.isEmpty {
            self.error = "Nao foi possivel carregar o dashboard."
        }

        isLoading = false
    }

    private func apply(dashboard: DashboardResponse) {
        greeting = dashboard.greeting
        subtitle = dashboard.subtitle
        if dashboard.flashcardsDueTotal > 0 { flashcardsDueTotal = dashboard.flashcardsDueTotal }
        if let xp = dashboard.xp { xpLevel = xp.level }
        if !dashboard.subjects.isEmpty { subjects = dashboard.subjects }
        if !dashboard.agenda.isEmpty { agenda = dashboard.agenda }
        if !dashboard.exams.isEmpty {
            upcomingExams = dashboard.exams.map { exam in
                UpcomingExam(
                    id: exam.id,
                    subject: exam.subject,
                    type: exam.title,
                    date: Date().addingTimeInterval(TimeInterval(exam.daysUntil * 86400)),
                    daysUntil: exam.daysUntil,
                    conceptCards: exam.conceptCards,
                    practiceCards: exam.practiceCards
                )
            }
        }
    }

    private func apply(progress: ProgressResponse, preserveExistingSubjects: Bool) {
        if !progress.subjects.isEmpty && (!preserveExistingSubjects || subjects.isEmpty) {
            subjects = progress.subjects.map { sp in
                DashboardSubject(name: sp.subjectId)
            }
        }
        if progress.flashcardsDue > 0 {
            flashcardsDueTotal = progress.flashcardsDue
        }
        if !progress.upcomingExams.isEmpty && upcomingExams.isEmpty {
            upcomingExams = progress.upcomingExams.map { exam in
                UpcomingExam(
                    id: exam.id,
                    subject: exam.subjectName ?? exam.subjectId ?? "",
                    type: exam.title,
                    date: Date().addingTimeInterval(TimeInterval(exam.daysUntil * 86400)),
                    daysUntil: exam.daysUntil,
                    conceptCards: exam.conceptCards ?? 0,
                    practiceCards: exam.practiceCards ?? 0
                )
            }
        }
    }
}
