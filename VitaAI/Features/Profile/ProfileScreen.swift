import SwiftUI

struct ProfileScreen: View {
    let authManager: AuthManager

    // Navigation callbacks injected by AppRouter
    var onNavigateToAbout:         (() -> Void)?
    var onNavigateToAppearance:    (() -> Void)?
    var onNavigateToNotifications: (() -> Void)?
    var onNavigateToCanvasConnect: (() -> Void)?
    var onNavigateToWebAluno:      (() -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Avatar section
                VStack(spacing: 12) {
                    if let imageURL = authManager.userImage.flatMap(URL.init(string:)) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            avatarPlaceholder
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    if let name = authManager.userName {
                        Text(name)
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(VitaColors.white)
                    }
                }
                .padding(.top, 20)

                // Integrations group
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "building.columns",
                            title: "Canvas LMS",
                            subtitle: "Conectar faculdade",
                            action: { onNavigateToCanvasConnect?() }
                        )
                        Divider().background(VitaColors.glassBorder)
                        settingsRow(
                            icon: "graduationcap",
                            title: "WebAluno",
                            subtitle: "Conectar portal",
                            action: { onNavigateToWebAluno?() }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Preferences group
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "bell",
                            title: "Notificações",
                            subtitle: "Configurar alertas",
                            action: { onNavigateToNotifications?() }
                        )
                        Divider().background(VitaColors.glassBorder)
                        settingsRow(
                            icon: "paintpalette",
                            title: "Aparência",
                            subtitle: "Tema e preferências visuais",
                            action: { onNavigateToAppearance?() }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Support group
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "questionmark.circle",
                            title: "Sobre o VitaAI",
                            subtitle: "Versão, licenças e créditos",
                            action: { onNavigateToAbout?() }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Logout
                Button(action: { authManager.logout() }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sair da conta")
                    }
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .glassCard(cornerRadius: 12)
                }
                .padding(.horizontal, 20)

                // Version
                Text("VitaAI v0.1.0")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .padding(.top, 8)

                Spacer().frame(height: 100)
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(VitaColors.accent.opacity(0.15))
                .frame(width: 80, height: 80)
            Text(authManager.userName?.prefix(1).uppercased() ?? "V")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(subtitle)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}
