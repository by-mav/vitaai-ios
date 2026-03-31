import SwiftUI

@MainActor
@Observable
final class FaculdadeViewModel {
    private let api: VitaAPI
    private let tokenStore: TokenStore

    // State
    private(set) var isLoading = true
    private(set) var isConnected = false
    private(set) var grades: [WebalunoGrade] = []
    private(set) var summary: WebalunoGradesSummary?
    private(set) var schedule: [WebalunoScheduleBlock] = []
    private(set) var semesters: [String] = []
    var selectedSemester: String?
    private(set) var error: String?

    // Onboarding data
    private(set) var courseName: String = "Medicina"
    private(set) var universityName: String?
    private(set) var currentPeriod: Int?
    private(set) var averageAttendance: Double?
    private(set) var averageAbsence: Double?

    init(api: VitaAPI, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let status = try await api.getWebalunoStatus()
            isConnected = status.connected

            if !status.connected {
                isLoading = false
                return
            }

            async let gradesTask = api.getWebalunoGrades()
            async let scheduleTask = api.getWebalunoSchedule()
            let (gradesResp, scheduleResp) = try await (gradesTask, scheduleTask)

            grades = gradesResp.grades
            summary = gradesResp.summary
            schedule = scheduleResp.schedule

            // Compute semesters sorted by most recent first
            semesters = Array(
                Set(grades.compactMap(\.semester))
            ).sorted { a, b in
                semesterSortKey(a) > semesterSortKey(b)
            }
            selectedSemester = semesters.first

            // Onboarding data for course/university info
            if let onboarding = await tokenStore.getOnboardingData() {
                if !onboarding.universityName.isEmpty {
                    universityName = onboarding.universityName
                }
                if onboarding.semester > 0 {
                    currentPeriod = onboarding.semester
                }
            }

            // Compute average attendance from grades that have attendance data
            let gradesWithAttendance = grades.compactMap(\.attendance)
            if !gradesWithAttendance.isEmpty {
                let avg = gradesWithAttendance.reduce(0, +) / Double(gradesWithAttendance.count)
                averageAttendance = avg
                averageAbsence = 100.0 - avg
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectSemester(_ semester: String) {
        selectedSemester = semester
    }

    var filteredGrades: [WebalunoGrade] {
        guard let sem = selectedSemester else { return grades }
        return grades.filter { $0.semester == sem }
    }

    // MARK: - Helpers

    private func semesterSortKey(_ semester: String) -> Int {
        let parts = semester.split(separator: "/")
        let period = Int(parts.first ?? "0") ?? 0
        let year = Int(parts.last ?? "0") ?? 0
        return year * 10 + period
    }
}
