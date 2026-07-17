import SwiftUI
import UIKit
import SafariServices

// MARK: - Connect Step — Canvas/Moodle API token entry

struct ConnectStep: View {
    var university: University?
    var allPortalTypes: [PortalTypeInfo]
    var api: VitaAPI?
    var canvasStatus: ConnectionItemStatus
    var moodleStatus: ConnectionItemStatus
    var calendarStatus: ConnectionItemStatus
    var driveStatus: ConnectionItemStatus
    var whatsappStatus: ConnectionItemStatus
    var whatsappSubtitle: String?
    @Binding var whatsappPhone: String
    @Binding var whatsappCode: String
    @Binding var whatsappStep: Int
    @Binding var whatsappSending: Bool
    @Binding var whatsappError: String?
    var onConnect: ((String) -> Void)?
    var onDisconnect: ((String) -> Void)?
    var onLoad: (() async -> Void)?
    let onSendWhatsAppCode: () -> Void
    let onVerifyWhatsAppCode: () -> Void

    @State private var selectedPortal: PortalChoice?
    @State private var token = ""
    @State private var instanceURL = ""
    @State private var isConnecting = false
    @State private var connectedPortals = Set<PortalChoice>()
    @State private var isWhatsAppExpanded = false
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

        var iconAsset: String {
            "connector-\(apiType)"
        }

