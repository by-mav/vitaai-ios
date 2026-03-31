import SwiftUI

// MARK: - VitaTopBar — Glass Pill Top Navigation
// Matches mockup .topnav CSS: pill shape, avatar with XP ring, greeting, bell, hamburger

struct VitaTopBar: View {
    var title: String = ""
    var userName: String?
    var userImageURL: URL?
    var subtitle: String = ""
    var level: Int = 0
    var xpProgress: Double = 0
    var notificationCount: Int = 0
    var onAvatarTap: (() -> Void)?
    var onBellTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // Left: Avatar with XP ring
            Button(action: { onAvatarTap?() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: xpProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentHover.opacity(0.85),
                                    VitaColors.glassInnerLight.opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: VitaColors.accent.opacity(0.15), radius: 4)

                    if let url = userImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            avatarInitials
                        }
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    } else {
                        avatarInitials
                    }

                    // Level badge
                    Text("\(level)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [VitaColors.accent.opacity(0.35), VitaColors.accentDark.opacity(0.25)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        )
                        .overlay(Capsule().stroke(VitaColors.accentLight.opacity(0.30), lineWidth: 1))
                        .offset(y: 18)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Perfil")

            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 6) {
                navCircleButton(icon: "bell", badgeCount: notificationCount) { onBellTap?() }
                    .accessibilityLabel("Notificações")
                navCircleButton(icon: "line.3.horizontal") { onMenuTap?() }
                    .accessibilityLabel("Menu")
                    .accessibilityIdentifier("menu_button")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.surfaceElevated.opacity(0.60),
                            VitaColors.surfaceCard.opacity(0.68)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule().stroke(
                        VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.20), radius: 21, x: 0, y: 10)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, VitaColors.glassHighlight.opacity(0.11), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
        )
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let period = hour < 12 ? "Bom dia" : hour < 18 ? "Boa tarde" : "Boa noite"
        if let name = userName {
            let first = name.split(separator: " ").first.map(String.init) ?? name
            return "\(period), \(first)"
        }
        return period
    }

    private var avatarInitials: some View {
        Text(userName?.prefix(1).uppercased() ?? "R")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(VitaColors.accentLight.opacity(0.7))
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [VitaColors.accent.opacity(0.3), VitaColors.accentDark.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
    }

    private func navCircleButton(icon: String, badgeCount: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.68))
                    .frame(width: 44, height: 44)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                VitaColors.glassHighlight.opacity(0.075),
                                VitaColors.glassHighlight.opacity(0.03)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Circle().stroke(VitaColors.glassBorder, lineWidth: 1)
                )

                // Badge
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(VitaColors.dataRed))
                        .offset(x: 2, y: -2)
                }
            } // ZStack
        }
        .buttonStyle(.plain)
    }
}
