import SwiftUI

struct GlassAuthButton: View {
    let label: String
    let icon: AnyView
    var isPrimary: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    HStack(spacing: 12) {
                        icon
                        Text(label)
                            .font(VitaTypography.bodyLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                            .fontWeight(.medium)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isPrimary ? VitaColors.glassHighlight : VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isPrimary ? VitaColors.accent.opacity(0.12) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
