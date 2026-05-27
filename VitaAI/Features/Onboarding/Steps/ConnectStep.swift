import SwiftUI
import UIKit

// MARK: - Connect Step — Canvas/Moodle API token entry

struct ConnectStep: View {
    var university: University?
    var allPortalTypes: [PortalTypeInfo]
    var api: VitaAPI?
    var onConnect: ((String) -> Void)?

    @State private var selectedPortal: PortalChoice?
    @State private var token = ""
    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var errorMessage: String?

    enum PortalChoice: String, CaseIterable {
        case canvas = "Canvas"
        case moodle = "Moodle"

        var apiType: String {
            switch self {
            case .canvas: return "canvas"
            case .moodle: return "moodle"
            }
        }

        var tokenPlaceholder: String {
            switch self {
            case .canvas: return "Cole seu token aqui"
            case .moodle: return "Cole seu token aqui"
            }
        }

        var tutorialSteps: [String] {
            switch self {
            case .canvas:
                return [
                    "Abra o Canvas da sua faculdade no navegador",
                    "Vá em Conta → Configurações",
                    "Role até \"Tokens de Acesso\"",
                    "Clique em \"+ Novo Token de Acesso\"",
                    "Dê um nome (ex: Vita) e clique em Gerar",
                    "Copie o token e cole aqui",
                ]
            case .moodle:
                return [
                    "Abra o Moodle da sua faculdade no navegador",
                    "Vá em Preferências → Chaves de Segurança",
                    "Clique em \"Redefinir\" pra gerar um token",
                    "Copie o token e cole aqui",
                ]
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if isConnected, let portal = selectedPortal {
                connectedView(portal: portal)
            } else if let portal = selectedPortal {
                tokenEntry(portal: portal)
            } else {
                portalPicker
            }

            if !isConnected && selectedPortal == nil {
                ConnectorCard(
                    letter: "G", name: "Google Calendar",
                    status: .disconnected,
                    color: Color(red: 0.26, green: 0.52, blue: 0.96),
                    onConnect: { onConnect?("google_calendar") }
                )
                ConnectorCard(
                    letter: "G", name: "Google Drive",
                    status: .disconnected,
                    color: Color(red: 0.13, green: 0.59, blue: 0.33),
                    onConnect: { onConnect?("google_drive") }
                )
            }
        }
    }

    // MARK: - Portal picker

    private var portalPicker: some View {
        VStack(spacing: 10) {
            ForEach(PortalChoice.allCases, id: \.rawValue) { choice in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPortal = choice
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(University.color(for: choice.apiType).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(University.letter(for: choice.apiType))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(University.color(for: choice.apiType))
                        }
                        Text(choice.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Token entry

    private func tokenEntry(portal: PortalChoice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPortal = nil
                        token = ""
                        errorMessage = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(portal.rawValue)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            // Open portal button (app or Safari fallback)
            Button {
                openPortal(portal: portal)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(University.color(for: portal.apiType).opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(University.color(for: portal.apiType))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Abrir \(portal.rawValue)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Abre o app (se tiver) ou no Safari")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(University.color(for: portal.apiType).opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(University.color(for: portal.apiType).opacity(0.15), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // Video tutorial placeholder
            Button {
                // TODO: abrir vídeo tutorial
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.accent.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(VitaColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Como pegar seu token")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Veja o passo a passo em 30 segundos")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VitaColors.accent.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.accent.opacity(0.12), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // Step-by-step text instructions
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(portal.tutorialSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VitaColors.accent)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(VitaColors.accent.opacity(0.12)))
                        Text(step)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // Token input
            VStack(alignment: .leading, spacing: 6) {
                Text("TOKEN DE ACESSO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.8)
                TextField(portal.tokenPlaceholder, text: $token)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                errorMessage != nil ? Color.red.opacity(0.3) : Color.white.opacity(0.08),
                                lineWidth: 1
                            ))
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red.opacity(0.8))
            }

            Button {
                Task { await connectWithToken(portal: portal) }
            } label: {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView().tint(VitaColors.surface).scaleEffect(0.8)
                    }
                    Text(isConnecting ? "Conectando..." : "Conectar")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canConnect ? .white : .white.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canConnect || isConnecting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Connected

    private func connectedView(portal: PortalChoice) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(VitaColors.dataGreen.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(VitaColors.dataGreen)
            }

            Text("\(portal.rawValue) conectado!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Vita já tá puxando seus dados")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(VitaColors.dataGreen.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.dataGreen.opacity(0.12), lineWidth: 1))
        )
    }

    // MARK: - Logic

    private var canConnect: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Abre o portal no Safari na rota de login certa pro SSO funcionar.
    /// Canvas: /login/google (SSO Google, padrão das faculdades brasileiras)
    /// Moodle: /login/index.php
    private func openPortal(portal: PortalChoice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let baseURL = portalURL(for: portal)
        guard !baseURL.isEmpty else {
            let fallback = portal == .canvas
                ? "https://www.instructure.com"
                : "https://moodle.org"
            if let u = URL(string: fallback) { UIApplication.shared.open(u) }
            return
        }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let loginPath: String = {
            switch portal {
            case .canvas: return "/login/google"
            case .moodle: return "/login/index.php"
            }
        }()
        if let url = URL(string: trimmed + loginPath) {
            UIApplication.shared.open(url, options: [.universalLinksOnly: false])
        }
    }

    private func portalURL(for portal: PortalChoice) -> String {
        if let portals = university?.portals,
           let match = portals.first(where: { $0.portalType == portal.apiType }),
           let url = match.instanceUrl, !url.isEmpty {
            return url.hasPrefix("http") ? url : "https://\(url)"
        }
        return ""
    }

    private func connectWithToken(portal: PortalChoice) async {
        guard canConnect, let api else { return }
        isConnecting = true
        errorMessage = nil

        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let instanceUrl = portalURL(for: portal)

        do {
            let result: CanvasConnectResponse
            switch portal {
            case .canvas:
                result = try await api.connectCanvas(accessToken: cleanToken, instanceUrl: instanceUrl)
            case .moodle:
                result = try await api.connectMoodle(accessToken: cleanToken, instanceUrl: instanceUrl)
            }

            await MainActor.run {
                if result.success {
                    withAnimation(.spring(response: 0.4)) { isConnected = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    errorMessage = result.error ?? "Token inválido"
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                isConnecting = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erro de conexão. Verifique o token."
                isConnecting = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Portal Type Info (derived from API data)

struct PortalTypeInfo: Identifiable {
    var id: String { type }
    let type: String
    let displayName: String
    let letter: String
    let color: Color

    init(type: String) {
        self.type = type
        self.displayName = University.displayName(for: type)
        self.letter = University.letter(for: type)
        self.color = University.color(for: type)
    }
}
