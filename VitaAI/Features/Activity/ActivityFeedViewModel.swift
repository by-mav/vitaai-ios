import Foundation
import Observation

@MainActor
@Observable
final class ActivityFeedViewModel {
    private let api: VitaAPI

    var stats: GamificationStatsResponse?
    var feed: [ActivityFeedItem] = []
    var isLoading = true
    var errorMessage: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        async let statsTask: GamificationStatsResponse = api.getGamificationStats()
        async let feedTask: [ActivityFeedItem] = api.getActivityFeed(limit: 50)
        do {
            let (s, f) = try await (statsTask, feedTask)
            stats = s
            feed = f
        } catch {
            errorMessage = "Erro ao carregar atividade"
        }
        isLoading = false
    }
}
