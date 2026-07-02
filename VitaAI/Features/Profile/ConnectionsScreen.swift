import SwiftUI
import Sentry

// MARK: - ConnectionsScreen
// University-aware connector list â€” mirrors the onboarding ConnectStep UX.
// Shows the student's university portals (from API), Google integrations, and
// an expandable "Outros portais" section for portal types not detected.

struct ConnectionsScreen: View {
    /// Optional callback for future token/OAuth connectors not handled inline.
    var onPortalConnect: ((String, String?) -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var vm: ConnectorsViewModel?
    @State private var toastState = VitaToastState()

    // Sheet visibility
    @State private var activeSheet: String?
    @State private var showAllPortals = false

    @State private var showCanvasTokenSheet = false
    @State private var canvasInstanceUrl: String = ""

    // WhatsApp linking flow
    @State private var showWhatsAppSheet = false
    @State private var waPhone: String = ""
    @State private var waCode: String = ""
    @State private var waStep: Int = 0
    @State private var waError: String?
    @State private var waSending = false

    // Design tokens
    private let goldSubtle = VitaColors.accentLight

    private let allPortalTypes: [PortalTypeInfo] = [
        PortalTypeInfo(type: "canvas"),
        PortalTypeInfo(type: "moodle"),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Starry ambient background (same as all screens)
            if let vm {
                mainContent(vm: vm)
            } else {
                DashboardSkeleton()
            }
        }
        .onAppear {
            if vm == nil {
                let viewModel = ConnectorsViewModel(api: container.api, dataManager: container.dataManager)
                vm = viewModel
                Task {
                    await viewModel.loadAll()
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .task(id: "refresh-timer") {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await vm?.loadPortalConnections()
            }
        }
        // Status sheet for connected portals
        .sheet(item: $activeSheet) { sheetId in
            VitaSheet {
                sheetContent(for: sheetId)
            }
        }
        // Canvas token sheet â€” AddTokenSheet (substitui WebView, pivot 2026-05-07)
        .sheet(isPresented: $showCanvasTokenSheet) {
            AddTokenSheet()
                .environmentObject(container)
                .presentationDetents([.large])
        }
        // WhatsApp linking sheet
        // WhatsApp linking sheet
        .sheet(isPresented: $showWhatsAppSheet) {
            VitaSheet(title: "Vincular WhatsApp") {
                whatsAppLinkSheet
            }
        }
        .vitaToastHost(toastState)
        .onChange(of: vm?.toastMessage) { msg in
            if let msg {
                toastState.show(msg, type: vm?.toastType ?? .success)
                vm?.toastMessage = nil
            }
        }
        .trackScreen("Connections")
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: ConnectorsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Connected count card
                connectedCountCard(vm: vm)
                    .padding(.horizontal, 14)

                // Institucional section
                institucionalSection(vm: vm)

                // Integracoes section
                sectionLabel("INTEGRACOES")
                    .padding(.top, 18)

                VStack(spacing: 8) {
                    integrationCard(
                        letter: "G", name: "Google Calendar",
                        color: Color(red: 0.26, green: 0.52, blue: 0.96),
                        connectorId: "google_calendar",
                        state: vm.calendar, vm: vm,
                        iconAsset: "mascot-google-calendar"
                    )
                    integrationCard(
                        letter: "G", name: "Google Drive",
                        color: Color(red: 0.13, green: 0.59, blue: 0.33),
                        connectorId: "google_drive",
                        state: vm.drive, vm: vm,
                        iconAsset: "mascot-google-drive"
                    )
                    integrationCard(
                        letter: "S", name: "Spotify",
                        color: Color(red: 0.11, green: 0.73, blue: 0.33),
                        connectorId: "spotify",
                        state: vm.spotify, vm: vm,
                        iconAsset: "mascot-spotify"
                    )
                    ConnectorCard(
                        letter: "W",
                        name: "WhatsApp",
                        status: vm.whatsapp.status,
                        color: Color(red: 0.15, green: 0.68, blue: 0.38),
                        iconAsset: "mascot-whatsapp",
                        lastSync: vm.whatsapp.lastSync,
                        stats: vm.whatsapp.stats,
                        onConnect: {
                            waStep = 0; waPhone = ""; waCode = ""; waError = nil
                            showWhatsAppSheet = true
                        },
                        onDisconnect: { Task { await vm.disconnect("whatsapp") } },
                        onTapConnected: {
                            waStep = 0; waPhone = vm.whatsapp.subtitle ?? ""; waCode = ""; waError = nil
                            showWhatsAppSheet = true
                        }
                    )
                }
                .padding(.horizontal, 14)

                // Como funciona
                sectionLabel("COMO FUNCIONA")
                    .padding(.top, 20)

                comoFunciona
                    .padding(14)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 14)

                Spacer().frame(height: 120)
            }
            .padding(.top, 8)
        }
        .refreshable { await vm.refreshAndSync() }
    }

    // MARK: - Institucional Section

    @ViewBuilder
    private func institucionalSection(vm: ConnectorsViewModel) -> some View {
        let hasUniversity = !vm.universityName.isEmpty
        // Fallback: se o catalogo getUniversities() nao retornou portals (universidade fora do
        // catalogo ou backend incompleto), constroi portais a partir do state real do VM.
        // Isso garante que usuario com conexao ativa sempre ve o card, independente do catalogo.
        let fallbackPortals: [UniversityPortal] = {
            guard vm.universityPortals.isEmpty else { return [] }
            var result: [UniversityPortal] = []
            if vm.canvas.status != .disconnected {
                result.append(UniversityPortal(
                    id: "fallback-canvas",
                    portalType: "canvas",
                    portalName: "Canvas",
                    instanceUrl: vm.canvas.instanceUrl
                ))
            }
            return result
        }()
        let supportedTypes: Set<String> = ["canvas", "moodle"]
        let detectedPortals = (vm.universityPortals.isEmpty ? fallbackPortals : vm.universityPortals)
            .filter { supportedTypes.contains($0.portalType) }
        let detectedTypes = Set(detectedPortals.map(\.portalType))
        let otherPortals = allPortalTypes.filter { !detectedTypes.contains($0.type) }

        // Section header
        sectionLabel("INSTITUCIONAL")
            .padding(.top, 18)

        // University subtitle (name + city from API)
        if hasUniversity {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.system(size: 11))
                    .foregroundColor(goldSubtle.opacity(0.40))
                Text(universityDisplayLine(vm: vm))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }

        VStack(spacing: 8) {
            if !detectedPortals.isEmpty {
                // Detected portals for this university
                ForEach(detectedPortals, id: \.id) { portal in
                    let connState = vm.state(for: portal.portalType)
                    ConnectorCard(
                        letter: University.letter(for: portal.portalType),
                        name: portal.displayName.isEmpty
                            ? University.displayName(for: portal.portalType)
                            : portal.displayName,
                        status: connState.status,
                        color: University.color(for: portal.portalType),
                        lastSync: connState.lastSync,
                        lastPing: connState.lastPing,
                        isStale: connState.isStale,
                        stats: connState.stats,
                        isPrimary: portal.isPrimary,
                        onConnect: { handleConnect(portalType: portal.portalType, instanceUrl: portal.instanceUrl) },
                        onDisconnect: { Task { await vm.disconnect(portal.portalType) } },
                        onTapConnected: { activeSheet = portal.portalType }
                    )
                }
            } else if !hasUniversity {
                // No university â€” show hint
                noUniversityHint
            }

            // "Outros portais" toggle
            // "Outros portais" sÃ³ faz sentido quando NÃƒO temos faculdade detectada
            // (user sem onboarding completo). Quando uni estÃ¡ conhecida, mostrar
            // apenas os portais que ELA usa â€” clicar Moodle/SIGAA sem URL leva
            // pra tela "URL nÃ£o configurada" e quebra UX. Rafael 2026-04-27:
            // "porque nao colocaram o link de todos conectores para cada
            //  instituicao ... entao nem deveria mostrar esses conectores quando
            //  o usuario nao eh da faculdade que tem eles".
            if !hasUniversity && !otherPortals.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) { showAllPortals.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAllPortals ? "minus.circle" : "plus.circle")
                            .font(.system(size: 13))
                        Text(showAllPortals ? "Ocultar outros portais" : "Outros portais")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: showAllPortals ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if !hasUniversity && showAllPortals {
                ForEach(otherPortals) { portal in
                    let connState = vm.state(for: portal.type)
                    ConnectorCard(
                        letter: portal.letter,
                        name: portal.displayName,
                        status: connState.status,
                        color: portal.color,
                        onConnect: { handleConnect(portalType: portal.type, instanceUrl: nil) },
                        onDisconnect: { Task { await vm.disconnect(portal.type) } },
                        onTapConnected: { activeSheet = portal.type }
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Quando user TEM faculdade mas portal dela nÃ£o estÃ¡ mapeado, o
            // helper hint "meu portal nÃ£o aparece" abre um caminho de feedback
            // sem expor a lista cheia de connectors quebrados.
            if hasUniversity && detectedPortals.isEmpty {
                missingPortalHint
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Missing Portal Hint
    // Mostrado quando user tem uni configurada mas o catÃ¡logo
    // university_portals nÃ£o tem nenhum portal mapeado pra ela. Em vez de
    // listar 8 conectores genÃ©ricos sem URL (UX quebrada), pede contato.
    private var missingPortalHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 22))
                .foregroundColor(goldSubtle.opacity(0.40))
            Text("Portal da sua faculdade ainda nÃ£o mapeado")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Text("Estamos adicionando 351+ faculdades. Avise no chat da Vita qual Ã© o portal da sua e adicionamos rÃ¡pido.")
                .font(.system(size: 11))
                .foregroundColor(goldSubtle.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - University Display

    private func universityDisplayLine(vm: ConnectorsViewModel) -> String {
        if vm.universityCity.isEmpty {
            return vm.universityName
        }
        return "\(vm.universityName) \u{00B7} \(vm.universityCity)"
    }

    // MARK: - No University Hint

    private var noUniversityHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 24))
                .foregroundColor(goldSubtle.opacity(0.30))
            Text("Nenhuma universidade detectada")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text("Complete seu perfil para ver os portais da sua faculdade")
                .font(.system(size: 11))
                .foregroundColor(goldSubtle.opacity(0.30))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Portal Card (generic)

    @ViewBuilder
    private func portalCard(
        letter: String, name: String, color: Color,
        connectorId: String, state: ConnectorState,
        vm: ConnectorsViewModel
    ) -> some View {
        ConnectorCard(
            letter: letter,
            name: name,
            status: state.status,
            color: color,
            lastSync: state.lastSync,
            stats: state.stats,
            onConnect: { handleConnect(portalType: connectorId, instanceUrl: nil) },
            onDisconnect: { Task { await vm.disconnect(connectorId) } },
            onTapConnected: { activeSheet = connectorId }
        )
    }

    // MARK: - Integration Card (OAuth connectors)

    // MARK: - WhatsApp Link Sheet

    @ViewBuilder
    private var whatsAppLinkSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)
                Image(systemName: waStep == 2 ? "checkmark.circle.fill" : "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(waStep == 2 ? .green : Color(red: 0.15, green: 0.68, blue: 0.38))

                if waStep == 0 {
                    Text("Conectar WhatsApp").font(.title2.bold()).foregroundStyle(.white)
                    Text("Receba notificações e converse com a VITA pelo WhatsApp")
                        .font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    TextField("51989484243", text: $waPhone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .padding().background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24).foregroundStyle(.white)
                    if let err = waError { Text(err).font(.caption).foregroundStyle(.red) }
                    Button {
                        Task { await sendWACode() }
                    } label: {
                        HStack {
                            if waSending { ProgressView().tint(.black) }
                            Text("Enviar código").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(red: 0.15, green: 0.68, blue: 0.38))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(waPhone.count < 8 || waSending).padding(.horizontal, 24)

                } else if waStep == 1 {
                    Text("Digite o código").font(.title2.bold()).foregroundStyle(.white)
                    Text("Enviamos um código de 6 dígitos para seu WhatsApp")
                        .font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    TextField("000000", text: $waCode)
                        .keyboardType(.numberPad).textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .padding().background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 60).foregroundStyle(.white)
                    if let err = waError { Text(err).font(.caption).foregroundStyle(.red) }
                    Button {
                        Task { await verifyWACode() }
                    } label: {
                        HStack {
                            if waSending { ProgressView().tint(.black) }
                            Text("Verificar").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(red: 0.15, green: 0.68, blue: 0.38))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(waCode.count < 6 || waSending).padding(.horizontal, 24)
                    Button("Reenviar código") { Task { await sendWACode() } }
                        .font(.caption).foregroundStyle(goldSubtle)

                } else {
                    Text("WhatsApp conectado!").font(.title2.bold()).foregroundStyle(.white)
                    Text("A VITA vai te mandar uma mensagem de boas-vindas")
                        .font(.subheadline).foregroundStyle(.gray)
                }
                Spacer()
            }
            .padding(.top, 20)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { showWhatsAppSheet = false }.foregroundStyle(.gray)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sendWACode() async {
        guard let vm else { return }
        waSending = true; waError = nil
        do {
            try await vm.linkWhatsApp(phone: waPhone)
            waStep = 1
        } catch { waError = "Erro ao enviar código" }
        waSending = false
    }

    private func verifyWACode() async {
        guard let vm else { return }
        waSending = true; waError = nil
        do {
            try await vm.verifyWhatsApp(code: waCode)
            waStep = 2
            try? await Task.sleep(for: .seconds(2))
            showWhatsAppSheet = false
        } catch { waError = "Código inválido ou expirado" }
        waSending = false
    }

        private func integrationCard(
        letter: String, name: String, color: Color,
        connectorId: String, state: ConnectorState,
        vm: ConnectorsViewModel,
        iconAsset: String? = nil
    ) -> some View {
        ConnectorCard(
            letter: letter,
            name: name,
            status: state.status,
            color: color,
            iconAsset: iconAsset,
            lastSync: state.lastSync,
            stats: state.stats,
            onConnect: { Task { await vm.connectIntegration(connectorId) } },
            onDisconnect: { Task { await vm.disconnect(connectorId) } },
            onTapConnected: { activeSheet = connectorId }
        )
    }

    // MARK: - Handle Connect (direct flow, no intermediate screen)

    private func handleConnect(portalType: String, instanceUrl: String?) {
        switch portalType {
        case "canvas":
            canvasInstanceUrl = instanceUrl ?? vm?.canvas.instanceUrl ?? "https://ulbra.instructure.com"
            showCanvasTokenSheet = true
        default:
            onPortalConnect?(portalType, instanceUrl)
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for connectorId: String) -> some View {
        if let vm {
            let state = vm.state(for: connectorId)
            let (icon, syncNote) = sheetMeta(for: connectorId)

            ConnectorStatusSheet(
                serviceName: state.name,
                icon: icon,
                subtitle: state.subtitle,
                lastSync: state.lastSync,
                lastSyncAbsolute: state.lastSyncAbsolute,
                lastPing: state.lastPing,
                isStale: state.isStale,
                isExpired: state.status == .expired,
                stats: state.stats.map { ConnectorStat(value: $0.value, label: $0.label) },
                syncNote: syncNote,
                onSync: {
                    activeSheet = nil
                    Task {
                        switch connectorId {
                        case "canvas": await vm.syncCanvas()
                        case "google_calendar": await vm.syncCalendar()
                        case "google_drive": await vm.syncDrive()
                        default: break
                        }
                    }
                },
                onDisconnect: {
                    activeSheet = nil
                    Task { await vm.disconnect(connectorId) }
                }
            )
        }
    }

    private func sheetMeta(for id: String) -> (icon: String, syncNote: String?) {
        switch id {
        case "canvas": ("building.columns", nil)
        case "google_calendar": ("calendar", nil)
        case "google_drive": ("externaldrive", nil)
        case "spotify": ("music.note", nil)
        case "whatsapp": ("message.fill", nil)
        default: ("link", nil)
        }
    }

    // MARK: - Connected Count Card

    private func connectedCountCard(vm: ConnectorsViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portais conectados")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.88))
                Text("Sincronize notas e horÃ¡rios automaticamente")
                    .font(.system(size: 10.5))
                    .foregroundColor(goldSubtle.opacity(0.35))
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(vm.connectedCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.90))
                Text("/\(vm.totalPortals)")
                    .font(.system(size: 11))
                    .foregroundColor(goldSubtle.opacity(0.30))
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        SectionHeader(title: text)
    }

    // MARK: - Como Funciona

    private var comoFunciona: some View {
        VStack(alignment: .leading, spacing: 12) {
            howItWorksRow("1", "Conecte seu portal acadÃªmico com suas credenciais")
            howItWorksRow("2", "Disciplinas, notas e horÃ¡rios sao importados")
            howItWorksRow("3", "Dados sincronizam automaticamente a cada 15 minutos")
            howItWorksRow("4", "Desconecte a qualquer momento â€” seus dados sao excluidos")
        }
    }

    private func howItWorksRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(VitaColors.glassInnerLight.opacity(0.12))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.12), lineWidth: 1)
                    )
                Text(number)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.80))
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(goldSubtle.opacity(0.45))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - String+Identifiable (for sheet binding)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - ConnectionItemStatus

enum ConnectionItemStatus: Equatable {
    case loading, connected, expired, disconnected

    var accentColor: Color {
        switch self {
        case .connected:              return Color(red: 0.29, green: 0.87, blue: 0.50)
        case .expired:                return VitaColors.dataAmber
        case .disconnected, .loading: return VitaColors.textTertiary
        }
    }

    @ViewBuilder
    var badge: some View {
        switch self {
        case .connected:
            statusBadge(icon: "checkmark.circle.fill", label: "Conectado",    color: Color(red: 0.29, green: 0.87, blue: 0.50))
        case .expired:
            statusBadge(icon: "exclamationmark.triangle.fill", label: "Expirado", color: VitaColors.dataAmber)
        case .disconnected:
            statusBadge(icon: "xmark.circle", label: "Desconectado", color: VitaColors.textTertiary)
        case .loading:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
