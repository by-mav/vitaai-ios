import SwiftUI

// MARK: - SectionHeader — Gold uppercase label
// Matches mockup .section-label CSS:
//   font-size: 11-13px, weight: 700, uppercase, letter-spacing: 0.5-0.8px
//   color: rgba(255,241,215,0.55) gold tint

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionText: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VitaColors.sectionLabel)
                .kerning(0.5)
                .textCase(.uppercase)

            Spacer()

            if let actionText, let onAction {
                Button(actionText, action: onAction)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
            } else if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
