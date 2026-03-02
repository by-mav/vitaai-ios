import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    private let tokenStore: TokenStore

    // MARK: - Navigation
    var currentStep: Int = 0
    let totalSteps = 5
    var isSaving = false

    // MARK: - Step 0: Welcome
    var nickname: String = ""

    // MARK: - Step 1: University
    var universityQuery: String = ""
    var selectedUniversity: University? = nil
    var selectedSemester: Int = 0

    // MARK: - Step 2: Subjects
    var selectedSubjects: [String] = []
    var customSubject: String = ""

    // MARK: - Step 3: Goals
    var selectedGoals: [String] = []

    // MARK: - Step 4: Time
    var dailyStudyMinutes: Int = 0

    // MARK: - Derived

    var filteredUniversities: [University] {
        let query = universityQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return brazilianMedicalSchools.filter { uni in
            uni.name.lowercased().contains(query) ||
            uni.shortName.lowercased().contains(query) ||
            uni.city.lowercased().contains(query)
        }
    }

    var semesterSubjects: [String] {
        guard selectedSemester >= 1 && selectedSemester <= 12 else { return [] }
        return medicineSubjectsBySemester[selectedSemester] ?? []
    }

    var canAdvance: Bool {
        switch currentStep {
        case 0: return !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return selectedUniversity != nil && selectedSemester > 0
        case 2: return !selectedSubjects.isEmpty
        case 3: return !selectedGoals.isEmpty
        case 4: return dailyStudyMinutes > 0
        default: return false
        }
    }

    /// Steps 1–3 can be skipped (university, subjects, goals)
    var canSkip: Bool {
        currentStep >= 1 && currentStep <= 3
    }

    // MARK: - Init

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
        // Pre-fill nickname from stored name
        Task {
            if let name = await tokenStore.userName, !name.isEmpty {
                self.nickname = name.split(separator: " ").first.map(String.init) ?? name
            }
        }
    }

    // MARK: - Navigation

    func advance() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func skip() {
        guard canSkip, currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Step mutations

    func selectUniversity(_ university: University) {
        selectedUniversity = university
        universityQuery = university.shortName
    }

    func clearUniversity() {
        selectedUniversity = nil
        universityQuery = ""
    }

    func selectSemester(_ semester: Int) {
        selectedSemester = semester
        selectedSubjects = []
    }

    func toggleSubject(_ subject: String) {
        if let idx = selectedSubjects.firstIndex(of: subject) {
            selectedSubjects.remove(at: idx)
        } else {
            selectedSubjects.append(subject)
        }
    }

    func addCustomSubject() {
        let trimmed = customSubject.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedSubjects.contains(trimmed) else {
            customSubject = ""
            return
        }
        selectedSubjects.append(trimmed)
        customSubject = ""
    }

    func toggleGoal(_ goal: String) {
        if let idx = selectedGoals.firstIndex(of: goal) {
            selectedGoals.remove(at: idx)
        } else {
            selectedGoals.append(goal)
        }
    }

    // MARK: - Save

    func complete() async {
        isSaving = true
        let data = OnboardingData(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            universityName: selectedUniversity?.shortName ?? "",
            universityState: selectedUniversity?.state ?? "",
            semester: selectedSemester,
            subjects: selectedSubjects,
            goals: selectedGoals,
            dailyStudyMinutes: dailyStudyMinutes
        )
        await tokenStore.saveOnboardingData(data)
        isSaving = false
    }
}
