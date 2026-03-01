import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: OnboardingViewModel?
    let onComplete: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                onboardingContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(tokenStore: container.tokenStore)
            }
        }
    }

    @ViewBuilder
    private func onboardingContent(viewModel: OnboardingViewModel) -> some View {
        VitaAmbientBackground {
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= viewModel.currentStep ? VitaColors.accent : VitaColors.surfaceBorder)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Step content
                TabView(selection: Binding(
                    get: { viewModel.currentStep },
                    set: { _ in }
                )) {
                    WelcomeStep(viewModel: viewModel).tag(0)
                    UniversityStep(viewModel: viewModel).tag(1)
                    SubjectsStep(viewModel: viewModel).tag(2)
                    GoalsStep(viewModel: viewModel).tag(3)
                    TimeSummaryStep(viewModel: viewModel).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Navigation buttons
                HStack(spacing: 16) {
                    if viewModel.currentStep > 0 {
                        Button(action: { viewModel.goBack() }) {
                            Text("Voltar")
                                .font(VitaTypography.bodyMedium)
                                .foregroundStyle(VitaColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .glassCard(cornerRadius: 12)
                        }
                    }

                    Button(action: {
                        if viewModel.currentStep == viewModel.totalSteps - 1 {
                            Task {
                                await viewModel.complete()
                                onComplete()
                            }
                        } else {
                            viewModel.advance()
                        }
                    }) {
                        Group {
                            if viewModel.isSaving {
                                ProgressView().tint(VitaColors.white)
                            } else {
                                Text(viewModel.currentStep == viewModel.totalSteps - 1 ? "Começar" : "Próximo")
                                    .font(VitaTypography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VitaColors.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(viewModel.canAdvance ? VitaColors.accent : VitaColors.surfaceBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!viewModel.canAdvance || viewModel.isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}
