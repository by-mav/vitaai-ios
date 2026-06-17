import SwiftUI
import Sentry

// MARK: - ConfiguracoesScreen
// Dialeto "graphite premium" portado do Pixio (Rafael 2026-06-16): fundo aurora +
// seções sem caixa + tiles dimensionais + toggle grafite. Estrutura Pixio, cor Vita
// (via PixioCompat). SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
// Navegação preservada (router.goBack via onBack); ordem de menu travada (Rafael
// 2026-04-26). Pushed via AppRouter (.configuracoes).

struct ConfiguracoesScreen: View {
    let authManager: AuthManager

    // Menu order locked by Rafael 2026-04-26 (gold-standard hamburger pattern):
    //   1. Meu perfil  2. Assinatura  3. Matérias  4. Conectores
    //   5. Notificações  6. Convide amigos  7. Ajuda e suporte
    //   8. Termos e privacidade  →  Sair (logout, vermelho, separado)
    var onNavigateToPerfil:           (() -> Void)?
    var onNavigateToAssinatura:       (() -> Void)?
    var onNavigateToDisciplinas:      (() -> Void)?
    var onNavigateToConnections:      (() -> Void)?
    var onNavigateToNotifications:    (() -> Void)?
    var onNavigateToReferral:         (() -> Void)?
    var onNavigateToFeedback:         (() -> Void)?
    var onNavigateToPrivacyDocuments: (() -> Void)?
    var onBack:                       (() -> Void)?

    @AppStorage("vita_haptic_enabled") private var hapticEnabled: Bool = true

    @Environment(\.appContainer) private var container
    @State private var profile: ProfileResponse?

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "VitaAI v\(version) (\(build))"
    }

    /// Linha sob o nome do user no card topo. "Medicina · 3º semestre" quando há
    /// perfil carregado, fallback pro e-mail.
    private var profileSubtitle: String {
        let course = "Medicina"
        if let s = profile?.semester, s > 0 {
            return "\(course) · \(s)º semestre"
        }
        return authManager.userEmail ?? course
    }

    var body: some View {
        ZStack {
            // Fundo graphite premium (port Pixio) — opaco, cobre o shell.
            PixioAuroraBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PixioSpacing.lg) {
                    headerBar
                        .padding(.top, PixioSpacing.sm)

                    userCard

                    // MARK: - Conta (ordem Rafael 2026-04-26)
                    PixioSettingsSection("CONTA") {
                        PixioSettingsRow(icon: "person.crop.circle", accent: PixioColor.premium,
                                         title: "Meu perfil", action: { onNavigateToPerfil?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "star", accent: PixioColor.premium,
                                         title: "Assinatura", action: { onNavigateToAssinatura?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "book", accent: PixioColor.premium,
                                         title: "Matérias", action: { onNavigateToDisciplinas?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "link", accent: PixioColor.premium,
                                         title: "Conectores", action: { onNavigateToConnections?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "bell", accent: PixioColor.premium,
                                         title: "Notificações", action: { onNavigateToNotifications?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "gift", accent: PixioColor.premium,
                                         title: "Convide amigos", action: { onNavigateToReferral?() })
                    }

                    // MARK: - Suporte + Legal + Preferências
                    PixioSettingsSection("SUPORTE") {
                        PixioSettingsRow(icon: "questionmark.circle", accent: PixioColor.premium,
                                         title: "Ajuda e suporte", action: { onNavigateToFeedback?() })
                        PixioSettingsDivider()
                        PixioSettingsRow(icon: "lock.shield", accent: PixioColor.premium,
                                         title: "Termos e privacidade", action: { onNavigateToPrivacyDocuments?() })
                        PixioSettingsDivider()
                        PixioSettingsToggleRow(icon: "iphone.radiowaves.left.and.right",
                                               accent: PixioColor.premium,
                                               title: "Vibração", isOn: $hapticEnabled)
                    }

                    // MARK: - Sair (sempre por último, separado)
                    logoutButton
                        .padding(.top, PixioSpacing.sm)

                    Text(appVersionString)
                        .font(.system(size: 10))
                        .foregroundStyle(PixioColor.textLightFaint.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, PixioSpacing.xs)

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, PixioSpacing.screenH)
                .padding(.top, PixioSpacing.sm)
            }
            .toggleStyle(PixioPremiumToggleStyle())
            .onChange(of: hapticEnabled) { _, _ in
                HapticManager.shared.fire(.light)
            }
        }
        .task { await loadProfile() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Configuracoes")
    }

    @MainActor
    private func loadProfile() async {
        if let p = try? await container.api.getProfile() { profile = p }
    }

    // MARK: - Header (back + título — navegação do Vita preservada)

    private var headerBar: some View {
        HStack(spacing: PixioSpacing.md) {
            Button(action: { onBack?() }) {
                Image(systemName: "chevron.left")
                    .font(PixioTypo.sans(size: 15, weight: .semibold))
                    .foregroundStyle(PixioColor.textLight)
                    .frame(width: 30, height: 30)
                    .pixioRaised(in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backButton")
            .accessibilityLabel("Voltar")

            Text("Configurações")
                .font(PixioTypo.sans(size: 20, weight: .bold))
                .foregroundStyle(PixioColor.textLight)

            Spacer()
        }
    }

    // MARK: - User Card (identidade no topo — clean Pixio)

    private var userCard: some View {
        Button(action: { onNavigateToPerfil?() }) {
            HStack(spacing: PixioSpacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.accent.opacity(0.30), VitaColors.accentDark.opacity(0.18)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(VitaColors.accentHover.opacity(0.18), lineWidth: 1))
                    Text(String((authManager.userName ?? "R").prefix(2)).uppercased())
                        .font(PixioTypo.sans(size: 17, weight: .bold))
                        .foregroundStyle(PixioColor.premiumText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.userName ?? "Estudante")
                        .font(PixioTypo.sans(size: 16, weight: .semibold))
                        .foregroundStyle(PixioColor.textLight)
                    Text(profileSubtitle)
                        .font(PixioTypo.sans(size: 12, weight: .regular))
                        .foregroundStyle(PixioColor.textLightMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("Ver perfil")
                        .font(PixioTypo.sans(size: 12, weight: .medium))
                        .foregroundStyle(PixioColor.premium)
                        .padding(.top, 1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(PixioTypo.sans(size: 13, weight: .semibold))
                    .foregroundStyle(PixioColor.textLightFaint)
            }
            .padding(PixioSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PixioRadius.card, style: .continuous)
                    .fill(PixioColor.cardLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PixioRadius.card, style: .continuous)
                    .strokeBorder(PixioColor.borderLight.opacity(0.6), lineWidth: 0.75)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logout (pílula premium, label vermelho)

    private var logoutButton: some View {
        Button(action: { authManager.logout() }) {
            HStack(spacing: PixioSpacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(PixioTypo.sans(size: 14, weight: .semibold))
                Text("Sair da conta")
                    .font(PixioTypo.sans(size: 14, weight: .semibold))
            }
            .foregroundStyle(PixioColor.negative)
        }
        .buttonStyle(PixioPremiumPillButtonStyle())
        .accessibilityLabel("Sair da conta")
    }
}
