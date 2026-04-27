import SwiftUI

// MARK: - JornadaScreen
//
// Tela universal da tab Jornada. Substitui FaculdadeHomeScreen como entry point.
// Renderiza cards diferentes conforme userJourney.journeyType (Onda 6).
//
// PHASE 1 (atual): default journeyType=.faculdade → renderiza FaculdadeHomeScreen
// (conteudo atual da Faculdade — ZERO mudanca pra Rafael e users existentes).
//
// PHASE 6 (futuro): integrar com appData.profile.journeyType (apos backend
// expor o campo no /api/profile). Stubs INTERNATO/ENAMED/RESIDENCIA/REVALIDA
// ja prontos como JornadaEmptyStateCards.
//
// SOT: agent-brain/decisions/2026-04-27_jornada-3lentes-FINAL.md
// Backend Phase 1 ja em main: commit d2ab3a1 (migration 0077 + endpoint).

struct JornadaScreen: View {
    // PHASE 1: default fixo pra retrocompat. PHASE 6 lera do AppDataManager.
    private var journeyType: JourneyType { .faculdade }

    var body: some View {
        switch journeyType {
        case .faculdade:
            FaculdadeHomeScreen()
        case .internato:
            JornadaEmptyStateCards(
                journeyName: "Internato",
                tagline: "Rotacoes, casos clinicos, OSCE e checklists",
                icon: "stethoscope"
            )
        case .enamed:
            JornadaEmptyStateCards(
                journeyName: "ENAMED",
                tagline: "Matriz oficial, simulados e cronograma do exame federal",
                icon: "doc.text.fill"
            )
        case .residencia:
            JornadaEmptyStateCards(
                journeyName: "Residencia",
                tagline: "Bancas, provas antigas e revisao por erro",
                icon: "cross.case"
            )
        case .revalida:
            JornadaEmptyStateCards(
                journeyName: "Revalida",
                tagline: "Etapas 1a e 2a, casos clinicos e OSCE",
                icon: "globe.americas"
            )
        }
    }
}

struct JornadaEmptyStateCards: View {
    let journeyName: String
    let tagline: String
    let icon: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(VitaColors.accentHover.opacity(0.7))
            Text("Jornada \(journeyName)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text(tagline)
                .font(.system(size: 15))
                .foregroundStyle(VitaColors.textWarm.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            VStack(spacing: 8) {
                Text("Em breve")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.accentHover)
                Text("Estamos preparando os cards para sua jornada")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.5))
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surface.ignoresSafeArea())
    }
}
