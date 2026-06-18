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
    var onAvatarTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Esquerda: a foto de perfil (rosto), clean — igual Pixio.
            Button(action: { onAvatarTap?() }) {
                avatarView
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Perfil")

            Spacer()
            statusChips
            Spacer()

            // Direita: menu hambúrguer (sem barra de fundo).
            Button(action: { onMenuTap?() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.55))
                        .frame(width: 40, height: 40)
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
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // Nível + streak no centro da top nav (Rafael 2026-06-17).
    private var statusChips: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.45))
                Text("Nível \(level)").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.80))
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(
                Capsule().fill(Color(red: 0.50, green: 0.39, blue: 0.20).opacity(0.32))
                    .overlay(Capsule().stroke(Color(red: 1.0, green: 0.86, blue: 0.55).opacity(0.30), lineWidth: 1))
            )

            HStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.dataAmber)
                Text("\(streak)").font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(VitaColors.textPrimary)
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(
                Capsule().fill(VitaColors.dataAmber.opacity(0.14))
                    .overlay(Capsule().stroke(VitaColors.dataAmber.opacity(0.28), lineWidth: 1))
            )
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = userImageURL {
            CachedAsyncImage(url: url) { avatarInitials }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            avatarInitials
        }
    }

    private var avatarInitials: some View {
        Text(userName?.prefix(1).uppercased() ?? "R")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.945, blue: 0.843).opacity(0.75))
            .frame(width: 40, height: 40)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.32),
                            Color(red: 0.627, green: 0.471, blue: 0.235).opacity(0.22)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
    }
}
