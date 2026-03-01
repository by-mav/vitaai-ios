import SwiftUI

struct StudyTipCard: View {
    let tip: String

    var body: some View {
        VitaGlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(VitaColors.accent)

                Text(tip)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }
}
