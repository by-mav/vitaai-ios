import SwiftUI

// MARK: - AchievementsViewModel
// Drives AchievementsScreen: loads badges from API (GET /api/activity/stats).
// The API is the source of truth for badge definitions.

@MainActor
@Observable
final class AchievementsViewModel {
    private let api: VitaAPI

    // Summary
    var totalXp: Int = 0
    var level: Int = 1
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var earnedCount: Int = 0
    var totalCount: Int = 0

    // Badges grouped by category
    var categories: [BadgeCategoryGroup] = []

    // Loading state
    var isLoading = true
    var errorMessage: String?

    // Selected badge for detail sheet
    var selectedBadge: AchievementBadge?

    init(api: VitaAPI) {
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let stats = try await api.getGamificationStats()

            totalXp = stats.totalXp
            level = stats.level
            currentStreak = stats.currentStreak
            longestStreak = stats.longestStreak

            // Build badge list directly from API response (source of truth)
            var allBadges: [AchievementBadge] = stats.badges.map { badge in
                AchievementBadge(
                    id: badge.id,
                    name: badge.name,
                    description: badge.description,
                    icon: sfSymbol(for: badge.icon, category: badge.category),
                    category: badge.category,
                    isEarned: badge.earned,
                    earnedAt: badge.earnedAt.flatMap { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
                    xpReward: 0
                )
            }

            // Sort: earned first (most recent), then locked
            allBadges.sort { a, b in
                if a.isEarned != b.isEarned { return a.isEarned }
                if let aDate = a.earnedAt, let bDate = b.earnedAt { return aDate > bDate }
                return false
            }

            earnedCount = allBadges.filter { $0.isEarned }.count
            totalCount = allBadges.count

            // Group by category
            let grouped = Dictionary(grouping: allBadges, by: { $0.category })
            let categoryOrder = ["streak", "cards", "milestone", "study", "social"]
            categories = categoryOrder.compactMap { cat in
                guard let badges = grouped[cat], !badges.isEmpty else { return nil }
                return BadgeCategoryGroup(
                    category: cat,
                    displayName: categoryDisplayName(cat),
                    icon: categoryIcon(cat),
                    color: categoryColor(cat),
                    badges: badges
                )
            }

        } catch {
            errorMessage = NSLocalizedString("Erro ao carregar conquistas", comment: "")
        }

        isLoading = false
    }

    // MARK: - SF Symbol mapping from Material icon names
    private func sfSymbol(for materialIcon: String, category: String) -> String {
        switch materialIcon {
        case "local_fire_department", "whatshot": return "flame.fill"
        case "military_tech": return "shield.lefthalf.filled"
        case "emoji_events": return "trophy.fill"
        case "school", "style": return "rectangle.stack.fill"
        case "auto_awesome": return "sparkles"
        case "menu_book": return "book.fill"
        case "trending_up": return "arrow.up.right"
        case "workspace_premium": return "medal.fill"
        case "edit_note": return "note.text"
        case "dark_mode": return "moon.fill"
        case "wb_sunny": return "sun.max.fill"
        case "sports_esports": return "gamecontroller.fill"
        case "chat": return "bubble.left.and.bubble.right.fill"
        default:
            // Fallback by category
            switch category {
            case "streak": return "flame.fill"
            case "cards": return "rectangle.stack.fill"
            case "milestone": return "trophy.fill"
            case "study": return "book.fill"
            case "social": return "bubble.left.fill"
            default: return "star.fill"
            }
        }
    }

    private func categoryDisplayName(_ cat: String) -> String {
        switch cat {
        case "streak": return NSLocalizedString("Sequencia", comment: "Badge category streak")
        case "cards": return NSLocalizedString("Flashcards", comment: "Badge category cards")
        case "milestone": return NSLocalizedString("Marcos", comment: "Badge category milestone")
        case "study": return NSLocalizedString("Estudo", comment: "Badge category study")
        case "social": return NSLocalizedString("Social", comment: "Badge category social")
        default: return cat.capitalized
        }
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "streak": return "flame.fill"
        case "cards": return "rectangle.stack.fill"
        case "milestone": return "trophy.fill"
        case "study": return "book.fill"
        case "social": return "person.2.fill"
        default: return "star.fill"
        }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "streak": return VitaColors.dataAmber
        case "cards": return VitaColors.accent
        case "milestone": return VitaColors.dataAmber
        case "study": return VitaColors.dataGreen
        case "social": return VitaColors.dataBlue
        default: return VitaColors.accent
        }
    }

}

// MARK: - Data Models

struct AchievementBadge: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let isEarned: Bool
    let earnedAt: Date?
    let xpReward: Int

    var earnedDateString: String? {
        guard let date = earnedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt-BR")
        return formatter.string(from: date)
    }
}

struct BadgeCategoryGroup: Identifiable {
    var id: String { category }
    let category: String
    let displayName: String
    let icon: String
    let color: Color
    let badges: [AchievementBadge]

    var earnedCount: Int { badges.filter { $0.isEarned }.count }
}
