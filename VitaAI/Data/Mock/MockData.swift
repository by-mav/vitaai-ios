import Foundation
import SwiftUI

enum MockData {
    static func dashboardResponse() -> DashboardResponse {
        DashboardResponse(
            greeting: "Boa noite, \(AppConfig.demoUserName)",
            subtitle: "ULBRA",
            exams: [
                DashboardExam(
                    id: "exam-anatomia-p2",
                    title: "P2",
                    subject: "Anatomia Humana II",
                    daysUntil: 4,
                    description: nil,
                    conceptCards: 18,
                    practiceCards: 12
                ),
                DashboardExam(
                    id: "exam-farmaco-simulado",
                    title: "Simulado",
                    subject: "Farmacologia I",
                    daysUntil: 7,
                    description: nil,
                    conceptCards: 14,
                    practiceCards: 10
                )
            ],
            subjects: [
                DashboardSubject(name: "Anatomia Humana II"),
                DashboardSubject(name: "Farmacologia I"),
                DashboardSubject(name: "Histologia")
            ],
            agenda: [
                DashboardAgendaItem(type: "exam", title: "P2 · Anatomia Humana II", daysUntil: 4, date: "em 4 dias"),
                DashboardAgendaItem(type: "review", title: "Revisar farmacologia", daysUntil: 1, date: "amanha")
            ],
            flashcardsDueTotal: 23,
            studyRecommendations: [
                DashboardRecommendation(title: "Anatomia Humana II", dueCount: 12, deckId: "deck-anatomia")
            ],
            xp: DashboardXP(total: 1250, level: 5),
            todayReviewed: 18
        )
    }

    static func progressResponse() -> ProgressResponse {
        ProgressResponse(
            streakDays: 7,
            totalStudyHours: 42.5,
            avgAccuracy: 0.78,
            flashcardsDue: 23,
            totalCards: 245,
            todayCompleted: 18,
            todayTotal: 25,
            todayStudyMinutes: 85,
            subjects: [
                SubjectProgress(subjectId: "Anatomia Humana II", accuracy: 0.58, hoursSpent: 12, cardsDue: 8, questionCount: 42),
                SubjectProgress(subjectId: "Farmacologia I", accuracy: 0.64, hoursSpent: 10, cardsDue: 5, questionCount: 36),
                SubjectProgress(subjectId: "Histologia", accuracy: 0.71, hoursSpent: 8, cardsDue: 4, questionCount: 28)
            ],
            weekGrades: [],
            upcomingExams: [
                ExamEntry(
                    id: "exam-anatomia-p2",
                    title: "P2",
                    subjectId: "anatomia",
                    subjectName: "Anatomia Humana II",
                    examType: "prova",
                    date: "2026-04-03",
                    result: nil,
                    notes: nil,
                    daysUntil: 4,
                    weight: nil,
                    pointsPossible: nil,
                    conceptCards: 18,
                    practiceCards: 12,
                    userId: nil,
                    createdAt: nil,
                    deletedAt: nil
                )
            ],
            heatmap: demoHeatmap(),
            weeklyHours: [1.5, 2.0, 0.5, 3.0, 1.0, 0.0, 0.0],
            weeklyGoalHours: 10,
            weeklyActualHours: 8,
            dailyStudyGoalMinutes: 120
        )
    }

    static func gamificationStats() -> GamificationStatsResponse {
        GamificationStatsResponse(
            totalXp: 1250,
            level: 5,
            currentLevelXp: 400,
            xpToNextLevel: 450,
            streakDays: 7,
            achievements: [
                BadgeWithStatus(
                    id: "first_review",
                    name: "Primeira Revisao",
                    description: "Complete sua primeira sessao.",
                    icon: "rectangle.stack.fill",
                    category: "cards",
                    rarity: "common",
                    unlocked: true,
                    unlockedAt: "2026-03-28T12:00:00.000Z"
                )
            ]
        )
    }

