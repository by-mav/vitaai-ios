import SwiftUI

struct GlassChip: View {
    let label: String
    var isSelected: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(label)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? VitaColors.accent.opacity(0.12) : VitaColors.glassBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? VitaColors.accent.opacity(0.2) : VitaColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
