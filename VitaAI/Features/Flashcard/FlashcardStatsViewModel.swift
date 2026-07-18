import Foundation
import Observation

// MARK: - FlashcardStatsViewModel

@Observable
@MainActor
final class FlashcardStatsViewModel {

    // MARK: Loading
    private(set) var isLoading = true

    // MARK: Card counts
    private(set) var totalCards = 0
    private(set) var newCards = 0
    private(set) var youngCards = 0
    private(set) var matureCards = 0

    // MARK: Performance stats
    private(set) var retentionRate: Double = 0
    private(set) var streakDays = 0
    private(set) var totalStudyMinutes = 0
    private(set) var totalReviews = 0
    private(set) var todayReviews = 0

    // MARK: Chart data
    private(set) var reviewsPerDay: [String: Int] = [:]
    private(set) var forecastNext7Days: [Int] = Array(repeating: 0, count: 7)
    private(set) var dailyRetention: [DailyRetentionEntry] = []

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func load() async {
        isLoading = true

        // Parallel: deck cards + progress aggregate
        async let decksTask = api.getFlashcardDecks(dueOnly: false)
        async let progressTask = api.getProgress()

        do {
            let (decks, progress) = try await (decksTask, progressTask)
            computeLocally(decks: decks, progress: progress)
        } catch {
            // Partial failure — leave defaults
        }

        // Optionally enrich with server-side review history
        if let stats = try? await api.getFlashcardStats() {
            enrichFromServer(stats)
        }

        // Dobra com o estudo OFFLINE da Biblioteca (o servidor não a conhece — era
        // por isso que dava "0 em tudo" mesmo com 5801 cards e estudo local).
        let bundleTotal = await VitaContentBundle.shared.totalCards()
        let local = await LocalFlashcardStore.shared.aggregate()
        foldInOffline(bundleTotal: bundleTotal, local: local)

        isLoading = false
    }

    /// Soma a Biblioteca curada (bundle, offline) + o estudo FSRS local ao que veio
    /// do servidor. Rafael 2026-07-18 — a tela lia só o servidor e zerava.
    private func foldInOffline(bundleTotal: Int, local: LocalFlashcardStore.Aggregate) {
        guard bundleTotal > 0 else { return }
        // Cards
        totalCards += bundleTotal
        matureCards += local.matureCards
        youngCards += local.youngCards
        newCards += max(bundleTotal - local.cardsStudied, 0)
        // Reviews / hoje / sequência
        totalReviews += local.totalReviews
        todayReviews += local.todayReviews
        streakDays = max(streakDays, local.streakDays)
        // Retenção do estudo local = (reviews - erros) / reviews
        if local.totalReviews > 0 {
            let localRetention = Double(local.totalReviews - local.lapses) / Double(local.totalReviews) * 100
            retentionRate = retentionRate > 0 ? (retentionRate + localRetention) / 2 : localRetention
        }
        // Heatmap
        for (day, count) in local.reviewsPerDay {
            reviewsPerDay[day, default: 0] += count
        }
    }

    // MARK: - Local computation from deck entries

    private func computeLocally(decks: [FlashcardDeckEntry], progress: ProgressResponse) {
        // Só os decks PRÓPRIOS do usuário (userId preenchido). A Biblioteca curada
        // (userId vazio) é offline — entra pelo `foldInOffline`, senão contaria em
        // dobro (bundle + servidor).
        let allCards = decks.filter { !($0.userId ?? "").isEmpty }.flatMap { $0.cards }

        var newCount = 0
        var youngCount = 0
        var matureCount = 0
        var forecastCounts = Array(repeating: 0, count: 7)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let isoParser = ISO8601DateFormatter()

        for card in allCards {
            // Maturidade pelo classificador CANÔNICO (mesma regra do estudo local).
            switch CardMaturity.classify(reps: card.repetitions, intervalDays: card.interval) {
            case .new:    newCount += 1
            case .young:  youngCount += 1
            case .mature: matureCount += 1
            }

            // 7-day review forecast from nextReviewAt
            guard let nextStr = card.nextReviewAt,
                  let nextDate = isoParser.date(from: nextStr) else { continue }

            let nextDay = calendar.startOfDay(for: nextDate)
            for offset in 0..<7 {
                guard let target = calendar.date(byAdding: .day, value: offset, to: todayStart) else { continue }
                if nextDay == target {
                    forecastCounts[offset] += 1
                    break
                }
            }
            // Cards already overdue count toward today
            if nextDay < todayStart {
                forecastCounts[0] += 1
            }
        }

        totalCards = allCards.count
        newCards = newCount
        youngCards = youngCount
        matureCards = matureCount
        forecastNext7Days = forecastCounts

        // Esta tela é ESPECÍFICA de flashcard. O `progress` é GERAL (qbank +
        // simulados + flashcards) → usá-lo aqui mistura fontes e gera número
        // furado (era o HOJE > total de revisões). Então "hoje", "sequência" e
        // "retenção" vêm só de fonte de flashcard: stats do servidor
        // (enrichFromServer) + estudo local (foldInOffline). Só o tempo total de
        // estudo fica no geral (não há relógio por-ferramenta). Rafael 2026-07-18.
        totalStudyMinutes = Int(progress.totalStudyHours * 60)
    }

    // MARK: - Enrich from API stats endpoint

    private func enrichFromServer(_ stats: FlashcardStatsResponse) {
        if stats.totalCards > 0     { totalCards = stats.totalCards }
        if stats.newCards > 0       { newCards = stats.newCards }
        if stats.youngCards > 0     { youngCards = stats.youngCards }
        if stats.matureCards > 0    { matureCards = stats.matureCards }
        if stats.totalReviews > 0   { totalReviews = stats.totalReviews }
        if stats.retentionRate > 0  { retentionRate = stats.retentionRate }
        if stats.streakDays > 0     { streakDays = stats.streakDays }
        if stats.totalStudyMinutes > 0 { totalStudyMinutes = stats.totalStudyMinutes }
        if stats.todayReviews > 0   { todayReviews = stats.todayReviews }
        if !stats.reviewsPerDay.isEmpty  { reviewsPerDay = stats.reviewsPerDay }
        if !stats.forecastNext7Days.isEmpty { forecastNext7Days = stats.forecastNext7Days }
        if !stats.dailyRetention.isEmpty    { dailyRetention = stats.dailyRetention }
    }
}