    static func leaderboardEntries() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(oderId: "u1", rank: 1, displayName: "Ana Lima", xp: 2100, level: 8, isMe: false),
            LeaderboardEntry(oderId: "u2", rank: 2, displayName: "Bruno Alves", xp: 1850, level: 7, isMe: false),
            LeaderboardEntry(oderId: "me", rank: 3, displayName: AppConfig.demoUserName, xp: 1250, level: 5, isMe: true),
            LeaderboardEntry(oderId: "u4", rank: 4, displayName: "Carla Souza", xp: 980, level: 4, isMe: false),
            LeaderboardEntry(oderId: "u5", rank: 5, displayName: "Diego Costa", xp: 900, level: 4, isMe: false)
        ]
    }

    static func demoHeatmap() -> [Int] {
        (0..<91).map { index in
            switch index % 5 {
            case 0: return 0
            case 1: return 1
            case 2: return 2
            case 3: return 3
            default: return 4
            }
        }
    }

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

    // MARK: - Gamification

    static func userProgress() -> UserProgress {
        return UserProgress(
            totalXp: 1_250,
            level: 5,
            currentLevelXp: 400,
            xpToNextLevel: 450,
            currentStreak: 7,
            longestStreak: 14,
            streakFreezes: 1,
            badges: badges(),
            totalCardsReviewed: 245,
            totalChatMessages: 18,
            totalNotesCreated: 6,
            dailyXp: 35,
            dailyGoal: 50,
            dailyLoginClaimed: true
        )
    }

    static func badges() -> [VitaBadge] {
        let now = Date()
        let cal = Calendar.current
        return [
            VitaBadge(id: "first_review",  name: "Primeira Revisão",   description: "Complete sua primeira sessão de flashcards.",    icon: "rectangle.stack.fill",  earnedAt: cal.date(byAdding: .day, value: -10, to: now), category: .cards),
            VitaBadge(id: "streak_3",      name: "3 Dias Seguidos",    description: "Mantenha uma sequência de 3 dias.",              icon: "flame.fill",            earnedAt: cal.date(byAdding: .day, value: -4, to: now),  category: .streak),
            VitaBadge(id: "streak_7",      name: "Semana Perfeita",    description: "Mantenha uma sequência de 7 dias.",              icon: "flame.fill",            earnedAt: now,                                           category: .streak),
            VitaBadge(id: "streak_30",     name: "Mês Dedicado",       description: "Mantenha uma sequência de 30 dias.",             icon: "flame.fill",            earnedAt: nil,                                           category: .streak),
            VitaBadge(id: "cards_100",     name: "Centurião",          description: "Revise 100 flashcards.",                        icon: "100.circle.fill",       earnedAt: cal.date(byAdding: .day, value: -2, to: now),  category: .cards),
            VitaBadge(id: "cards_500",     name: "Mestre dos Cards",   description: "Revise 500 flashcards.",                        icon: "star.circle.fill",      earnedAt: nil,                                           category: .cards),
            VitaBadge(id: "cards_1000",    name: "Lenda",              description: "Revise 1000 flashcards.",                       icon: "trophy.fill",           earnedAt: nil,                                           category: .cards),
            VitaBadge(id: "level_5",       name: "Estudante Dedicado", description: "Alcance o nível 5.",                            icon: "graduationcap.fill",    earnedAt: now,                                           category: .milestone),
            VitaBadge(id: "level_10",      name: "Residente",          description: "Alcance o nível 10.",                           icon: "cross.case.fill",       earnedAt: nil,                                           category: .milestone),
            VitaBadge(id: "first_note",    name: "Anotador",           description: "Crie sua primeira nota.",                       icon: "note.text",             earnedAt: cal.date(byAdding: .day, value: -6, to: now),  category: .study),
            VitaBadge(id: "first_chat",    name: "Curioso",            description: "Envie sua primeira mensagem para Vita.",        icon: "bubble.left.fill",      earnedAt: cal.date(byAdding: .day, value: -8, to: now),  category: .social),
            VitaBadge(id: "night_owl",     name: "Coruja",             description: "Estude após as 22h.",                           icon: "moon.fill",             earnedAt: nil,                                           category: .study),
            VitaBadge(id: "early_bird",    name: "Madrugador",         description: "Estude antes das 7h.",                          icon: "sunrise.fill",          earnedAt: nil,                                           category: .study),
        ]
    }
}
