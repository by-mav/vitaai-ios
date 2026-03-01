import Foundation
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    private let api: VitaAPI

    var streakDays: Int = 0
    var avgAccuracy: Double = 0
    var totalHours: Double = 0
    var totalCards: Int = 0
    var flashcardsDue: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var upcomingExams: [ExamEntry] = []
    var isLoading = true

    init(api: VitaAPI) { self.api = api }

    func load() async {
        isLoading = true
        loadMock()
        isLoading = false

        do {
            let p = try await api.getProgress()
            streakDays = p.streakDays
            avgAccuracy = p.avgAccuracy
            totalHours = p.totalStudyHours
            totalCards = p.totalCards
            flashcardsDue = p.flashcardsDue
            todayCompleted = p.todayCompleted
            todayTotal = p.todayTotal
            todayMinutes = p.todayStudyMinutes
            subjects = p.subjects
            upcomingExams = p.upcomingExams
        } catch {}
    }

    private func loadMock() {
        streakDays = 7
        avgAccuracy = 72.0
        totalHours = 48.5
        totalCards = 234
        flashcardsDue = 12
        todayCompleted = 3
        todayTotal = 5
        todayMinutes = 95
        subjects = [
            SubjectProgress(subjectId: "cm-cardio", accuracy: 78.0, hoursSpent: 12.5, cardsDue: 3),
            SubjectProgress(subjectId: "cm-pneumo", accuracy: 65.0, hoursSpent: 8.0, cardsDue: 5),
            SubjectProgress(subjectId: "cm-gastro", accuracy: 82.0, hoursSpent: 10.0, cardsDue: 1),
            SubjectProgress(subjectId: "cir-geral", accuracy: 55.0, hoursSpent: 6.0, cardsDue: 8),
            SubjectProgress(subjectId: "ped-geral", accuracy: 70.0, hoursSpent: 5.0, cardsDue: 2),
        ]
        upcomingExams = [
            ExamEntry(id: "e1", subjectName: "Cardiologia", examType: "Prova", date: "2025-02-15", daysUntil: 12),
            ExamEntry(id: "e2", subjectName: "Internato", examType: "OSCE", date: "2025-02-28", daysUntil: 25),
        ]
    }

    func accuracyColor(for accuracy: Double) -> Color {
        if accuracy >= 70 { return Color(hex: 0x22C55E) } // green
        if accuracy >= 50 { return Color(hex: 0xF59E0B) } // amber
        return Color(hex: 0xEF4444) // red
    }

    func subjectName(for id: String) -> String {
        let names: [String: String] = [
            "cm-cardio": "Cardiologia",
            "cm-pneumo": "Pneumologia",
            "cm-gastro": "Gastroenterologia",
            "cm-nefro": "Nefrologia",
            "cm-endocrino": "Endocrinologia",
            "cm-reumato": "Reumatologia",
            "cm-hemato": "Hematologia",
            "cm-infecto": "Infectologia",
            "cm-neuro": "Neurologia",
            "cir-geral": "Cirurgia Geral",
            "cir-trauma": "Cirurgia do Trauma",
            "ped-geral": "Pediatria",
            "go-obstetricia": "Obstetrícia",
            "go-ginecologia": "Ginecologia",
            "prev-epidemio": "Epidemiologia",
            "prev-bioestat": "Bioestatística",
        ]
        return names[id] ?? id
    }
}
