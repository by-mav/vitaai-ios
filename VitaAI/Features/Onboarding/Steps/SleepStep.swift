import SwiftUI

// MARK: - Sleep Step

/// Keeps the original first-slide CTA. The sleeping mascot remains owned by
/// VitaOnboarding so its established size and position do not change.
struct SleepStep: View {
    let onWake: () -> Void

    var body: some View {
        VitaButton(
            text: String(localized: "onboarding_sleep_wake"),
            action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWake()
            },
            variant: .primary,
            size: .md,
            fillsWidth: true
        )
        .padding(.horizontal, VitaTokens.Spacing._4xl + VitaTokens.Spacing._3xl)
        .accessibilityHint(String(localized: "onboarding_sleep_hint"))
    }
}

// MARK: - Dream thoughts

struct OnboardingDreamThoughts: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phraseIndex = 0
    @State private var phraseVisible = true

    private var phrases: [String] {
        [
            String(localized: "onboarding_dream_plexus"),
            String(localized: "onboarding_dream_c5_c7"),
            String(localized: "onboarding_dream_mitochondria"),
            String(localized: "onboarding_dream_cranial_nerves"),
            String(localized: "onboarding_dream_sodium_potassium"),
            String(localized: "onboarding_dream_raas")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text(phrases[phraseIndex])
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineSpacing(VitaTokens.Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .opacity(phraseVisible ? 1 : 0)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
        .frame(width: 206)
        .background {
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) { EmptyView() }
        }
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: VitaTokens.Spacing.xs) {
                Circle()
                    .fill(VitaColors.glassBg)
                    .frame(width: VitaTokens.Spacing.md, height: VitaTokens.Spacing.md)
                Circle()
                    .fill(VitaColors.glassBg)
                    .frame(width: VitaTokens.Spacing.sm, height: VitaTokens.Spacing.sm)
                    .offset(y: VitaTokens.Spacing.md)
            }
            .offset(x: -VitaTokens.Spacing.md, y: VitaTokens.Spacing.md)
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.7))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.22)) { phraseVisible = false }
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                phraseIndex = (phraseIndex + 1) % phrases.count
                withAnimation(.easeIn(duration: 0.28)) { phraseVisible = true }
            }
        }
    }
}

// MARK: - Introduction name step

struct IntroductionNameStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onSubmit: () -> Void

    var body: some View {
        OnboardingTextInput(
            value: $viewModel.nickname,
            placeholder: String(localized: "onboarding_intro_name_placeholder"),
            leadingSystemImage: "person",
            submitLabel: .continue,
            accessibilityIdentifier: "onboardingNameInput",
            onSubmit: onSubmit
        )
        .textContentType(.name)
    }
}

// MARK: - Original sleeping indicator

struct OnboardingSleepingZs: View {
    @State private var animate = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            zLetter(size: VitaTokens.Typography.fontSizeXs, delay: 0.0)
            zLetter(size: VitaTokens.Typography.fontSizeBase, delay: 0.9)
                .offset(x: VitaTokens.Spacing.sm)
            zLetter(size: VitaTokens.Typography.fontSizeLg, delay: 1.8)
                .offset(x: VitaTokens.Spacing.lg)
        }
        .frame(
            width: VitaTokens.Spacing._4xl,
            height: VitaTokens.Spacing._3xl,
            alignment: .bottomLeading
        )
        .onAppear { animate = true }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func zLetter(size: CGFloat, delay: Double) -> some View {
        Text("Z")
            .font(.system(size: size, weight: .heavy, design: .rounded)) // ds-allow: restore original mascot sleep lettering
            .foregroundStyle(VitaColors.textSecondary)
            .offset(y: animate ? -VitaTokens.Spacing.lg : 0)
            .opacity(animate ? 0 : 1)
            .animation(
                .easeOut(duration: 2.7)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: animate
            )
    }
}
