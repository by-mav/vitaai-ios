import Foundation
import Observation

@MainActor
@Observable
final class LeaderboardViewModel {
    private let api: VitaAPI

    var entries: [LeaderboardEntry] = []
    var isLoading = true
    var errorMessage: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func load(period: String) async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await api.getLeaderboard(period: period)
        } catch {
            entries = []
            errorMessage = "Erro ao carregar ranking"
        }
        isLoading = false
    }
}
