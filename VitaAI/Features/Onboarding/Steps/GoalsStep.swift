import SwiftUI

struct GoalsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private struct GoalOption: Identifiable {
        let id: String
        let label: String
        let sublabel: String
        let icon: String // SF Symbol name
    }

    private let options: [GoalOption] = [
        GoalOption(id: "provas",     label: "Provas",     sublabel: "Estudar para provas e avaliações",   icon: "graduationcap"),
        GoalOption(id: "residencia", label: "Residência", sublabel: "Preparação para residência médica",  icon: "cross.case"),
        GoalOption(id: "aprender",   label: "Aprender",   sublabel: "Aprofundar conhecimento médico",     icon: "brain.head.profile"),
        GoalOption(id: "organizar",  label: "Organizar",  sublabel: "Organizar rotina e cronograma",      icon: "calendar"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qual seu foco?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Pode selecionar mais de um")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer().frame(height: 24)

                // Goal cards
                VStack(spacing: 12) {
                    ForEach(options) { option in
                        GoalCard(
                            icon: option.icon,
                            label: option.label,
                            sublabel: option.sublabel,
                            isSelected: viewModel.selectedGoals.contains(option.id)
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.toggleGoal(option.id)
                        }
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Goal card

private struct GoalCard: View {
    let icon: String
    let label: String
    let sublabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 32)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(VitaTypography.bodyLarge)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundStyle(isSelected ? VitaColors.white : VitaColors.textSecondary)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)

                    Text(sublabel)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(isSelected ? VitaColors.accent.opacity(0.10) : VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
            )
            // Top-edge shimmer when selected (mirrors Android drawBehind gradient line)
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, VitaColors.accent.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
