import SwiftUI

// MARK: - Sleep Step (atmospheric intro — tap to wake)

struct SleepStep: View {
    let onWake: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Spacer()

            // Pulsing hint text
            Text(String(localized: "onboarding_sleep_hint"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.bottom, 24)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWake()
            }) {
                Text(String(localized: "onboarding_sleep_wake"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
}
