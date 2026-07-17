import SwiftUI
import Sentry

// MARK: - ConnectionsScreen

/// Canonical home for Vita's five connectors. The exact same providers are
/// always available in onboarding and Settings; university detection only
/// pre-fills the learning-portal URL.
struct ConnectionsScreen: View {
    var onPortalConnect: ((String, String?) -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var vm: ConnectorsViewModel?
    @State private var toastState = VitaToastState()
    @State private var statusSelection: ConnectorStatusSelection?
    @State private var portalSelection: PortalConnectionSelection?
    @State private var showWhatsAppSheet = false

    @State private var waPhone = ""
    @State private var waCode = ""
    @State private var waStep = 0
    @State private var waError: String?
    @State private var waSending = false

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(
                title: String(localized: "connections_title"),
                onBack: onBack
            )

            if let vm {
                if vm.hasLoaded {
                    mainContent(vm: vm)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(String(localized: "connections_loading"))
                        .transition(.opacity)
                }
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm?.hasLoaded)
        .onAppear(perform: installViewModelIfNeeded)
        .task(id: "connector-status-refresh") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await vm?.loadAll()
            }
        }
        .sheet(item: $statusSelection) { selection in
            if let vm {
                ConnectorStatusSheet(
                    serviceName: selection.displayName,
                    iconAsset: selection.iconAsset,
                    subtitle: vm.state(for: selection.id).subtitle,
                    lastSync: vm.state(for: selection.id).lastSync,
                    lastSyncAbsolute: vm.state(for: selection.id).lastSyncAbsolute,
                    lastPing: vm.state(for: selection.id).lastPing,
                    isStale: vm.state(for: selection.id).isStale,
                    isExpired: vm.state(for: selection.id).status == .expired,
                    stats: vm.state(for: selection.id).stats.map {
                        ConnectorStat(value: $0.value, label: $0.label)
                    },
                    onSync: {
                        statusSelection = nil
                        Task { await sync(selection.id, vm: vm) }
                    },
                    onDisconnect: {
                        statusSelection = nil
                        Task { await vm.disconnect(selection.id) }
                    }
                )
            }
        }
        .sheet(item: $portalSelection) { selection in
            VitaSheet(
                title: String(
                    format: String(localized: "connections_portal_sheet_title_format"),
                    selection.displayName
                ),
                detents: [.large]
            ) {
                PortalConnectionForm(
                    selection: selection,
                    api: container.api,
                    onConnected: {
                        portalSelection = nil
                        Task { await vm?.loadAll() }
                    }
                )
            }
        }
        .sheet(isPresented: $showWhatsAppSheet) {
            VitaSheet(
                title: String(localized: "onboarding_whatsapp_title"),
                detents: [.medium, .large]
            ) {
                OnboardingWhatsAppLinkContent(
                    phone: $waPhone,
                    code: $waCode,
                    stepIndex: $waStep,
                    sending: $waSending,
                    error: $waError,
                    onSendCode: { Task { await sendWhatsAppCode() } },
                    onVerify: { Task { await verifyWhatsAppCode() } }
                )
                .padding(VitaTokens.Spacing.xl)
            }
        }
        .vitaToastHost(toastState)
        .onChange(of: vm?.toastMessage) { message in
            guard let message else { return }
            toastState.show(message, type: vm?.toastType ?? .success)
            vm?.toastMessage = nil
        }
        .preference(key: ImmersivePreferenceKey.self, value: true)
        .trackScreen("Connections")
    }

    private func installViewModelIfNeeded() {
        guard vm == nil else { return }
        let viewModel = ConnectorsViewModel(
            api: container.api,
            dataManager: container.dataManager
        )
        vm = viewModel
        Task {
            await viewModel.loadAll()
            SentrySDK.reportFullyDisplayed()
        }
    }

    private func mainContent(vm: ConnectorsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
                connectionSummary(vm: vm)

                connectorSection(
                    title: String(localized: "onboarding_connect_portals_section")
                ) {
                    portalCard(
                        id: "canvas",
                        name: "Canvas",
                        iconAsset: "connector-canvas",
                        color: VitaColors.accent,
                        state: vm.canvas,
                        vm: vm
                    )

                    portalCard(
                        id: "moodle",
                        name: "Moodle",
                        iconAsset: "connector-moodle",
                        color: VitaColors.dataAmber,
                        state: vm.moodle,
                        vm: vm
                    )
                }

                connectorSection(
                    title: String(localized: "onboarding_connect_additional_section")
                ) {
                    integrationCard(
                        id: "google_calendar",
                        name: "Google Calendar",
                        iconAsset: "connector-google-calendar",
                        color: VitaColors.dataBlue,
                        state: vm.calendar,
                        vm: vm
                    )

                    integrationCard(
                        id: "google_drive",
                        name: "Google Drive",
                        iconAsset: "connector-google-drive",
                        color: VitaColors.success,
                        state: vm.drive,
                        vm: vm
                    )

                    ConnectorCard(
                        letter: "W",
                        name: "WhatsApp",
                        status: vm.whatsapp.status,
                        color: VitaColors.success,
                        iconAsset: "connector-whatsapp",
                        subtitle: vm.whatsapp.subtitle
                            ?? String(localized: "onboarding_whatsapp_card_subtitle"),
                        lastSync: vm.whatsapp.lastSync,
                        stats: vm.whatsapp.stats,
                        actionAccessibilityIdentifier: "settingsConnectorAction_whatsapp",
                        onConnect: { presentWhatsApp(vm: vm) },
                        onDisconnect: { Task { await vm.disconnect("whatsapp") } },
                        onTapConnected: { presentWhatsApp(vm: vm) }
                    )
                }

                privacyNote
                Spacer().frame(height: VitaTokens.Spacing._4xl)
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.sm)
        }
        .refreshable { await vm.refreshAndSync() }
    }

    private func connectionSummary(vm: ConnectorsViewModel) -> some View {
        HStack(spacing: VitaTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                Text(String(localized: "connections_summary_title"))
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                Text(String(localized: "connections_summary_subtitle"))
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: VitaTokens.Spacing.sm)

            Text("\(vm.connectedCount)/\(vm.totalPortals)")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.accentLight)
                .monospacedDigit()
                .accessibilityLabel(
                    String(
                        format: String(localized: "connections_count_accessibility_format"),
                        vm.connectedCount,
                        vm.totalPortals
                    )
                )
        }
        .padding(VitaTokens.Spacing.lg)
        .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func connectorSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: title.uppercased())
            content()
        }
    }

    private func portalCard(
        id: String,
        name: String,
        iconAsset: String,
        color: Color,
        state: ConnectorState,
        vm: ConnectorsViewModel
    ) -> some View {
        ConnectorCard(
            letter: String(name.prefix(1)),
            name: name,
            status: state.status,
            color: color,
            iconAsset: iconAsset,
            subtitle: portalSubtitle(state: state, vm: vm),
            lastSync: state.lastSync,
            lastPing: state.lastPing,
            isStale: state.isStale,
            stats: state.stats,
            isPrimary: configuredPortalURL(for: id, vm: vm) != nil,
            actionAccessibilityIdentifier: "settingsConnectorAction_\(id)",
            onConnect: { presentPortal(id: id, name: name, vm: vm) },
            onDisconnect: { Task { await vm.disconnect(id) } },
            onTapConnected: {
                statusSelection = ConnectorStatusSelection(
                    id: id,
                    displayName: name,
                    iconAsset: iconAsset
                )
            }
        )
    }

    private func integrationCard(
        id: String,
        name: String,
        iconAsset: String,
        color: Color,
        state: ConnectorState,
        vm: ConnectorsViewModel
    ) -> some View {
        ConnectorCard(
            letter: String(name.prefix(1)),
            name: name,
            status: state.status,
            color: color,
            iconAsset: iconAsset,
            subtitle: state.subtitle,
            lastSync: state.lastSync,
            isStale: state.isStale,
            stats: state.stats,
            actionAccessibilityIdentifier: "settingsConnectorAction_\(id)",
            onConnect: { Task { await vm.connectIntegration(id) } },
            onDisconnect: { Task { await vm.disconnect(id) } },
            onTapConnected: {
                statusSelection = ConnectorStatusSelection(
                    id: id,
                    displayName: name,
                    iconAsset: iconAsset
                )
            }
        )
    }

    private var privacyNote: some View {
        Label {
            Text(String(localized: "connections_privacy_note"))
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.accent)
        }
        .padding(.horizontal, VitaTokens.Spacing.xs)
    }

    private func portalSubtitle(state: ConnectorState, vm: ConnectorsViewModel) -> String {
        if let subtitle = state.subtitle, !subtitle.isEmpty { return subtitle }
        let university = universityDisplayLine(vm: vm)
        return university.isEmpty
            ? String(localized: "onboarding_connect_portal_subtitle")
            : university
    }

    private func universityDisplayLine(vm: ConnectorsViewModel) -> String {
        guard !vm.universityName.isEmpty else { return "" }
        guard !vm.universityCity.isEmpty else { return vm.universityName }
        return "\(vm.universityName) · \(vm.universityCity)"
    }

    private func configuredPortalURL(for portalType: String, vm: ConnectorsViewModel) -> String? {
        if let stateURL = vm.state(for: portalType).instanceUrl, !stateURL.isEmpty {
            return stateURL
        }
        return vm.universityPortals
            .first(where: { $0.portalType == portalType })?
            .instanceUrl
    }

    private func presentPortal(id: String, name: String, vm: ConnectorsViewModel) {
        if let onPortalConnect {
            onPortalConnect(id, configuredPortalURL(for: id, vm: vm))
            return
        }
        portalSelection = PortalConnectionSelection(
            id: id,
            displayName: name,
            iconAsset: "connector-\(id)",
            instanceURL: configuredPortalURL(for: id, vm: vm)
        )
    }

    private func presentWhatsApp(vm: ConnectorsViewModel) {
        waPhone = vm.whatsapp.status == .connected ? "" : waPhone
        waCode = ""
        waStep = vm.whatsapp.status == .connected ? 2 : 0
        waError = nil
        showWhatsAppSheet = true
    }

    private func sendWhatsAppCode() async {
        guard let vm else { return }
        waSending = true
        waError = nil
        do {
            try await vm.linkWhatsApp(phone: waPhone)
            waStep = 1
        } catch APIError.serverError(let code) where code == 429 {
            waError = String(localized: "onboarding_whatsapp_rate_limit_error")
        } catch APIError.serverError(let code) where code == 400 {
            waError = String(localized: "onboarding_whatsapp_phone_error")
        } catch {
            waError = String(localized: "onboarding_whatsapp_send_error")
        }
        waSending = false
    }

    private func verifyWhatsAppCode() async {
        guard let vm else { return }
        waSending = true
        waError = nil
        do {
            try await vm.verifyWhatsApp(code: waCode)
            waStep = 2
        } catch {
            waError = String(localized: "onboarding_whatsapp_verify_error")
        }
        waSending = false
    }

    private func sync(_ id: String, vm: ConnectorsViewModel) async {
        switch id {
        case "canvas": await vm.syncCanvas()
        case "moodle": await vm.syncMoodle()
        case "google_calendar": await vm.syncCalendar()
        case "google_drive": await vm.syncDrive()
        default: break
        }
    }
}

