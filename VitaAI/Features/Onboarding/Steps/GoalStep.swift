import SwiftUI

// MARK: - GoalStep — P1 do onboarding v2 (Onda 5b, Rafael 2026-04-27)
//
// Pergunta: "Qual seu objetivo principal?"
// Filtragem dinâmica baseada em `academicPhase` (resposta anterior — Onda 5b
// refined, Rafael 2026-04-28):
//   - .graduando    → todos: FACULDADE, ENAMED, RESIDENCIA, REVALIDA
//   - .residencia   → só pós-grad: ENAMED, RESIDENCIA, REVALIDA
//   - .vestibulando → só FACULDADE (objetivo natural: passar no vestibular)
//
// Decisão Rafael 2026-04-27/28: não bloquear via modal; opções inválidas
// "nem aparecem" (mais clean). `.skip` foi removido do enum em 2026-04-28.

struct GoalStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private var visibleGoals: [OnboardingGoal] {
        switch viewModel.academicPhase {
        case .graduando:
            return [.faculdade, .enamed, .residencia, .revalida]
        case .residencia:
            return [.enamed, .residencia, .revalida]
        case .vestibulando:
            // TODO Rafael: vestibulando ainda não tem jornada própria. Por
            // enquanto cai em FACULDADE pra não quebrar fluxo. Decisão pendente
            // sobre criar journeyType=VESTIBULAR.
            return [.faculdade]
        case nil:
            return [.enamed, .residencia, .revalida]
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(visibleGoals, id: \.self) { goal in
                goalCard(goal: goal)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: visibleGoals)
    }

    private func goalCard(goal: OnboardingGoal) -> some View {
        let isSelected = viewModel.selectedGoal == goal
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.selectedGoal = goal
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goal.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? VitaColors.accent : .white.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? VitaColors.accent.opacity(0.12) : Color.white.opacity(0.04))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.88))
                    Text(goal.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private extension OnboardingGoal {
    var iconName: String {
        switch self {
        case .faculdade: return "graduationcap.fill"
        case .enamed: return "doc.text.magnifyingglass"
        case .residencia: return "stethoscope"
        case .revalida: return "globe.americas.fill"
        }
    }

    var title: String {
        switch self {
        case .faculdade: return String(localized: "onboarding_goal_faculdade")
        case .enamed: return String(localized: "onboarding_goal_enamed")
        case .residencia: return String(localized: "onboarding_goal_residencia")
        case .revalida: return String(localized: "onboarding_goal_revalida")
        }
    }

    var subtitle: String {
        switch self {
        case .faculdade: return String(localized: "onboarding_goal_faculdade_sub")
        case .enamed: return String(localized: "onboarding_goal_enamed_sub")
        case .residencia: return String(localized: "onboarding_goal_residencia_sub")
        case .revalida: return String(localized: "onboarding_goal_revalida_sub")
        }
    }
}
