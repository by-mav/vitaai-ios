import SwiftUI

// MARK: - Trial Content

struct TrialStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "onboarding_trial_badge"))
                .font(.system(size: 11, weight: .bold)).tracking(2)
                .foregroundStyle(VitaColors.accent)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(
                    Capsule().fill(VitaColors.accent.opacity(0.12))
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.25), lineWidth: 1))
                )

            VStack(spacing: 12) {
                TrialFeature(text: String(localized: "onboarding_trial_f1"))
                TrialFeature(text: String(localized: "onboarding_trial_f2"))
                TrialFeature(text: String(localized: "onboarding_trial_f3"))
                TrialFeature(text: String(localized: "onboarding_trial_f4"))
                TrialFeature(text: String(localized: "onboarding_trial_f5"))
            }

            Text(String(localized: "onboarding_trial_disclaimer"))
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center).padding(.top, 4)
        }
    }
}

private struct TrialFeature: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.accent)
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
