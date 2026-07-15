import Foundation

// MIGRATION: No generated OpenAPI equivalents for AppConfig models.
// App config endpoint not in OpenAPI spec. Kept manual.

// MARK: - AppConfigResponse
// Port of GET /api/config/app — single source of truth for all app configuration.
// All platforms (Web, Android, iOS) consume this endpoint.
// Cache: UserDefaults with 1-hour TTL.

struct AppConfigResponse: Codable {
    let gamification: GamificationConfig
}

// MARK: - GamificationConfig

struct GamificationConfig: Codable {
    let levels: LevelConfig
    let xpRewards: [String: Int]
    let completionRewards: CompletionRewardsConfig
    let streak: StreakConfig
    let badges: [AppBadgeConfig]
}

// MARK: - LevelConfig

struct LevelConfig: Codable {
    let maxLevel: Int
    let formula: String
}

// MARK: - Server reward rules

struct CompletionRewardsConfig: Codable {
    let qbank: CompletionRewardRule
    let simulado: CompletionRewardRule
}

struct CompletionRewardRule: Codable {
    let perAnswered: Int
    let max: Int
}

struct StreakConfig: Codable {
    let freezeMax: Int
    let freezeRechargeEveryDays: Int
}

// MARK: - AppBadgeConfig

struct AppBadgeConfig: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let xpReward: Int?
}
