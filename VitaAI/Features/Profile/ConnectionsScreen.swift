import SwiftUI

// Stub type for portal page capture (used by SilentPortalSync)
struct CapturedPortalPage {
    let type: String
    let html: String
    let linkText: String?
}

// MARK: - ConnectionsScreen
// Unified connector list using shared ConnectorCard + ConnectorStatusSheet.
// All portal types supported, driven by ConnectorsViewModel.

struct ConnectionsScreen: View {
    var onCanvasConnect:         (() -> Void)?
    var onWebAlunoConnect:       (() -> Void)?
    var onGoogleCalendarConnect: (() -> Void)?
    var onGoogleDriveConnect:    (() -> Void)?
    var onBack:                  (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var vm: ConnectorsViewModel?
    @State private var toastState = VitaToastState()

    // Sheet visibility
    @State private var activeSheet: String?

    // Direct WebView for WebAluno connect
    @State private var showWebalunoWebView: Bool = false

    // Design tokens
    private let goldSubtle = VitaColors.accentLight
    private let borderColor = VitaColors.glassBorder
    private let cardBg = VitaColors.glassBg
    private let bg = VitaColors.surface

    // MARK: - Portal definitions

    private struct PortalDef {
        let id: String
        let letter: String
        let name: String
        let color: Color
    }

    private var academicPortals: [PortalDef] {
        [
            PortalDef(id: "webaluno", letter: "W", name: "WebAluno",
                      color: Color(red: 0.231, green: 0.510, blue: 0.965)),
            PortalDef(id: "canvas", letter: "C", name: "Canvas LMS",
                      color: Color(red: 0.937, green: 0.267, blue: 0.267)),
            PortalDef(id: "moodle", letter: "M", name: "Moodle",
                      color: Color(red: 0.976, green: 0.451, blue: 0.086)),
            PortalDef(id: "sigaa", letter: "S", name: "SIGAA",
                      color: Color(red: 0.133, green: 0.773, blue: 0.369)),
            PortalDef(id: "totvs", letter: "T", name: "TOTVS RM",
                      color: Color(red: 0.408, green: 0.200, blue: 0.835)),
            PortalDef(id: "lyceum", letter: "L", name: "Lyceum",
                      color: Color(red: 0.114, green: 0.631, blue: 0.667)),
            PortalDef(id: "sagres", letter: "Sa", name: "Sagres",
                      color: Color(red: 0.820, green: 0.557, blue: 0.102)),
            PortalDef(id: "blackboard", letter: "Bb", name: "Blackboard",
                      color: Color(red: 0.267, green: 0.267, blue: 0.267)),
            PortalDef(id: "platos", letter: "P", name: "Platos",
                      color: Color(red: 0.827, green: 0.184, blue: 0.463)),
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            bg.ignoresSafeArea()

            if let vm {
                mainContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if vm == nil {
                let viewModel = ConnectorsViewModel(api: container.api)
                vm = viewModel
                Task { await viewModel.loadAll() }
            }
        }
        .task(id: "refresh-timer") {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await vm?.loadPortalConnections()
            }
        }
        // Unified sheet for any connector
        .sheet(item: $activeSheet) { sheetId in
            sheetContent(for: sheetId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // Direct WebAluno WebView
        .fullScreenCover(isPresented: $showWebalunoWebView) {
            WebAlunoWebViewScreen(
                onBack: { showWebalunoWebView = false },
                onSessionCaptured: { cookie in
                    showWebalunoWebView = false
                    Task { await vm?.connectWebaluno(cookie: cookie) }
                },
                userEmail: container.authManager.userEmail
            )
        }
        .vitaToastHost(toastState)
        .onChange(of: vm?.toastMessage) { msg in
            if let msg {
                toastState.show(msg, type: vm?.toastType ?? .success)
                vm?.toastMessage = nil
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: ConnectorsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 64)

                // Connected count card
                connectedCountCard(vm: vm)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                // Section label
                sectionLabel("Portais")
                    .padding(.top, 18)

                // Portal cards
                VStack(spacing: 8) {
                    if vm.universityPortals.isEmpty {
                        ForEach(academicPortals, id: \.id) { portal in
                            portalCardView(portal, vm: vm)
                        }
                    } else {
                        ForEach(vm.universityPortals, id: \.id) { portal in
                            let def = academicPortals.first(where: { $0.id == portal.portalType })
                                ?? PortalDef(
                                    id: portal.portalType,
                                    letter: University.letter(for: portal.portalType),
                                    name: portal.displayName.isEmpty ? University.displayName(for: portal.portalType) : portal.displayName,
                                    color: VitaColors.accent
                                )
                            portalCardView(def, vm: vm)
                        }
                    }
                }
                .padding(.horizontal, 14)

                // Google section
                sectionLabel("Google")
                    .padding(.top, 18)

                VStack(spacing: 8) {
                    googleCardView(
                        letter: "G", name: "Google Calendar",
                        color: Color(red: 0.26, green: 0.52, blue: 0.96),
                        state: vm.calendar,
                        onConnect: { onGoogleCalendarConnect?() },
                        onDisconnect: { Task { await vm.disconnect("google_calendar") } },
                        onTap: { activeSheet = "google_calendar" }
                    )
                    googleCardView(
                        letter: "G", name: "Google Drive",
                        color: Color(red: 0.13, green: 0.59, blue: 0.33),
                        state: vm.drive,
                        onConnect: { onGoogleDriveConnect?() },
                        onDisconnect: { Task { await vm.disconnect("google_drive") } },
                        onTap: { activeSheet = "google_drive" }
                    )
                }
                .padding(.horizontal, 14)

                // Como funciona
                sectionLabel("Como funciona")
                    .padding(.top, 20)

                comoFunciona
                    .padding(14)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
                    .padding(.horizontal, 14)

                Spacer().frame(height: 120)
            }
        }
    }

    // MARK: - Portal Card (academic)

    @ViewBuilder
    private func portalCardView(_ portal: PortalDef, vm: ConnectorsViewModel) -> some View {
        let connState = vm.state(for: portal.id)

        ConnectorCard(
            letter: portal.letter,
            name: portal.name,
            status: connState.status,
            color: portal.color,
            lastSync: connState.lastSync,
            stats: connState.stats,
            onConnect: {
                switch portal.id {
                case "webaluno": showWebalunoWebView = true
                case "canvas": onCanvasConnect?()
                default: break
                }
            },
            onDisconnect: {
                Task { await vm.disconnect(portal.id) }
            },
            onTapConnected: {
                activeSheet = portal.id
            }
        )
    }

    // MARK: - Google Card

    @ViewBuilder
    private func googleCardView(
        letter: String, name: String, color: Color,
        state: ConnectorState,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) -> some View {
        ConnectorCard(
            letter: letter,
            name: name,
            status: state.status,
            color: color,
            lastSync: state.lastSync,
            stats: state.stats,
            onConnect: onConnect,
            onDisconnect: onDisconnect,
            onTapConnected: onTap
        )
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
                stats: state.stats.map { ConnectorStat(value: $0.value, label: $0.label) },
                syncNote: syncNote,
                onSync: {
                    activeSheet = nil
                    Task {
                        switch connectorId {
                        case "canvas": await vm.syncCanvas()
                        case "webaluno":
                            activeSheet = nil
                            showWebalunoWebView = true
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
        case "webaluno": ("graduationcap", "Sincroniza automaticamente a cada 15 min")
        case "google_calendar": ("calendar", nil)
        case "google_drive": ("externaldrive", nil)
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
                Text("Sincronize notas e horarios automaticamente")
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
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(goldSubtle.opacity(0.35))
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    // MARK: - Como Funciona

    private var comoFunciona: some View {
        VStack(spacing: 10) {
            howItWorksStep("1", "Conecte seu portal academico com suas credenciais")
            howItWorksStep("2", "A Vita importa disciplinas, notas e horarios")
            howItWorksStep("3", "Dados sincronizados automaticamente a cada 15 minutos")
            howItWorksStep("4", "Desconecte a qualquer momento — seus dados sao excluidos")
        }
    }

    private func howItWorksStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(VitaColors.glassInnerLight.opacity(0.12))
                    .frame(width: 20, height: 20)
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
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
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
