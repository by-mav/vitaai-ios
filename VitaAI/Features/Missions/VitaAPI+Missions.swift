import Foundation
import SwiftUI

// MARK: - Missões diárias (3/dia, rotativas)
//
// 2 endpoints do backend Vita (provados E2E no dev 2026-07-16):
//   GET  /api/missions/today  → dia + 3 missões (progresso/tier/resgate) + bônus + saldo
//   POST /api/missions/claim  → resgata 1 missão concluída (409 não-concluída/já resgatada)
//
// Backend é SOT: sorteia as 3 do dia (determinístico por user+dia, corte
// America/Sao_Paulo = mesmo do streak), conta o progresso a partir do que o
// aluno REALMENTE fez (activity_logs) e credita o XP no resgate. O app só
// desenha e chama resgatar — nunca calcula progresso nem recompensa.
//
// O HTTPClient decodifica com .convertFromSnakeCase.

// MARK: - DTOs

/// Uma missão do dia. `tier` = bronze|silver|gold (recompensa crescente, padrão
/// Duolingo). `icon` = SF Symbol resolvido no backend (cliente renderiza cru).
struct DailyMission: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let icon: String
    let tier: String
    let target: Int
    let progress: Int
    let xpReward: Int
    let completed: Bool
    let claimed: Bool

    /// 0…1 pra barra de progresso.
    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(progress) / Double(target))
    }

    /// Pronta pra resgatar (o estado que acende a placa).
    var claimable: Bool { completed && !claimed }

    /// Família da missão (prefixo do id: "questions_20" → "questions") — mapeia
    /// pra tela onde o aluno faz a ação. Fonte: lib/missions/catalog.ts.
    var family: String { String(id.prefix(while: { $0 != "_" })) }
}

/// Onde a missão leva ao ser tocada (quando ainda não concluída). Cada família
/// aponta pra ferramenta que gera aquele progresso.
enum MissionDestination {
    case flashcards, qbank, simulado, transcricao

    init?(family: String) {
        switch family {
        case "flashcards": self = .flashcards
        case "questions", "correct": self = .qbank
        case "simulado": self = .simulado
        case "transcription": self = .transcricao
        default: return nil
        }
    }
}

struct DailyMissionBonus: Codable, Hashable, Sendable {
    let xpReward: Int
    let eligible: Bool
    let claimed: Bool
}

struct DailyMissionsResponse: Codable, Hashable, Sendable {
    let day: String
    let missions: [DailyMission]
    let bonus: DailyMissionBonus
    let coinBalance: Int
}

struct ClaimMissionRequest: Codable, Sendable {
    let missionId: String
}

struct ClaimMissionResponse: Codable, Sendable {
    let ok: Bool
    let missionId: String
    let xpAwarded: Int
    let bonusXpAwarded: Int
    let coinBalance: Int
    let totalXp: Int
    let level: Int
}

// MARK: - API

extension VitaAPI {
    /// GET /api/missions/today — as 3 missões do dia com progresso e resgate.
    func getDailyMissions() async throws -> DailyMissionsResponse {
        try await client.get("missions/today")
    }

    /// POST /api/missions/claim — resgata a recompensa. Lança
    /// APIError.serverError(409) quando não concluída ou já resgatada.
    func claimMission(id: String) async throws -> ClaimMissionResponse {
        // camelCase explícito (`missionId`) — o encoder global converteria pra
        // snake_case e o zod da rota rejeitaria com 400 (mesmo caso do buySkin).
        let body = try JSONEncoder().encode(ClaimMissionRequest(missionId: id))
        return try await client.postRaw("missions/claim", body: body)
    }
}

// MARK: - Store

/// Estado das missões do dia. Feature store própria (padrão SkinStore): load +
/// mutate + recarrega do backend (SOT). Não duplica o AppDataManager.
@MainActor
final class MissionStore: ObservableObject {
    @Published private(set) var day: String = ""
    @Published private(set) var missions: [DailyMission] = []
    @Published private(set) var bonus: DailyMissionBonus = .init(xpReward: 0, eligible: false, claimed: false)
    @Published private(set) var coinBalance: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var claimingId: String?
    @Published var errorMessage: String?
    /// Última recompensa resgatada — dispara a animação de moeda no popout.
    @Published var lastReward: ClaimMissionResponse?

    /// Missões prontas pra resgatar — é o número do selo na placa.
    var pendingCount: Int { missions.filter(\.claimable).count }

    private var liveObserver: NSObjectProtocol?

    deinit { if let o = liveObserver { NotificationCenter.default.removeObserver(o) } }

    /// Progresso AO VIVO: cada flashcard/questão que o aluno faz emite evento no
    /// SSE que já existe (/api/stream, domain "activity") → o quadro atualiza
    /// sozinho, sem polling e sem conexão nova (canon §17 + brain §Realtime).
    func startLiveUpdates(api: VitaAPI) {
        guard liveObserver == nil else { return }
        liveObserver = NotificationCenter.default.addObserver(
            forName: .activityLogged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.load(api: api) }
        }
    }

    func load(api: VitaAPI) async {
        isLoading = true
        defer { isLoading = false }
        do {
            apply(try await api.getDailyMissions())
        } catch {
            errorMessage = "Não consegui carregar as missões de hoje."
        }
    }

    /// Resgata e recarrega (o servidor manda). Retorna sucesso.
    @discardableResult
    func claim(id: String, api: VitaAPI) async -> Bool {
        guard claimingId == nil else { return false }
        claimingId = id
        defer { claimingId = nil }
        do {
            let r = try await api.claimMission(id: id)
            lastReward = r
            await load(api: api)
            return true
        } catch APIError.serverError(409) {
            // Estado local velho (outro device resgatou, ou a missão ainda não
            // fechou). O servidor é a verdade: recarrega e não inventa erro se
            // o resgate de fato já consta.
            await load(api: api)
            if missions.first(where: { $0.id == id })?.claimed == true { return true }
            errorMessage = "Essa missão ainda não está pronta."
            return false
        } catch {
            errorMessage = "Não consegui resgatar agora. Tente de novo."
            return false
        }
    }

    private func apply(_ r: DailyMissionsResponse) {
        day = r.day
        missions = r.missions
        bonus = r.bonus
        coinBalance = r.coinBalance
    }
}