        var tutorialSteps: [String] {
            switch self {
            case .canvas:
                return [
                    String(localized: "onboarding_canvas_step_1"),
                    String(localized: "onboarding_canvas_step_2"),
                    String(localized: "onboarding_canvas_step_3"),
                    String(localized: "onboarding_canvas_step_4"),
                    String(localized: "onboarding_canvas_step_5"),
                    String(localized: "onboarding_canvas_step_6"),
                ]
            case .moodle:
                return [
                    String(localized: "onboarding_moodle_step_1"),
                    String(localized: "onboarding_moodle_step_2"),
                    String(localized: "onboarding_moodle_step_3"),
                    String(localized: "onboarding_moodle_step_4"),
                ]
            }
        }
    }

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.xl) {
            if let portal = selectedPortal {
                tokenEntry(portal: portal)
            } else {
                portalPicker
                additionalConnectors
            }
        }
        .task { await onLoad?() }
    }

    // MARK: - Portal picker

    private var portalPicker: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            sectionLabel(String(localized: "onboarding_connect_portals_section"))

            ForEach(PortalChoice.allCases, id: \.rawValue) { choice in
                ConnectorCard(
                    letter: String(choice.rawValue.prefix(1)),
                    name: choice.rawValue,
                    status: portalStatus(choice),
                    color: University.color(for: choice.apiType),
                    iconAsset: choice.iconAsset,
                    subtitle: String(localized: "onboarding_connect_portal_subtitle"),
                    isPrimary: !configuredPortalURL(for: choice).isEmpty,
                    actionAccessibilityIdentifier: "onboardingPortal_\(choice.apiType)",
                    onConnect: { selectPortal(choice) },
                    onDisconnect: {
                        connectedPortals.remove(choice)
                        onDisconnect?(choice.apiType)
                    }
                )
            }
        }
    }

    // MARK: - Optional connectors

    private var additionalConnectors: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            sectionLabel(String(localized: "onboarding_connect_additional_section"))

            ConnectorCard(
                letter: "G",
                name: "Google Calendar",
                status: calendarStatus,
                color: VitaColors.dataBlue,
                iconAsset: "connector-google-calendar",
                iconCornerRadius: VitaTokens.Radius.md,
                actionAccessibilityIdentifier: "onboardingConnectorAction_google_calendar",
                onConnect: { onConnect?("google_calendar") },
                onDisconnect: { onDisconnect?("google_calendar") }
            )

            ConnectorCard(
                letter: "G",
                name: "Google Drive",
                status: driveStatus,
                color: VitaColors.success,
                iconAsset: "connector-google-drive",
                iconCornerRadius: VitaTokens.Radius.md,
                actionAccessibilityIdentifier: "onboardingConnectorAction_google_drive",
                onConnect: { onConnect?("google_drive") },
                onDisconnect: { onDisconnect?("google_drive") }
            )

            ConnectorCard(
                letter: "W",
                name: "WhatsApp",
                status: effectiveWhatsAppStatus,
                color: VitaColors.success,
                iconAsset: "connector-whatsapp",
                iconCornerRadius: VitaTokens.Radius.md,
                subtitle: whatsappSubtitle ?? String(localized: "onboarding_whatsapp_card_subtitle"),
                actionAccessibilityIdentifier: "onboardingConnectorAction_whatsapp",
                onConnect: toggleWhatsApp,
                onDisconnect: { onDisconnect?("whatsapp") },
                onTapConnected: toggleWhatsApp
            )

            if isWhatsAppExpanded || whatsappStep > 0 {
                OnboardingWhatsAppLinkContent(
                    phone: $whatsappPhone,
                    code: $whatsappCode,
                    stepIndex: $whatsappStep,
                    sending: $whatsappSending,
                    error: $whatsappError,
                    onSendCode: onSendWhatsAppCode,
                    onVerify: onVerifyWhatsAppCode
                )
                .padding(VitaTokens.Spacing.lg)
                .background {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                        .fill(VitaColors.glassBg.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var effectiveWhatsAppStatus: ConnectionItemStatus {
        whatsappStep == 2 ? .connected : whatsappStatus
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.sectionLabel)
            .tracking(0.8)
            .padding(.leading, VitaTokens.Spacing.xs)
    }

    private func toggleWhatsApp() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isWhatsAppExpanded.toggle()
        }
    }

    private func portalStatus(_ portal: PortalChoice) -> ConnectionItemStatus {
        if connectedPortals.contains(portal) { return .connected }
        switch portal {
        case .canvas: return canvasStatus
        case .moodle: return moodleStatus
        }
    }

    private func selectPortal(_ portal: PortalChoice) {
        instanceURL = configuredPortalURL(for: portal)
        withAnimation(.snappy) {
            selectedPortal = portal
        }
    }

    // MARK: - Token entry

    private func tokenEntry(portal: PortalChoice) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Button {
                    withAnimation(.snappy) {
                        selectedPortal = nil
                        token = ""
                        instanceURL = ""
                        errorMessage = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(
                            width: VitaTokens.Spacing._3xl,
                            height: VitaTokens.Spacing._3xl
                        )
                        .background(VitaColors.glassBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "onboarding_a11y_back"))

                Image(portal.iconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: VitaTokens.Spacing._3xl,
                        height: VitaTokens.Spacing._3xl
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: VitaTokens.Radius.sm,
                            style: .continuous
                        )
                    )

                Text(portal.rawValue)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }

            if configuredPortalURL(for: portal).isEmpty {
                OnboardingTextInput(
                    value: $instanceURL,
                    label: String(localized: "onboarding_portal_url_label"),
                    placeholder: String(localized: "onboarding_portal_url_placeholder"),
                    leadingSystemImage: "link",
                    keyboardType: .URL,
                    autocapitalization: .never,
                    autocorrectionDisabled: true,
                    accessibilityIdentifier: "onboardingPortalURLInput"
                )
            }

            VitaButton(
                text: String(
                    format: String(localized: "onboarding_portal_open"),
                    portal.rawValue
                ),
                action: { openPortal(portal: portal) },
                variant: .secondary,
                size: .md,
                isEnabled: !portalURL(for: portal).isEmpty,
                leadingSystemImage: "safari",
                fillsWidth: true
            )

            Text(String(localized: "onboarding_portal_open_hint"))
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                ForEach(Array(portal.tutorialSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: VitaTokens.Spacing.sm) {
                        Text("\(index + 1)")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.accent)
                            .frame(
                                width: VitaTokens.Spacing._2xl,
                                height: VitaTokens.Spacing._2xl
                            )
                            .background(Circle().fill(VitaColors.accent.opacity(0.12)))
                        Text(step)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            OnboardingTextInput(
                value: $token,
                label: String(localized: "onboarding_portal_token_label"),
                placeholder: String(localized: "onboarding_portal_token_placeholder"),
                leadingSystemImage: "key",
                errorMessage: errorMessage,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                isSecure: true,
                accessibilityIdentifier: "onboardingPortalTokenInput"
            )

            VitaButton(
                text: String(localized: "onboarding_portal_connect"),
                action: { Task { await connectWithToken(portal: portal) } },
                variant: .primary,
                size: .md,
                isEnabled: canConnect,
                isLoading: isConnecting,
                fillsWidth: true
            )
        }
        .padding(VitaTokens.Spacing.xl)
        .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    // MARK: - Logic

    private var canConnect: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !portalURL(for: selectedPortal ?? .canvas).isEmpty
    }

    @MainActor
    private func openPortal(portal: PortalChoice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let baseURL = portalURL(for: portal)
        if let url = URL(string: baseURL), !baseURL.isEmpty {
            presentBrowser(url)
        }
    }

    @MainActor
    private func presentBrowser(_ url: URL) {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else { return }

        let presenter = root.presentedViewController ?? root
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: url, configuration: configuration)
        safari.preferredControlTintColor = UIColor(VitaColors.accent)
        safari.dismissButtonStyle = .cancel
        safari.modalPresentationStyle = .pageSheet
        presenter.present(safari, animated: true)
    }

    private func portalURL(for portal: PortalChoice) -> String {
        let enteredURL = instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !enteredURL.isEmpty {
            return enteredURL.hasPrefix("http") ? enteredURL : "https://\(enteredURL)"
        }
        return configuredPortalURL(for: portal)
    }

    private func configuredPortalURL(for portal: PortalChoice) -> String {
        if let portals = university?.portals,
           let match = portals.first(where: { $0.portalType == portal.apiType }),
           let url = match.instanceUrl, !url.isEmpty {
            return url.hasPrefix("http") ? url : "https://\(url)"
        }
        return ""
    }

    private func connectWithToken(portal: PortalChoice) async {
        guard canConnect, let api else { return }
        await MainActor.run {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
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
                    connectedPortals.insert(portal)
                    selectedPortal = nil
                    token = ""
                    instanceURL = ""
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    errorMessage = result.localizedErrorMessage
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                isConnecting = false
            }
            if result.success {
                Task {
                    do {
                        switch portal {
                        case .canvas:
                            if let connectionId = result.connectionId {
                                _ = try await api.syncCanvas(connectionId: connectionId)
                            }
                        case .moodle:
                            _ = try await api.syncMoodle(connectionId: result.connectionId)
                        }
                    } catch {
                        NSLog("[ConnectStep] Initial %@ sync deferred: %@", portal.rawValue, error.localizedDescription)
                    }
                    await onLoad?()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "onboarding_portal_connection_error")
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
