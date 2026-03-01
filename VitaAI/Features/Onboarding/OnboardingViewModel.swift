import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    private let tokenStore: TokenStore

    var currentStep: Int = 0
    var nickname: String = ""
    var selectedState: String = ""
    var selectedUniversity: String = ""
    var selectedSemester: Int = 1
    var selectedSubjects: Set<String> = []
    var selectedGoals: Set<String> = []
    var dailyStudyMinutes: Int = 120
    var isSaving = false

    let totalSteps = 5

    let availableGoals = [
        "Passar nas provas",
        "Manter média alta",
        "Preparar para residência",
        "Dominar conteúdo clínico",
        "Melhorar organização",
        "Reduzir ansiedade",
        "Revisar conteúdo atrasado",
        "Praticar questões",
    ]

    let studyTimeOptions = [30, 60, 90, 120, 180, 240]

    var filteredUniversities: [University] {
        guard !selectedState.isEmpty else { return brazilianMedicalSchools }
        return brazilianMedicalSchools.filter { $0.state == selectedState }
    }

    var semesterSubjects: [String] {
        medicineSubjectsBySemester[selectedSemester] ?? []
    }

    var canAdvance: Bool {
        switch currentStep {
        case 0: return !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !selectedUniversity.isEmpty
        case 2: return !selectedSubjects.isEmpty
        case 3: return !selectedGoals.isEmpty
        case 4: return true
        default: return false
        }
    }

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    func advance() {
        guard canAdvance, currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    func toggleSubject(_ subject: String) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
        } else {
            selectedSubjects.insert(subject)
        }
    }

    func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    func complete() async {
        isSaving = true
        let data = OnboardingData(
            nickname: nickname,
            universityName: selectedUniversity,
            universityState: selectedState,
            semester: selectedSemester,
            subjects: Array(selectedSubjects),
            goals: Array(selectedGoals),
            dailyStudyMinutes: dailyStudyMinutes
        )
        await tokenStore.saveOnboardingData(data)
        isSaving = false
    }
}
