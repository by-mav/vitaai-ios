import SwiftUI
import Sentry

// MARK: - PrivacySettingsScreen
//
// Shell §5.2 + Rafael 2026-04-25: 4 switches que CONTROLAM comportamento real
// (diferente de PrivacyDocumentsScreen que só EXPLICA o que coletamos).
//
// Persiste via /api/user/privacy-preferences (backend commit 10a3dde do
// vitaai-web). Cada toggle dispara PATCH debounced. Falha → reverte UI +
// mostra erro inline.
//
// Sobre ads: Vita NÃO tem ads (decisão produto Rafael 2026-04-25). Sem
// switch "anúncios personalizados".

struct PrivacySettingsScreen: View {
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var prefs: PrivacyPreferences?
    @State private var isLoading = true
    @State private var pendingUpdates: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBar
                    .padding(.top, 8)

                introSection
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                if isLoading && prefs == nil {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let prefs {
                    sectionLabel("Coleta e visibilidade")
                    VitaGlassCard {
                        VStack(spacing: 0) {
                            privacyToggle(
                                icon: "location",
                                label: "Recursos de localização",
                                desc: "Permite o app pedir GPS pra features opcionais (ex: encontrar grupos de estudo na sua faculdade)",
                                key: "location",
                                isOn: prefs.location
                            )
                            rowDivider
                            privacyToggle(
                                icon: "person.2",
                                label: "Atividade pública",
                                desc: "Outros estudantes veem suas conquistas, streak e sessões de estudo",
                                key: "publicProfile",
                                isOn: prefs.publicProfile
                            )
                            rowDivider
                            privacyToggle(
                                icon: "trophy",
                                label: "Ranking público",
                                desc: "Você aparece no leaderboard semanal. OFF te tira do ranking visível",
                                key: "publicLeaderboard",
                                isOn: prefs.publicLeaderboard
                            )
                        }
                    }
                    .padding(.horizontal, 14)

                    sectionLabel("Diagnóstico")
                    VitaGlassCard {
                        privacyToggle(
                            icon: "ant.circle",
                            label: "Telemetria de erros",
                            desc: "Crash reports anônimos via Sentry. Ajuda a corrigir bugs antes que afetem mais alunos",
                            key: "telemetry",
                            isOn: prefs.telemetry
                        )
                    }
                    .padding(.horizontal, 14)
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                }

                lgpdFooter
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .trackScreen("PrivacySettings")
        .task { await load() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backButton")

                Text("Configurações de privacidade")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Você decide o que mostrar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("Cada switch aqui muda algo concreto: visibilidade do seu perfil, presença no ranking, e quanto a gente consegue debugar problemas técnicos. Sem ads, nunca — o Vita é Pro/Premium pago.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .lineSpacing(2)
        }
    }

    // MARK: - Toggle row

    private func privacyToggle(icon: String, label: String, desc: String, key: String, isOn: Bool) -> some View {
        let binding = Binding<Bool>(
            get: { isOn },
            set: { newValue in
                Task { await persist(key: key, value: newValue) }
            }
        )

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accentHover.opacity(0.18),
                                VitaColors.accentDark.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.80))
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .lineSpacing(1)
            }

            Spacer()

            if pendingUpdates.contains(key) {
                ProgressView()
                    .controlSize(.small)
                    .tint(VitaColors.accent)
            } else {
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .tint(VitaColors.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VitaColors.dataRed.opacity(0.85))
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.dataRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lgpdFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LGPD (Lei 13.709/2018) garante que você possa ajustar isso a qualquer momento. Mudanças têm efeito imediato.")
                .font(.system(size: 10.5))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                .lineSpacing(2)
            Text("DPO: privacy@vitaai.app")
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Logic

    private func load() async {
        do {
            let result = try await container.api.getPrivacyPreferences()
            prefs = result
        } catch {
            errorMessage = "Não foi possível carregar suas preferências. Tente novamente em instantes."
        }
        isLoading = false
    }

    private func persist(key: String, value: Bool) async {
        guard !pendingUpdates.contains(key) else { return }
        guard let current = prefs else { return }
        pendingUpdates.insert(key)
        defer { pendingUpdates.remove(key) }

        // Optimistic update local
        var optimistic = current
        switch key {
        case "location": optimistic.location = value
        case "publicProfile": optimistic.publicProfile = value
        case "publicLeaderboard": optimistic.publicLeaderboard = value
        case "telemetry":
            optimistic.telemetry = value
            if !value { SentrySDK.close() }
        default: return
        }
        prefs = optimistic
        HapticManager.shared.fire(.light)

        let body = UpdatePrivacyPreferencesRequest(
            location: key == "location" ? value : nil,
            publicProfile: key == "publicProfile" ? value : nil,
            publicLeaderboard: key == "publicLeaderboard" ? value : nil,
            telemetry: key == "telemetry" ? value : nil
        )

        do {
            let updated = try await container.api.updatePrivacyPreferences(body)
            prefs = updated
            errorMessage = nil
        } catch {
            prefs = current  // reverte ao snapshot antes do toggle
            errorMessage = "Não foi possível salvar. Tenta novamente em alguns segundos."
        }
    }
}
