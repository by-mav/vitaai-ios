import SwiftUI

// MARK: - VitaTopBar — Top nav minimalista (estilo Pixio)
//
// Rafael 2026-06-17: SEM a barra/pill. Só a foto de perfil (rosto) à esquerda e
// o hambúrguer à direita. Saudação, anel de XP e badge de nível saíram — a info
// de nível/XP vive na Home (trilha) e na aba Estatísticas.
//
// As props antigas (title/subtitle/level/xpProgress/xpToast) ficam só por
// compat dos callsites; são ignoradas no layout.

struct VitaTopBar: View {
    var title: String = ""
    var userName: String?
    var userImageURL: URL?
    var subtitle: String = ""
    var level: Int = 0
    var streak: Int = 0
    var xpProgress: Double = 0
    var xpToast: VitaXpToastState?
    var notificationCount: Int = 0
    var blendsWithHome: Bool = false
    var onAvatarTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onAvatarTap?() }) {
                VStack(spacing: blendsWithHome ? 2 : 4) {
                    avatarBadge

                    if level > 0 {
                        Text(blendsWithHome ? "\(level)" : "Nível \(level)")
                            .font(PixioTypo.micro)
                            .foregroundStyle(blendsWithHome ? Color.white.opacity(0.82) : VitaColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 54, minHeight: 62)
            .accessibilityLabel("Perfil")

            Spacer()

            Button(action: { onMenuTap?() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(blendsWithHome ? Color.white.opacity(0.86) : VitaColors.textSecondary)
                        .frame(width: 42, height: 42)
                        .background(menuChrome)
                    if notificationCount > 0 {
                        Text("\(notificationCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(VitaColors.dataRed))
                            .offset(x: 4, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("menuButton")
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
        .padding(.bottom, 0)
    }

    private var avatarBadge: some View {
        let size: CGFloat = blendsWithHome ? 56 : 48
        let imageSize: CGFloat = blendsWithHome ? 42 : 42
        return ZStack {
            avatarChrome
                .frame(width: size, height: size)

            if blendsWithHome && level > 0 {
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 3)
                    .frame(width: size - 1, height: size - 1)

                Circle()
                    .trim(from: 0, to: max(0.04, min(1, xpProgress)))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.46),
                                Color.white.opacity(0.95),
                                Color(red: 0.58, green: 0.92, blue: 0.50),
                                Color(red: 1.0, green: 0.86, blue: 0.46)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size - 1, height: size - 1)
                    .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.36).opacity(0.36), radius: 5, x: 0, y: 0)
            }

            avatarView
                .frame(width: imageSize, height: imageSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    blendsWithHome ? Color.white.opacity(0.52) : VitaColors.accentLight.opacity(0.48),
                                    blendsWithHome ? Color.white.opacity(0.18) : VitaColors.glassBorder.opacity(0.28),
                                    Color.white.opacity(blendsWithHome ? 0.14 : 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = userImageURL {
            CachedAsyncImage(url: url) { avatarInitials }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
        } else {
            avatarInitials
        }
    }

    private var avatarInitials: some View {
        Text(userName?.prefix(1).uppercased() ?? "R")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.945, blue: 0.843).opacity(blendsWithHome ? 0.90 : 0.75))
            .frame(width: 42, height: 42)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.784, green: 0.627, blue: 0.314).opacity(blendsWithHome ? 0.42 : 0.32),
                            Color(red: 0.627, green: 0.471, blue: 0.235).opacity(blendsWithHome ? 0.28 : 0.22)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
    }

    @ViewBuilder
    private var avatarChrome: some View {
        if blendsWithHome {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.white.opacity(0.16)))
                .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
        } else {
            Circle()
                .fill(VitaColors.surface.opacity(0.92))
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
        }
    }

    @ViewBuilder
    private var menuChrome: some View {
        if blendsWithHome {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle().fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.26),
                                Color(red: 1.0, green: 0.80, blue: 0.38).opacity(0.16),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 30
                        )
                    )
                )
                .overlay(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 0.75))
                .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.36).opacity(0.18), radius: 9, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
        } else {
            Circle()
                .fill(VitaColors.glassBg.opacity(0.56))
                .overlay(Circle().stroke(VitaColors.glassBorder.opacity(0.65), lineWidth: 0.75))
        }
    }
}
