import SwiftUI

struct GreetingCard: View {
    let progress: DashboardProgress

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 16) {
                ProgressRingView(
                    progress: progress.progressPercent,
                    size: 72,
                    strokeWidth: 7
                )
                .overlay {
                    Text("\(Int(progress.progressPercent * 100))%")
                        .font(VitaTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                        Text("\(progress.streak) dias")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.accent)
                        Text("\(progress.flashcardsDue) cards pendentes")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("\(Int(progress.accuracy * 100))% acurácia")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.accentLight)
                        Text("\(progress.studyMinutes)min hoje")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }
}
