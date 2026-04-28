import SwiftUI

// MARK: - GoalStep — P1 do onboarding v2 (Onda 5b, Rafael 2026-04-27)
//
// Pergunta: "Qual seu objetivo principal?"
// Filtragem dinamica baseada em `inFaculdade` (resposta anterior):
//   - inFaculdade=.yes → mostra todos: FACULDADE, ENAMED, RESIDENCIA, REVALIDA
//   - inFaculdade=.graduated/.skip → mostra apenas pos-grad: ENAMED, RESIDENCIA, REVALIDA
//
// Decisao Rafael 2026-04-27: nao bloquear via modal; opcoes invalidas
// "nem aparecem" (mais clean).

struct GoalStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private var visibleGoals: [OnboardingGoal] {
        switch viewModel.inFaculdade {
        case .yes:
            return [.faculdade, .enamed, .residencia, .revalida]
        case .graduated, .skip, nil:
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
