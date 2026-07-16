import SwiftUI

// vita-modals-ignore: onboarding-multistep — phone, code and success.
struct OnboardingWhatsAppLinkSheet: View {
    @Binding var phone: String
    @Binding var code: String
    @Binding var stepIndex: Int
    @Binding var sending: Bool
    @Binding var error: String?
    let onSendCode: () -> Void
    let onVerify: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: VitaTokens.Spacing.lg) {
                Image(systemName: stepIndex == 2 ? "checkmark.circle.fill" : "message.fill")
                    .font(VitaTypography.displayLarge)
                    .foregroundStyle(stepIndex == 2 ? VitaColors.success : VitaColors.accent)
                    .padding(.top, VitaTokens.Spacing.lg)

                switch stepIndex {
                case 0: phoneEntry
                case 1: codeEntry
                default: connectedState
                }

                Spacer()
            }
            .padding(.horizontal, VitaTokens.Spacing._2xl)
            .background(VitaColors.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "onboarding_close"), action: onClose)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var phoneEntry: some View {
        heading(
            title: String(localized: "onboarding_whatsapp_title"),
            subtitle: String(localized: "onboarding_whatsapp_subtitle")
        )

        OnboardingTextInput(
            value: $phone,
            placeholder: String(localized: "onboarding_whatsapp_phone_placeholder"),
            leadingSystemImage: "phone",
            errorMessage: error,
            keyboardType: .phonePad,
            autocapitalization: .never,
            autocorrectionDisabled: true
        )
        .textContentType(.telephoneNumber)

        VitaButton(
            text: sending
                ? String(localized: "onboarding_sending")
                : String(localized: "onboarding_whatsapp_send_code"),
            action: onSendCode,
            variant: .primary,
            size: .md,
            isEnabled: phone.filter(\.isNumber).count >= 8 && !sending,
            fillsWidth: true
        )
    }

    @ViewBuilder
    private var codeEntry: some View {
        heading(
            title: String(localized: "onboarding_whatsapp_code_title"),
            subtitle: String(localized: "onboarding_whatsapp_code_subtitle")
        )

        OnboardingTextInput(
            value: $code,
            placeholder: "000000",
            leadingSystemImage: "number",
            errorMessage: error,
            keyboardType: .numberPad,
            autocapitalization: .never,
            autocorrectionDisabled: true
        )
        .textContentType(.oneTimeCode)

        VitaButton(
            text: sending
                ? String(localized: "onboarding_verifying")
                : String(localized: "onboarding_whatsapp_verify"),
            action: onVerify,
            variant: .primary,
            size: .md,
            isEnabled: code.filter(\.isNumber).count == 6 && !sending,
            fillsWidth: true
        )

        Button(String(localized: "onboarding_whatsapp_resend"), action: onSendCode)
            .font(VitaTypography.bodySmall)
            .foregroundStyle(VitaColors.textSecondary)
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private var connectedState: some View {
        heading(
            title: String(localized: "onboarding_whatsapp_connected"),
            subtitle: String(localized: "onboarding_whatsapp_connected_subtitle")
        )
    }

    private func heading(title: String, subtitle: String) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Text(title)
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Text(subtitle)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
