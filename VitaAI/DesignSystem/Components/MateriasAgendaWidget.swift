import SwiftUI

// MARK: - MateriasAgendaWidget
//
// Shared agenda surface used by DashboardScreen and FaculdadeHomeScreen.
// Disciplines live in their own page/section now; the calendar owns only
// calendar controls: Aulas, Provas and Trabalhos.

struct MateriasAgendaWidget: View {
    let subjects: [GradeSubject]
    let schedule: [AgendaClassBlock]
    let evaluations: [AgendaEvaluation]
    var onNavigateToDiscipline: ((String, String) -> Void)?

    var body: some View {
        MonthlyCalendarView(
            schedule: schedule,
            evaluations: evaluations
        )
        .padding(14)
        .pixioRaised(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 14, y: 7)
    }
}
