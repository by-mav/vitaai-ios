import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionText: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.white)

            Spacer()

            if let actionText, let onAction {
                Button(actionText, action: onAction)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.accent)
            } else if let subtitle {
                Text(subtitle)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
