import Foundation

// MARK: - Professor Profile Models

struct ProfessorProfileResponse: Decodable {
    var id: String
    var name: String
    var university: String?
    var examCount: Int
    var profileData: ProfessorProfileData?
}

struct ProfessorProfileData: Decodable {
    var difficulty: String?
    var questionStyles: [String]?
    var styleDistribution: [String: Double]?
    var topFocusTopics: [String]?
    var tendencies: String?
    var lastUpdatedFromExam: String?
    var reasoningVsMemory: Double?
}

struct ExamAnalyzeResponse: Decodable {
    var success: Bool
    var message: String?
}

// MARK: - ProfessorProfileViewModel

@MainActor @Observable
final class ProfessorProfileViewModel {
    private(set) var profile: ProfessorProfileResponse?
    private(set) var isLoading = false
    private(set) var error: String?

    let subjectId: String
    private let api: VitaAPI

    init(subjectId: String, api: VitaAPI) {
        self.subjectId = subjectId
        self.api = api
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            profile = try await api.getProfessorProfile(subjectId: subjectId)
        } catch {
            self.error = "Erro ao carregar perfil do professor"
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Computed helpers

    var hasProfile: Bool {
        guard let p = profile else { return false }
        return p.examCount > 0 && p.profileData != nil
    }

    var difficultyColor: DifficultyColor {
        switch profile?.profileData?.difficulty?.lowercased() {
        case "easy", "facil": return .easy
        case "hard", "dificil": return .hard
        default: return .medium
        }
    }

    var difficultyLabel: String {
        switch profile?.profileData?.difficulty?.lowercased() {
        case "easy", "facil": return "Fácil"
        case "hard", "dificil": return "Difícil"
        default: return "Médio"
        }
    }

    var reasoningPercent: Int {
        let ratio = profile?.profileData?.reasoningVsMemory ?? 0.5
        return Int(ratio * 100)
    }

    enum DifficultyColor {
        case easy, medium, hard
    }
}
