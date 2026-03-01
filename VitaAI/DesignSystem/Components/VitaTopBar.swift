import SwiftUI

struct VitaTopBar: View {
    let title: String
    var userName: String?
    var userImageURL: URL?
    var onAvatarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Button(action: { onAvatarTap?() }) {
                ZStack {
                    if let url = userImageURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            initialsView
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        initialsView
                    }
                }
                .frame(width: 40, height: 40)
                .background(VitaColors.accent.opacity(0.15))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Greeting + title
            VStack(alignment: .leading, spacing: 1) {
                if let userName {
                    let firstName = userName.split(separator: " ").first.map(String.init) ?? userName
                    Text("Olá, \(firstName)")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Text(title)
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.white)
            }

            Spacer()

            // Notification bell
            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var initialsView: some View {
        Text(userName?.prefix(1).uppercased() ?? "M")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(VitaColors.accent)
    }
}
