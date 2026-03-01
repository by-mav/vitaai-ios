import SwiftUI

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cross.vial.fill")
                .font(.system(size: 60))
                .foregroundStyle(VitaColors.accent)

            Text("Bem-vindo ao VitaAI")
                .font(VitaTypography.headlineLarge)
                .foregroundStyle(VitaColors.white)

            Text("Seu assistente de estudos em medicina.\nVamos personalizar sua experiência.")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 32)

            GlassTextField(
                placeholder: "Como quer ser chamado?",
                text: $viewModel.nickname,
                icon: "person"
            )
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