// MARK: - Portal connection form

private struct PortalConnectionForm: View {
    let selection: PortalConnectionSelection
    let api: VitaAPI
    let onConnected: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var instanceURL: String
    @State private var token = ""
    @State private var errorMessage: String?
    @State private var isConnecting = false

    init(
        selection: PortalConnectionSelection,
        api: VitaAPI,
        onConnected: @escaping () -> Void
    ) {
        self.selection = selection
        self.api = api
        self.onConnected = onConnected
        _instanceURL = State(initialValue: selection.instanceURL ?? "")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
                portalIdentity

                OnboardingTextInput(
                    value: $instanceURL,
                    label: String(localized: "onboarding_portal_url_label"),
                    placeholder: String(localized: "onboarding_portal_url_placeholder"),
                    leadingSystemImage: "link",
                    keyboardType: .URL,
                    autocapitalization: .never,
                    autocorrectionDisabled: true,
                    accessibilityIdentifier: "settingsPortalURLInput_\(selection.id)"
                )

                VitaButton(
                    text: String(
                        format: String(localized: "onboarding_portal_open"),
                        selection.displayName
                    ),
                    action: openPortal,
                    variant: .secondary,
                    size: .md,
                    isEnabled: normalizedURL != nil,
                    leadingSystemImage: "safari",
                    fillsWidth: true
                )

                tutorial

                OnboardingTextInput(
                    value: $token,
                    label: String(localized: "onboarding_portal_token_label"),
                    placeholder: String(localized: "onboarding_portal_token_placeholder"),
                    leadingSystemImage: "key",
                    errorMessage: errorMessage,
                    autocapitalization: .never,
                    autocorrectionDisabled: true,
                    isSecure: true,
                    accessibilityIdentifier: "settingsPortalTokenInput_\(selection.id)"
                )

                VitaButton(
                    text: String(localized: "onboarding_portal_connect"),
                    action: { Task { await connect() } },
                    variant: .primary,
                    size: .md,
                    isEnabled: normalizedURL != nil && !trimmedToken.isEmpty,
                    isLoading: isConnecting,
                    fillsWidth: true
                )
                .accessibilityIdentifier("settingsPortalSubmit_\(selection.id)")
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.vertical, VitaTokens.Spacing.lg)
        }
    }

    private var portalIdentity: some View {
        HStack(alignment: .top, spacing: VitaTokens.Spacing.md) {
            Image(selection.iconAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: VitaTokens.Radius.md,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                Text(selection.displayName)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(String(localized: "onboarding_portal_open_hint"))
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
        }
    }

    private var tutorial: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text(String(localized: "connections_token_help_title"))
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)

            ForEach(Array(tutorialSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: VitaTokens.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.accent)
                        .frame(width: 20, height: 20)
                        .background(VitaColors.accent.opacity(0.12), in: Circle())

                    Text(step)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var tutorialSteps: [String] {
        if selection.id == "canvas" {
            return [
                String(localized: "onboarding_canvas_step_1"),
                String(localized: "onboarding_canvas_step_2"),
                String(localized: "onboarding_canvas_step_3"),
                String(localized: "onboarding_canvas_step_4"),
                String(localized: "onboarding_canvas_step_5"),
                String(localized: "onboarding_canvas_step_6"),
            ]
        }
        return [
            String(localized: "onboarding_moodle_step_1"),
            String(localized: "onboarding_moodle_step_2"),
            String(localized: "onboarding_moodle_step_3"),
            String(localized: "onboarding_moodle_step_4"),
        ]
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedURL: URL? {
        let entered = instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else { return nil }
        let normalized = entered.hasPrefix("http") ? entered : "https://\(entered)"
        guard let url = URL(string: normalized), url.host != nil else { return nil }
        return url
    }

    private func openPortal() {
        guard let normalizedURL else { return }
        openURL(normalizedURL)
    }

    private func connect() async {
        guard let normalizedURL, !trimmedToken.isEmpty else { return }
        isConnecting = true
        errorMessage = nil

        do {
            let response: CanvasConnectResponse
            if selection.id == "canvas" {
                response = try await api.connectCanvas(
                    accessToken: trimmedToken,
                    instanceUrl: normalizedURL.absoluteString
                )
            } else {
                response = try await api.connectMoodle(
                    accessToken: trimmedToken,
                    instanceUrl: normalizedURL.absoluteString
                )
            }

            guard response.success else {
                errorMessage = response.localizedErrorMessage
                isConnecting = false
                return
            }

            do {
                if selection.id == "canvas" {
                    if let connectionID = response.connectionId {
                        _ = try await api.syncCanvas(connectionId: connectionID)
                    } else {
                        _ = try await api.syncCanvas()
                    }
                } else {
                    _ = try await api.syncMoodle(connectionId: response.connectionId)
                }
            } catch {
                NSLog(
                    "[Connections] Initial %@ sync deferred: %@",
                    selection.id,
                    error.localizedDescription
                )
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onConnected()
        } catch {
            errorMessage = String(localized: "onboarding_portal_connection_error")
            isConnecting = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct ConnectorStatusSelection: Identifiable {
    let id: String
    let displayName: String
    let iconAsset: String
}

private struct PortalConnectionSelection: Identifiable {
    let id: String
    let displayName: String
    let iconAsset: String
    let instanceURL: String?
}

enum ConnectionItemStatus: Equatable {
    case loading
    case connected
    case expired
    case disconnected
}
