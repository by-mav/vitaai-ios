import SwiftUI

// MARK: - StatusFaculdadeStep — P1 do onboarding v2 (Onda 5b refined, Rafael 2026-04-28)
//
// Pergunta: "Em qual fase você está?" (acadêmica)
// 3 opções macro (em vez do antigo yes/graduated):
//   - Vestibulando — vai prestar vestibular pra medicina
//   - Graduando    — está cursando medicina
//   - Residência   — já formou, foco em prova de residência
//
// A fase escolhida deriva o `inFaculdade` legado (graduando=.yes, residência=
// .graduated) pra manter compatibilidade com o backend `onboardingV2Schema`,
// e o GoalStep depois filtra goals válidos. `Vestibulando` ainda não tem
// jornada própria — backend só vê `inFaculdade=nil`, frontend mostra goals
// específicos no próximo step (decisão Rafael ainda em aberto).

struct StatusFaculdadeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 10) {
            phaseOption(
                phase: .vestibulando,
                title: String(localized: "onboarding_status_phase_vestibulando"),
                icon: "graduationcap"
            )
            phaseOption(
                phase: .graduando,
                title: String(localized: "onboarding_status_phase_graduando"),
                icon: "books.vertical"
            )
            phaseOption(
                phase: .residencia,
                title: String(localized: "onboarding_status_phase_residencia"),
                icon: "cross.case"
            )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.academicPhase)
    }

    private func phaseOption(phase: AcademicPhase, title: String, icon: String) -> some View {
        let isSelected = viewModel.academicPhase == phase
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.academicPhase = phase
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? VitaColors.accent : Color.white.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 9, height: 9)
                    }
                }

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? VitaColors.accent : .white.opacity(0.55))
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
