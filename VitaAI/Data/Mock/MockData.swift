import Foundation
import SwiftUI

enum MockData {
    static func dashboardProgress() -> DashboardProgress {
        DashboardProgress(
            progressPercent: 0.68,
            streak: 5,
            flashcardsDue: 23,
            accuracy: 0.82,
            studyMinutes: 145
        )
    }

    static func upcomingExams() -> [UpcomingExam] {
        let today = Date()
        let cal = Calendar.current
        return [
            UpcomingExam(id: "e1", subject: "Anatomia Humana II", type: "P2", date: cal.date(byAdding: .day, value: 2, to: today)!, daysUntil: 2),
            UpcomingExam(id: "e2", subject: "Bioquímica Clínica", type: "Prova Final", date: cal.date(byAdding: .day, value: 5, to: today)!, daysUntil: 5),
            UpcomingExam(id: "e3", subject: "Fisiologia Médica", type: "Simulado", date: cal.date(byAdding: .day, value: 8, to: today)!, daysUntil: 8),
            UpcomingExam(id: "e4", subject: "Farmacologia I", type: "P1", date: cal.date(byAdding: .day, value: 12, to: today)!, daysUntil: 12),
        ]
    }

    static func weekDays() -> [WeekDay] {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -(weekday - 2), to: today)!

        let events: [[String]] = [
            ["Anatomia 8h", "Lab Bioquímica 14h"],
            ["Fisiologia 10h"],
            ["Farmacologia 8h", "Seminário 16h"],
            ["Patologia 10h", "Monitoria 14h"],
            ["Semiologia 8h"],
            [],
            [],
        ]

        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday)!
            return WeekDay(
                date: date,
                label: date.shortWeekday,
                events: events[offset],
                isToday: cal.isDateInToday(date)
            )
        }
    }

    static func studyModules() -> [StudyModule] {
        [
            StudyModule(name: "Flashcards", icon: "book.pages", count: 23, color: VitaColors.accent),
            StudyModule(name: "Simulados", icon: "questionmark.circle", count: 5, color: VitaColors.accent),
            StudyModule(name: "PDFs", icon: "book", count: 48, color: VitaColors.accent),
            StudyModule(name: "Materiais", icon: "folder", count: 124, color: VitaColors.accent),
        ]
    }

    static func vitaSuggestions() -> [VitaSuggestion] {
        [
            VitaSuggestion(label: "Plano de estudo", prompt: "Crie um plano de estudo para minhas provas das próximas 2 semanas"),
            VitaSuggestion(label: "Revisar flashcards", prompt: "Me ajude a revisar os flashcards pendentes de Anatomia"),
            VitaSuggestion(label: "Resumo do dia", prompt: "Faça um resumo do que preciso estudar hoje"),
            VitaSuggestion(label: "Dicas de estudo", prompt: "Quais técnicas de estudo são mais eficazes para memorização?"),
        ]
    }

    static func studyTip() -> String {
        let tips = [
            "Técnica Pomodoro: 25min de foco, 5min de pausa. Após 4 ciclos, 15min de pausa longa.",
            "Revise os flashcards antes de dormir — o sono consolida memórias recém-formadas.",
            "Ensine o conteúdo a alguém (ou finja). Explicar ativa a retrieval practice.",
            "Intercale disciplinas diferentes no mesmo bloco de estudo para fortalecer conexões.",
            "Antes da prova, faça simulados em vez de reler. Testar > reler.",
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return tips[dayIndex % tips.count]
    }
}
