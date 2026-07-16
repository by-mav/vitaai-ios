import SwiftUI

struct GoalStep: View {
    @Bindable var viewModel: OnboardingViewModel
    var onSelect: (OnboardingGoal) -> Void

    private var visibleGoals: [OnboardingGoal] {
        switch viewModel.academicPhase {
        case .graduando:
            return [.faculdade, .enamed, .residencia, .revalida]
        case .professional, .residencia:
            return [.enamed, .residencia, .revalida]
        case .vestibulando:
            return [.faculdade]
        case .other, nil:
            return [.faculdade, .enamed, .residencia, .revalida]
        }
    }

    var body: some View {
        LazyVStack(spacing: VitaTokens.Spacing.sm) {
            ForEach(visibleGoals, id: \.self) { goal in
                OnboardingChoiceRow(
                    title: goal.title,
                    subtitle: goal.subtitle,
                    systemImage: goal.iconName,
                    isSelected: viewModel.selectedGoal == goal,
                    accessibilityIdentifier: "onboardingGoal_\(goal.rawValue)"
                ) {
                    viewModel.selectedGoal = goal
                    onSelect(goal)
                }
            }
        }
        .animation(
            .spring(response: 0.32, dampingFraction: 0.86),
            value: visibleGoals
        )
    }
}

extension OnboardingGoal {
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
