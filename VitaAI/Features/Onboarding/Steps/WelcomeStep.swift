import SwiftUI

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var nameFocused: Bool

    // Entrance animation state
    @State private var iconVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var fieldVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                // Hero icon with pulsing glow ring
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(VitaColors.accent.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .scaleEffect(iconVisible ? 1.0 : 0.5)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1), value: iconVisible)

                    // Inner circle
                    Circle()
                        .fill(VitaColors.accent.opacity(0.12))
                        .frame(width: 80, height: 80)
                        .scaleEffect(iconVisible ? 1.0 : 0.5)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconVisible)

                    Image(systemName: "cross.vial.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(VitaColors.accent)
                        .scaleEffect(iconVisible ? 1.0 : 0.3)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05), value: iconVisible)
                }

                Spacer().frame(height: 32)

                // Title
                Text("Bem-vindo ao VitaAI")
                    .font(VitaTypography.headlineLarge)
                    .foregroundStyle(VitaColors.white)
                    .multilineTextAlignment(.center)
                    .offset(y: titleVisible ? 0 : 16)
                    .opacity(titleVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: titleVisible)

                Spacer().frame(height: 8)

                // Subtitle
                Text("Vamos personalizar sua experiência")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .offset(y: subtitleVisible ? 0 : 12)
                    .opacity(subtitleVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: subtitleVisible)

                Spacer().frame(height: 48)

                // Name field section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Como quer ser chamado?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .foregroundStyle(VitaColors.textTertiary)
                            .frame(width: 20)

                        TextField("Seu nome", text: $viewModel.nickname)
                            .foregroundStyle(VitaColors.textPrimary)
                            .font(VitaTypography.bodyLarge)
                            .tint(VitaColors.accent)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                nameFocused ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: nameFocused)
                }
                .padding(.horizontal, 0)
                .offset(y: fieldVisible ? 0 : 16)
                .opacity(fieldVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: fieldVisible)

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { nameFocused = false }
        .onAppear {
            iconVisible = true
            titleVisible = true
            subtitleVisible = true
            fieldVisible = true
        }
    }
}
