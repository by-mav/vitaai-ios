import SwiftUI

struct OnboardingWhatsAppLinkContent: View {
    @Binding var phone: String
    @Binding var code: String
    @Binding var stepIndex: Int
    @Binding var sending: Bool
    @Binding var error: String?
    let onSendCode: () -> Void
    let onVerify: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            HStack(alignment: .top, spacing: VitaTokens.Spacing.md) {
                Image("connector-whatsapp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: VitaTokens.Radius.md,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                    Text(String(localized: "onboarding_whatsapp_title"))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)

                    if stepIndex == 0 {
                        Text(String(localized: "onboarding_whatsapp_subtitle"))
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            switch stepIndex {
            case 0:
                phoneEntry
            case 1:
                codeEntry
            default:
                connectedState
            }
        }
    }

    @ViewBuilder
    private var phoneEntry: some View {
        OnboardingTextInput(
            value: $phone,
            placeholder: String(localized: "onboarding_whatsapp_phone_placeholder"),
            leadingSystemImage: "phone.fill",
            errorMessage: error,
            keyboardType: .phonePad,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            accessibilityIdentifier: "onboardingWhatsAppPhoneInput"
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
        .accessibilityIdentifier("onboardingWhatsAppSendCodeButton")
    }

    @ViewBuilder
    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            Text(String(localized: "onboarding_whatsapp_code_title"))
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Text(String(localized: "onboarding_whatsapp_code_subtitle"))
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }

        OnboardingTextInput(
            value: $code,
            placeholder: "000000",
            leadingSystemImage: "number",
            errorMessage: error,
            keyboardType: .numberPad,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            accessibilityIdentifier: "onboardingWhatsAppCodeInput"
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
        .accessibilityIdentifier("onboardingWhatsAppVerifyButton")

        Button(String(localized: "onboarding_whatsapp_resend"), action: onSendCode)
            .font(VitaTypography.bodySmall)
            .foregroundStyle(VitaColors.textSecondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var connectedState: some View {
        HStack(alignment: .top, spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.success)
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                Text(String(localized: "onboarding_whatsapp_connected"))
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(String(localized: "onboarding_whatsapp_connected_subtitle"))
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
        }
    }
}
