import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private let api: VitaAPI
    private weak var dataManager: AppDataManager?

    // Data from unified /api/mockup/dashboard endpoint
    var greeting: String = ""
    var subtitle: String = ""
    var upcomingExams: [UpcomingExam] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var xpLevel: Int = 1
    var streakDays: Int = 0
    var totalStudyHours: Double = 0
    var heroCards: [DashboardHeroCard] = []
    var isLoading = true
    var error: String?

    /// Stale-while-revalidate cache: keep last-load timestamp. If the view
    /// reappears within TTL, render the stale data immediately (isLoading=false)
    /// and refresh in background. Feels instant when user bounces between tabs.
    private var lastLoadedAt: Date?
    private static let cacheTTL: TimeInterval = 60  // seconds — aggressive refresh

    init(api: VitaAPI, dataManager: AppDataManager? = nil) {
        self.api = api
        self.dataManager = dataManager
    }

    func loadDashboard() async {
        // Cache hit: already have data and it is fresh. Render instantly,
        // refresh silently in background.
        if let last = lastLoadedAt, !heroCards.isEmpty,
           Date().timeIntervalSince(last) < Self.cacheTTL {
            isLoading = false
            Task { [weak self] in await self?.fetchAndApply(silent: true) }
            return
        }
        // Cold start or stale beyond TTL — full refresh with spinner.
        await fetchAndApply(silent: false)
    }

    /// Pull-to-refresh: force fetch even if cache is warm.
    func refresh() async {
        await fetchAndApply(silent: false)
    }

    private func fetchAndApply(silent: Bool) async {
        if !silent { isLoading = true }
        error = nil

        async let dashTask: DashboardResponse? = try? api.getDashboard()
        async let progressTask: ProgressResponse? = try? api.getProgress()
        let (dashResp, progressResp) = await (dashTask, progressTask)

        if let resp = dashResp {
            NSLog("[Dashboard] loaded hero=\(resp.hero?.count ?? 0) subjects=\(resp.subjects?.count ?? 0)")
            apply(dashboard: resp)
            lastLoadedAt = Date()
        } else if !silent {
            NSLog("[Dashboard] getDashboard FAILED")
        }

        if let progress = progressResp {
            apply(progress: progress, preserveExistingSubjects: true)
        }

        if subjects.isEmpty && upcomingExams.isEmpty && greeting.isEmpty {
            self.error = "Não foi possível carregar o dashboard."
        }

        if !silent { isLoading = false }
    }

    private func apply(dashboard: DashboardResponse) {
        greeting = dashboard.greeting ?? ""
        subtitle = dashboard.subtitle ?? ""
        if let fc = dashboard.flashcardsDueTotal, fc > 0 { flashcardsDueTotal = fc }
        if let xp = dashboard.xp, let lvl = xp.level { xpLevel = lvl }
        if let subs = dashboard.subjects, !subs.isEmpty {
            subjects = subs.sorted { ($0.vitaScore ?? 0) > ($1.vitaScore ?? 0) }
            dataManager?.dashboardSubjects = subjects
        }
        if let ag = dashboard.agenda, !ag.isEmpty { agenda = ag }
        // Store server-driven hero cards directly (sorted by urgency from backend)
        if let hero = dashboard.hero, !hero.isEmpty {
            heroCards = hero
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
        streakDays = progress.streakDays
        totalStudyHours = progress.totalStudyHours
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
