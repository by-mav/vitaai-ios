import Foundation
import SwiftUI

// MARK: - Local Assignment Model

struct LocalAssignment: Identifiable {
    var id: String
    var title: String
    var courseName: String
    var dueAt: Date?
    var pointsPossible: Double?
    var isSubmitted: Bool

    var daysUntilDue: Int? {
        guard let due = dueAt else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day
    }

    var urgencyColor: Color {
        guard let days = daysUntilDue else { return .gray }
        if days <= 1 { return Color.red }
        if days <= 3 { return Color.orange }
        if days <= 7 { return Color.yellow }
        return Color.green
    }
}

// MARK: - TrabalhoViewModel

@MainActor
@Observable
final class TrabalhoViewModel {
    private let api: VitaAPI

    var assignments: [LocalAssignment] = []
    var grades: [GradeEntry] = []
    var selectedSegment: Int = 0
    var isLoading: Bool = true

    // Derived
    var pendingCount: Int {
        assignments.filter { !$0.isSubmitted }.count
    }

    var sortedAssignments: [LocalAssignment] {
        assignments.sorted {
            switch ($0.dueAt, $1.dueAt) {
            case let (lhs?, rhs?): return lhs < rhs
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return false
            }
        }
    }

    var sortedGrades: [GradeEntry] {
        grades.sorted {
            // Sort by date descending; items without dates go last
            let lhs = $0.date ?? ""
            let rhs = $1.date ?? ""
            return lhs > rhs
        }
    }

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        loadMock()
        isLoading = false

        // Attempt real API; silently fall back to mock on any error
        async let assignmentsTask: Void = fetchAssignments()
        async let gradesTask: Void = fetchGrades()
        _ = await (assignmentsTask, gradesTask)
    }

    private func fetchAssignments() async {
        do {
            let response = try await api.getAssignments()
            if !response.assignments.isEmpty {
                let now = Date()
                let iso = ISO8601DateFormatter()
                assignments = response.assignments.map { a in
                    let dueDate: Date? = a.dueAt.flatMap { iso.date(from: $0) }
                    // An assignment is "submitted" if its due date is in the past
                    let submitted = dueDate.map { $0 < now } ?? false
                    return LocalAssignment(
                        id: a.id,
                        title: a.name,
                        courseName: a.courseName,
                        dueAt: dueDate,
                        pointsPossible: a.pointsPossible,
                        isSubmitted: submitted
                    )
                }
            }
        } catch {
            print("[TrabalhoViewModel] assignments fallback: \(error)")
        }
    }

    private func fetchGrades() async {
        // Prefer WebAluno grades (richer subject data) if available,
        // then fall back to generic /grades endpoint.
        do {
            let webaluno = try await api.getWebalunoGrades()
            if !webaluno.grades.isEmpty {
                // Map WebalunoGrade → GradeEntry for unified display
                grades = webaluno.grades.compactMap { wg -> GradeEntry? in
                    // Use finalGrade if present, otherwise average of available grades
                    let value: Double
                    if let final_ = wg.finalGrade {
                        value = final_
                    } else {
                        let available = [wg.grade1, wg.grade2, wg.grade3].compactMap { $0 }
                        guard !available.isEmpty else { return nil }
                        value = available.reduce(0, +) / Double(available.count)
                    }
                    return GradeEntry(
                        id: wg.id.isEmpty ? UUID().uuidString : wg.id,
                        userId: "",
                        subjectId: wg.subjectCode ?? wg.subjectName,
                        label: wg.subjectName,
                        value: value,
                        maxValue: 10.0,
                        notes: wg.status,
                        date: wg.semester
                    )
                }
                return
            }
        } catch {
            print("[TrabalhoViewModel] webaluno grades fallback: \(error)")
        }

        do {
            let entries = try await api.getGrades(limit: 30)
            if !entries.isEmpty {
                grades = entries
            }
        } catch {
            print("[TrabalhoViewModel] grades fallback: \(error)")
        }
    }

    // MARK: - Mock Seed

    private func loadMock() {
        let cal = Calendar.current
        assignments = [
            LocalAssignment(
                id: "a1",
                title: "Relatório de Caso Clínico",
                courseName: "Semiologia",
                dueAt: cal.date(byAdding: .day, value: 2, to: Date()),
                pointsPossible: 10,
                isSubmitted: false
            ),
            LocalAssignment(
                id: "a2",
                title: "Apresentação Cardiologia",
                courseName: "Clínica Médica",
                dueAt: cal.date(byAdding: .day, value: 7, to: Date()),
                pointsPossible: 8,
                isSubmitted: false
            ),
            LocalAssignment(
                id: "a3",
                title: "Quiz Pneumologia",
                courseName: "Clínica Médica",
                dueAt: cal.date(byAdding: .day, value: -2, to: Date()),
                pointsPossible: 5,
                isSubmitted: true
            ),
            LocalAssignment(
                id: "a4",
                title: "Seminário de Semiologia",
                courseName: "Semiologia",
                dueAt: cal.date(byAdding: .day, value: 1, to: Date()),
                pointsPossible: 6,
                isSubmitted: false
            ),
        ]

        grades = [
            GradeEntry(
                id: "g1",
                userId: "",
                subjectId: "cm-cardio",
                label: "Prova 1 - Cardio",
                value: 7.5,
                maxValue: 10,
                notes: nil,
                date: "2025-01-15"
            ),
            GradeEntry(
                id: "g2",
                userId: "",
                subjectId: "cm-pneumo",
                label: "Prova 1 - Pneumo",
                value: 8.0,
                maxValue: 10,
                notes: nil,
                date: "2025-01-10"
            ),
            GradeEntry(
                id: "g3",
                userId: "",
                subjectId: "cir-geral",
                label: "Avaliação Cirurgia",
                value: 6.5,
                maxValue: 10,
                notes: nil,
                date: "2025-01-08"
            ),
            GradeEntry(
                id: "g4",
                userId: "",
                subjectId: "semi",
                label: "Prova Semiologia",
                value: 4.5,
                maxValue: 10,
                notes: nil,
                date: "2025-01-05"
            ),
        ]
    }
}
