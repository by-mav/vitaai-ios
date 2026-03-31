import SwiftUI

// MARK: - PlannerViewModel
// Drives PlannerScreen: daily study tasks from API (GET /api/estudos/plan).

@MainActor
@Observable
final class PlannerViewModel {
    private let api: VitaAPI

    // State
    var isLoading = true
    var errorMessage: String?

    // Data
    var todayDate: String = ""
    var greeting: String = ""
    var tasks: [PlannerTask] = []
    var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    var totalCount: Int { tasks.count }
    var completionProgress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    // Study time today
    var studyMinutesToday: Int = 0
    var dailyGoalMinutes: Int = 3 * 60 // 3 hours default (moderate goal)

    // Streak
    var streakDays: Int = 0

    init(api: VitaAPI) {
        self.api = api
        updateGreeting()
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        // Set today's date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt-BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        todayDate = formatter.string(from: Date()).capitalized

        do {
            // Load study plan
            let plan = try await api.getStudyPlan()
            tasks = plan.tasks.enumerated().map { idx, task in
                PlannerTask(
                    id: task.id ?? "task-\(idx)",
                    title: task.title,
                    subtitle: task.subtitle ?? "",
                    icon: taskIcon(for: task.type),
                    color: taskColor(for: task.type),
                    type: task.type,
                    estimatedMinutes: task.estimatedMinutes ?? 30,
                    isCompleted: task.isCompleted ?? false,
                    linkedRoute: linkedRoute(for: task)
                )
            }

            // Load progress stats
            if let stats = try? await api.getGamificationStats() {
                streakDays = stats.currentStreak
            }

            if let progress = try? await api.getProgress() {
                studyMinutesToday = progress.todayStudyMinutes
            }

        } catch {
            errorMessage = NSLocalizedString("Erro ao carregar plano", comment: "")
        }

        isLoading = false
    }

    func toggleTask(_ task: PlannerTask) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()

        // Log activity if completing
        if tasks[idx].isCompleted {
            _ = try? await api.logActivity(
                action: "study_session_end",
                metadata: ["task_id": task.id, "task_type": task.type]
            )
        }
    }

    // MARK: - Helpers

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            greeting = NSLocalizedString("Bom dia", comment: "Morning greeting")
        } else if hour < 18 {
            greeting = NSLocalizedString("Boa tarde", comment: "Afternoon greeting")
        } else {
            greeting = NSLocalizedString("Boa noite", comment: "Evening greeting")
        }
    }

    private func taskIcon(for type: String) -> String {
        switch type {
        case "flashcard", "flashcards": return "rectangle.stack.fill"
        case "qbank", "questions": return "checkmark.square.fill"
        case "simulado": return "list.bullet.clipboard.fill"
        case "review": return "arrow.counterclockwise"
        case "reading", "pdf": return "doc.text.fill"
        case "notes": return "note.text"
        case "osce": return "stethoscope"
        case "chat": return "bubble.left.and.bubble.right.fill"
        default: return "book.fill"
        }
    }

    private func taskColor(for type: String) -> Color {
        switch type {
        case "flashcard", "flashcards": return VitaColors.dataBlue
        case "qbank", "questions": return Color(red: 160/255, green: 140/255, blue: 200/255)
        case "simulado": return VitaColors.dataGreen
        case "review": return VitaColors.dataAmber
        case "reading", "pdf": return VitaColors.accent
        case "notes": return Color(red: 200/255, green: 170/255, blue: 130/255)
        case "osce": return Color(red: 130/255, green: 200/255, blue: 140/255)
        default: return VitaColors.accent
        }
    }

    private func linkedRoute(for task: StudyPlanTask) -> Route? {
        switch task.type {
        case "flashcard", "flashcards":
            if let deckId = task.linkedId {
                return .flashcardSession(deckId: deckId)
            }
            return nil
        case "qbank", "questions": return .qbank
        case "simulado": return .simuladoHome
        case "osce": return .osce
        default: return nil
        }
    }

}

// MARK: - Data Models

struct PlannerTask: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let type: String
    let estimatedMinutes: Int
    var isCompleted: Bool
    let linkedRoute: Route?
}

// MARK: - API Response Models

struct StudyPlanResponse: Decodable {
    let tasks: [StudyPlanTask]
}

struct StudyPlanTask: Decodable {
    let id: String?
    let title: String
    let subtitle: String?
    let type: String
    let estimatedMinutes: Int?
    let isCompleted: Bool?
    let linkedId: String?
}
