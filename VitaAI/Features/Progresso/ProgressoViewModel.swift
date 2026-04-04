import SwiftUI

@MainActor
@Observable
final class ProgressoViewModel {
    private let api: VitaAPI

    // Loading / error
    var isLoading = true
    var error: String?

    // Stats
    var streakDays = 0
    var longestStreak = 0
    var totalStudyHours = 0.0
    var avgAccuracy = 0.0
    var totalQuestions = 0

    // Gamification
    var userProgress: UserProgress?

    // Weekly chart (hours per day Mon-Sun)
    var weeklyHours: [Double] = Array(repeating: 0, count: 7)
    var weeklyActualHours = 0.0
    var weeklyGoalHours = 0.0

    // Heatmap (91 days, levels 0-4)
    var heatmap: [Int] = []

    // Subjects for "onde melhorar"
    var subjects: [SubjectProgress] = []

    // Leaderboard
    var leaderboard: [LeaderboardEntry] = []

    var myLeaderboardEntry: LeaderboardEntry? {
        leaderboard.first(where: { $0.isMe })
    }

    init(api: VitaAPI) { self.api = api }

    func load() async {
        isLoading = true
        error = nil

        if AppConfig.isE2EDemoMode {
            let progress = MockData.progressResponse()
            let stats = MockData.gamificationStats()
            totalStudyHours = progress.totalStudyHours
            avgAccuracy = progress.avgAccuracy
            totalQuestions = progress.totalCards
            subjects = progress.subjects
            heatmap = progress.heatmap
            weeklyHours = progress.weeklyHours
            weeklyActualHours = progress.weeklyActualHours
            weeklyGoalHours = progress.weeklyGoalHours
            streakDays = stats.streakDays
            longestStreak = stats.streakDays
            userProgress = UserProgress(
                totalXp: stats.totalXp,
                level: stats.level,
                currentLevelXp: stats.currentLevelXp,
                xpToNextLevel: stats.xpToNextLevel,
                currentStreak: stats.streakDays,
                longestStreak: stats.streakDays,
                badges: stats.achievements.filter(\.earned).map {
                    VitaBadge(
                        id: $0.id,
                        name: $0.name,
                        description: $0.description,
                        icon: $0.icon,
                        earnedAt: $0.earnedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                        category: .milestone
                    )
                },
                dailyXp: 35
            )
            leaderboard = MockData.leaderboardEntries()
            isLoading = false
            return
        }

        var anySuccess = false

        // Load progress data (independent — partial success is OK)
        do {
            let progress = try await api.getProgress()
            totalStudyHours = progress.totalStudyHours
            avgAccuracy = progress.avgAccuracy
            totalQuestions = progress.totalAnswered
            subjects = progress.subjects
            heatmap = progress.heatmap
            weeklyHours = progress.weeklyHours
            weeklyActualHours = progress.weeklyActualHours
            weeklyGoalHours = progress.weeklyGoalHours
            streakDays = progress.streakDays
            anySuccess = true
        } catch {
            print("[PROGRESSO] getProgress failed: \(error)")
        }

        // Load XP/level from dashboard (gamification stats endpoint doesn't exist yet)
        do {
            let dashboard = try await api.getDashboard()
            let xp = dashboard.xp
            longestStreak = streakDays
            userProgress = UserProgress(
                totalXp: xp?.total ?? 0,
                level: xp?.level ?? 1,
                currentLevelXp: (xp?.total ?? 0) % 100,
                xpToNextLevel: 100,
                currentStreak: streakDays,
                longestStreak: streakDays,
                badges: [],
                dailyXp: 0
            )
            anySuccess = true
        } catch {
            print("[PROGRESSO] getDashboard (for XP) failed: \(error)")
        }

        // Load leaderboard
        do {
            leaderboard = try await api.getLeaderboard(period: "weekly", limit: 10)
            anySuccess = true
        } catch {
            print("[PROGRESSO] getLeaderboard failed: \(error)")
        }

        if !anySuccess {
            self.error = "Nao foi possivel carregar os dados de progresso."
        }
        isLoading = false
    }
}
