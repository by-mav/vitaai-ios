import SwiftUI
import StoreKit

// MARK: - Trial Content

struct TrialStep: View {
    let product: Product?
    let isLoading: Bool
    let isEligibleForTrial: Bool
    let errorMessage: String?
    let noticeMessage: String?
    let onRestore: () -> Void

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

            if isLoading {
                ProgressView()
                    .tint(VitaColors.accent)
                    .accessibilityLabel(String(localized: "onboarding_trial_loading"))
            } else if let product {
                Text(
                    trialPriceFormat
                        .replacingOccurrences(of: "%@", with: product.displayPrice)
                )
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.74))
                .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .multilineTextAlignment(.center)
            }

            if let noticeMessage {
                Text(noticeMessage)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text(String(localized: "onboarding_trial_disclaimer"))
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.top, VitaTokens.Spacing.xs)

            HStack(spacing: VitaTokens.Spacing.sm) {
                Link(
                    String(localized: "onboarding_trial_terms"),
                    destination: URL(string: "https://vita-ai.cloud/terms")!
                )
                Text("·")
                Link(
                    String(localized: "onboarding_trial_privacy"),
                    destination: URL(string: "https://vita-ai.cloud/privacy")!
                )
                Text("·")
                Button(String(localized: "onboarding_trial_restore"), action: onRestore)
            }
            .font(VitaTypography.bodySmall)
            .foregroundStyle(VitaColors.accent.opacity(0.82))
            .tint(VitaColors.accent.opacity(0.82))
        }
    }

    private var trialPriceFormat: String {
        if isEligibleForTrial {
            return String(localized: "onboarding_trial_price_after")
        }
        return String(localized: "onboarding_trial_price_without_offer")
    }
}

private struct TrialFeature: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(VitaTypography.labelSmall.bold())
                .foregroundStyle(VitaColors.accent)
            Text(text)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
        }
    }
}
