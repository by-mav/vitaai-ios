import SwiftUI

struct GoalsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Seus objetivos")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.white)

            Text("O que você quer alcançar com o VitaAI?")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.availableGoals, id: \.self) { goal in
                        Button(action: { viewModel.toggleGoal(goal) }) {
                            HStack {
                                Text(goal)
                                    .font(VitaTypography.bodyMedium)
                                    .foregroundStyle(viewModel.selectedGoals.contains(goal) ? VitaColors.accent : VitaColors.textPrimary)
                                Spacer()
                                if viewModel.selectedGoals.contains(goal) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(VitaColors.accent)
                                }
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
