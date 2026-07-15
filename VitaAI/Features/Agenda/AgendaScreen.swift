import SwiftUI
import Sentry

// MARK: - AgendaScreen
//
// Tela própria de Agenda — antes o link "Agenda" do menu hambúrguer caía na
// tab Faculdade (rota fantasma). Agora navega aqui.
// Reaproveita MonthlyCalendarView (mesmo componente do widget MateriasAgenda).
// Sem background custom — shell ambient mostra através.

struct AgendaScreen: View {
    @Environment(\.appData) private var appData

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(title: "Agenda")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        MonthlyCalendarView(
                            schedule: appData.classSchedule,
                            evaluations: appData.academicEvaluations
                        )
                    }
                    .padding(14)
                    .pixioRaised(in: RoundedRectangle(cornerRadius: 18, style: .continuous))  // ds-allow: raio herdado do card de agenda (pre-existente)
                    .shadow(color: .black.opacity(0.24), radius: 14, y: 7)

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable { await appData.forceRefresh() }
        }
        .background(Color.clear)
        .task { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Agenda")
    }
}
