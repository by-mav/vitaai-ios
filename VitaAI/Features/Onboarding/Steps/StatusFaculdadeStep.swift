import SwiftUI

/// Root branch of onboarding. Every choice is persisted by the view model
/// before navigation is allowed.
struct StatusFaculdadeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    var onSelect: (AcademicPhase) -> Void

    var body: some View {
        LazyVStack(spacing: VitaTokens.Spacing.sm) {
            option(.vestibulando, icon: "graduationcap")
            option(.graduando, icon: "books.vertical")
            option(.residencia, icon: "cross.case")
            option(.professional, icon: "stethoscope")
            option(.other, icon: "arrow.triangle.branch")
        }
        .animation(
            .spring(response: 0.32, dampingFraction: 0.86),
            value: viewModel.academicPhase
        )
    }

    private func option(_ phase: AcademicPhase, icon: String) -> some View {
        OnboardingChoiceRow(
            title: phase.title,
            systemImage: icon,
            isSelected: viewModel.academicPhase == phase,
            accessibilityIdentifier: "onboardingPhase_\(phase.rawValue)"
        ) {
            viewModel.selectAcademicPhase(phase)
            onSelect(phase)
        }
    }
}

extension AcademicPhase {
    var title: String {
        switch self {
        case .vestibulando:
            return String(localized: "onboarding_status_phase_vestibulando")
        case .graduando:
            return String(localized: "onboarding_status_phase_graduando")
        case .residencia:
            return String(localized: "onboarding_status_phase_residencia")
        case .professional:
            return String(localized: "onboarding_status_phase_professional")
        case .other:
            return String(localized: "onboarding_status_phase_other")
        }
    }

    var reaction: String {
        switch self {
        case .vestibulando:
            return String(localized: "onboarding_phase_reaction_vestibulando")
        case .graduando:
            return String(localized: "onboarding_phase_reaction_graduando")
        case .residencia:
            return String(localized: "onboarding_phase_reaction_residencia")
        case .professional:
            return String(localized: "onboarding_phase_reaction_professional")
        case .other:
            return String(localized: "onboarding_phase_reaction_other")
        }
    }
}
