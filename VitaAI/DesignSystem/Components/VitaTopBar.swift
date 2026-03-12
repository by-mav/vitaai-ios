import SwiftUI

struct VitaTopBar: View {
    let title: String
    var userName: String?
    var userImageURL: URL?
    var userLevel: Int?
    var userCourse: String?
    var userSemester: String?
    var onAvatarTap: (() -> Void)?
    var onNotificationsTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with level badge
            Button(action: { onAvatarTap?() }) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let url = userImageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                initialsView
                            }
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                        } else {
                            initialsView
                                .frame(width: 42, height: 42)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(VitaColors.accent.opacity(0.35), lineWidth: 1.5)
                    )

                    // Level badge
                    if let level = userLevel {
                        Text("\(level)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 26/255, green: 20/255, blue: 18/255))
                            .frame(width: 16, height: 16)
                            .background(VitaColors.accent)
                            .clipShape(Circle())
                            .offset(x: 2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)

            // Greeting + subtitle
            VStack(alignment: .leading, spacing: 1) {
                if let userName {
                    let firstName = userName.split(separator: " ").first.map(String.init) ?? userName
                    Text("\(timeGreeting), \(firstName)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineLimit(1)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                }

                // Subtitle: semestre · curso
                let sub = subtitleText
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            Spacer()

            // Notification bell
            Button(action: { onNotificationsTap?() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.60))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())

                    // Notification dot
                    Circle()
                        .fill(Color(red: 255/255, green: 80/255, blue: 60/255))
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)

            // Menu (hamburger)
            Button(action: { onMenuTap?() }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(VitaColors.accent.opacity(0.15))
            Text(userName?.prefix(1).uppercased() ?? "M")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
        }
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return NSLocalizedString("Bom dia", comment: "Morning greeting")
        } else if hour < 18 {
            return NSLocalizedString("Boa tarde", comment: "Afternoon greeting")
        } else {
            return NSLocalizedString("Boa noite", comment: "Evening greeting")
        }
    }

    private var subtitleText: String {
        let parts = [userSemester, userCourse].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
}
