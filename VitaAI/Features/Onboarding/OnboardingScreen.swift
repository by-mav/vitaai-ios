import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: OnboardingViewModel?
    let onComplete: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                OnboardingContent(viewModel: viewModel, onComplete: onComplete)
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
}

// MARK: - Main content (extracted to own view for clean @Bindable access)

private struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        VitaAmbientBackground {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                // Progress bar + animated dots
                VStack(spacing: 10) {
                    // Animated linear progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 4)

                            // Fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VitaColors.accent)
                                .frame(
                                    width: geo.size.width * CGFloat(viewModel.currentStep + 1) / CGFloat(totalSteps),
                                    height: 4
                                )
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.currentStep)
                        }
                    }
                    .frame(height: 4)

                    // Step dots
                    HStack(spacing: 10) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            let isActive = index == viewModel.currentStep
                            let isCompleted = index < viewModel.currentStep

                            Circle()
                                .fill(dotColor(index: index, isActive: isActive, isCompleted: isCompleted))
                                .frame(
                                    width: isActive ? 10 : 8,
                                    height: isActive ? 10 : 8
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentStep)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Step content via TabView (swipe disabled — navigate via buttons only)
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
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                // Bottom navigation
                bottomBar
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        let isLastStep = viewModel.currentStep == totalSteps - 1
        let canProceed = viewModel.canAdvance
        let showSkip = viewModel.canSkip && !canProceed

        VStack(spacing: 12) {
            // Primary button: Continue / Começar
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isLastStep {
                    Task {
                        await viewModel.complete()
                        onComplete()
                    }
                } else {
                    viewModel.advance()
                }
            }) {
                ZStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(VitaColors.white)
                    } else {
                        Text(isLastStep ? "Começar" : "Continuar")
                            .font(VitaTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(canProceed ? VitaColors.white : VitaColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    ZStack {
                        VitaColors.glassBg
                        // Glow overlay when last step is ready
                        if isLastStep && canProceed {
                            RadialGradient(
                                colors: [VitaColors.accent.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            canProceed ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: canProceed)
                .animation(.easeInOut(duration: 0.2), value: isLastStep)
            }
            .disabled(viewModel.isSaving || (!canProceed && !viewModel.canSkip))

            // Skip button (steps 1–3 when not yet valid)
            if showSkip {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.skip()
                }) {
                    Text("Pular")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
        .animation(.easeInOut(duration: 0.2), value: showSkip)
    }

    // MARK: - Helpers

    private func dotColor(index: Int, isActive: Bool, isCompleted: Bool) -> Color {
        if isActive { return VitaColors.accent }
        if isCompleted { return VitaColors.accent.opacity(0.6) }
        return Color.white.opacity(0.10)
    }
}
