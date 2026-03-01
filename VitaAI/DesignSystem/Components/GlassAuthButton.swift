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
                            .font(VitaTypography.labelLarge)  // 14pt/medium — matches Android 14sp/500
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)  // matches Android GlassAuthButton height=42dp
            .background(isPrimary ? VitaColors.glassHighlight : VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))  // matches Android cornerRadius=8dp
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
