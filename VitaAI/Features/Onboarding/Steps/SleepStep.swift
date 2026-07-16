import SwiftUI

// MARK: - Sleep Step (atmospheric intro — tap to wake)

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
            leadingSystemImage: "sun.max.fill"
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHint(String(localized: "onboarding_sleep_hint"))
    }
}
