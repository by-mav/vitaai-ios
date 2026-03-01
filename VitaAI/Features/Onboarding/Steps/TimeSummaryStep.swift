import SwiftUI

struct TimeSummaryStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.accent)

            Text("Tempo de estudo diário")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.white)

            Text("Quanto tempo pretende estudar por dia?")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)

            // Time options
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                ForEach(viewModel.studyTimeOptions, id: \.self) { minutes in
                    let hours = minutes / 60
                    let mins = minutes % 60
                    let label = hours > 0 ? (mins > 0 ? "\(hours)h\(mins)" : "\(hours)h") : "\(mins)min"

                    Button(action: { viewModel.dailyStudyMinutes = minutes }) {
                        Text(label)
                            .font(VitaTypography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundStyle(viewModel.dailyStudyMinutes == minutes ? VitaColors.accent : VitaColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                viewModel.dailyStudyMinutes == minutes
                                    ? VitaColors.accent.opacity(0.12)
                                    : VitaColors.glassBg
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.dailyStudyMinutes == minutes
                                            ? VitaColors.accent.opacity(0.2)
                                            : VitaColors.glassBorder,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Summary
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resumo")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.accent)

                    summaryRow(icon: "person", label: "Nome", value: viewModel.nickname)
                    summaryRow(icon: "building.columns", label: "Faculdade", value: viewModel.selectedUniversity.isEmpty ? "-" : viewModel.selectedUniversity)
                    summaryRow(icon: "book", label: "Disciplinas", value: "\(viewModel.selectedSubjects.count) selecionadas")
                    summaryRow(icon: "target", label: "Objetivos", value: "\(viewModel.selectedGoals.count) selecionados")
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
            Spacer()
            Text(value)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
        }
    }
}
