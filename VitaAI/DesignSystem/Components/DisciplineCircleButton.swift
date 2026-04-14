import SwiftUI

// MARK: - DisciplineCircleButton
// Fire-themed circular badge with discipline artwork + subtle label below.

struct DisciplineCircleButton: View {
    let name: String
    let size: CGFloat
    let action: () -> Void

    private var imageAsset: String {
        DisciplineImages.imageAsset(for: name)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(imageAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .saturation(0.7)
                    .brightness(-0.08)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Text(shortName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .lineLimit(1)
                    .frame(width: size)
            }
        }
        .buttonStyle(.plain)
    }

    private var shortName: String {
        name
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
