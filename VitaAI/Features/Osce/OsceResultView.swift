import SwiftUI

// MARK: - OsceResultView — completed phase

struct OsceResultView: View {
    @Bindable var viewModel: OsceViewModel

    private var score: Int { viewModel.score ?? 0 }

    private var scoreColor: Color {
        switch score {
        case 70...:  return VitaColors.dataGreen
        case 50..<70: return VitaColors.dataAmber
        default:      return VitaColors.dataRed
        }
    }

    private var verdict: String {
        switch score {
        case 70...:  return "Excelente desempenho!"
        case 50..<70: return "Bom desempenho, continue praticando"
        default:      return "Continue treinando, você vai melhorar!"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Animated score ring
                ScoreRingView(score: score, color: scoreColor)

                // Verdict + specialty badge
                VStack(spacing: 10) {
                    Text(verdict)
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Label(viewModel.specialty, systemImage: "stethoscope")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(VitaColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Step-by-step summary
                if !viewModel.exchanges.isEmpty {
                    StepSummaryCard(exchanges: viewModel.exchanges)
                        .padding(.horizontal, 16)
                }

                // General feedback card
                if !viewModel.feedback.isEmpty {
                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Feedback Geral", systemImage: "text.badge.checkmark")
                                .font(VitaTypography.labelLarge)
                                .fontWeight(.semibold)
                                .foregroundStyle(VitaColors.accent)
                            Text(viewModel.feedback)
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                }

                // New case CTA
                Button(action: viewModel.resetCase) {
                    Label("Novo Caso", systemImage: "arrow.clockwise")
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.surface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VitaColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Score Ring

private struct ScoreRingView: View {
    let score: Int
    let color: Color

    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            ProgressRingView(
                progress: progress,
                size: 140,
                strokeWidth: 12,
                trackColor: color.opacity(0.15),
                progressColor: color
            )

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(VitaTypography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text("/ 100")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                progress = Double(score) / 100.0
            }
        }
    }
}

// MARK: - Step Summary

private struct StepSummaryCard: View {
    let exchanges: [OsceViewModel.OsceExchange]

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Etapas concluídas")
                    .font(VitaTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ForEach(Array(exchanges.enumerated()), id: \.element.id) { idx, exchange in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            Rectangle()
                                .fill(VitaColors.glassBorder)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            // Step circle
                            ZStack {
                                Circle()
                                    .fill(VitaColors.accent)
                                    .frame(width: 24, height: 24)
                                Text("\(exchange.step)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VitaColors.surface)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(exchange.stepName)
                                    .font(VitaTypography.labelMedium)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VitaColors.textPrimary)
                                Text(exchange.userResponse)
                                    .font(VitaTypography.bodySmall)
                                    .foregroundStyle(VitaColors.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                Spacer().frame(height: 4)
            }
        }
    }
}
