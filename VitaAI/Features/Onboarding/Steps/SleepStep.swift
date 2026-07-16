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
        .accessibilityIdentifier("onboardingWakeButton")
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
            OnboardingDreamZs()

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
            ZStack(alignment: .topLeading) {
                thoughtDot(size: VitaTokens.Spacing.md)
                thoughtDot(size: VitaTokens.Spacing.sm)
                    .offset(
                        x: -VitaTokens.Spacing.md,
                        y: VitaTokens.Spacing.md
                    )
            }
            .offset(x: -VitaTokens.Spacing.sm, y: VitaTokens.Spacing.sm)
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.26)) { phraseVisible = false }
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }
                phraseIndex = (phraseIndex + 1) % phrases.count
                withAnimation(.easeIn(duration: 0.32)) { phraseVisible = true }
            }
        }
    }

    private func thoughtDot(size: CGFloat) -> some View {
        Circle()
            .fill(VitaColors.glassBg)
            .overlay {
                Circle()
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            }
            .frame(width: size, height: size)
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

// MARK: - Dream sleeping indicator

/// The sleep cue belongs to the thought itself. Keeping it inside the glass
/// prevents the bubble from ever occluding an independently positioned Z.
struct OnboardingDreamZs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: VitaTokens.Spacing.xs) {
            zLetter(
                font: VitaTypography.labelSmall,
                rise: 0,
                delay: 0
            )
            zLetter(
                font: VitaTypography.labelMedium,
                rise: VitaTokens.Spacing.xs,
                delay: 0.45
            )
            zLetter(
                font: VitaTypography.titleSmall,
                rise: VitaTokens.Spacing.sm,
                delay: 0.9
            )
        }
        .frame(
            height: VitaTokens.Spacing._2xl,
            alignment: .bottomLeading
        )
        .onAppear { animate = !reduceMotion }
        .onChange(of: reduceMotion) { isReduced in
            animate = !isReduced
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func zLetter(font: Font, rise: CGFloat, delay: Double) -> some View {
        let letter = Text("Z")
            .font(font)
            .foregroundStyle(VitaColors.accentLight)
            .offset(
                y: -rise - (animate ? VitaTokens.Spacing.xs : 0)
            )
            .opacity(reduceMotion ? 0.56 : (animate ? 0.28 : 0.72))

        if reduceMotion {
            letter
        } else {
            letter
            .animation(
                .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
        }
    }
}
