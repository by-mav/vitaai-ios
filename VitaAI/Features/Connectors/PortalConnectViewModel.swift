import Foundation
import Observation

// MARK: - PortalConnectViewModel
// Unified ViewModel for the portal connect screen. Replaces 4 separate ViewModels:
// CanvasConnectViewModel, WebAlunoConnectViewModel, GoogleCalendarConnectViewModel, GoogleDriveConnectViewModel.
// Uses portalType to dispatch to the correct API calls.

@MainActor
@Observable
final class PortalConnectViewModel {
    let portalType: String

    // Common state
    var isLoading = true
    var isConnected = false
    var isSyncing = false
    var isConnecting = false
    var isDisconnecting = false
    var lastSync: String?
    var subtitle: String?       // email for Google, URL for portals
    var stats: [(value: Int, label: String)] = []
    var instanceUrl: String = ""
    var error: String?
    var successMessage: String?

    // Canvas-specific sync state
    var canvasSyncPhase: CanvasSyncOrchestrator.Phase = .starting
    var canvasSyncProgress: Double = 0
    var canvasSyncMessage: String?

    // Mannesoft/WebAluno sync state
    var mannesoftSyncPhase: String = "login"
    var mannesoftSyncMessage: String?
    var mannesoftSyncDone = false

    private let api: VitaAPI
    private var syncTask: Task<Void, Never>?

    init(portalType: String, api: VitaAPI, defaultInstanceUrl: String = "") {
        self.portalType = portalType
        self.api = api
        if !defaultInstanceUrl.isEmpty {
            self.instanceUrl = defaultInstanceUrl
        }
    }

    // MARK: - Display Config

    var displayName: String { PortalConnectConfig.displayName(for: portalType) }
    var icon: String { PortalConnectConfig.icon(for: portalType) }
    var connectedIcon: String { PortalConnectConfig.connectedIcon(for: portalType) }
    var disconnectedIcon: String { PortalConnectConfig.disconnectedIcon(for: portalType) }
    var howItWorks: [String] { PortalConnectConfig.howItWorks(for: portalType) }
    var isOAuth: Bool { portalType.hasPrefix("google_") }
    var isWebViewPortal: Bool { !isOAuth }

    // MARK: - Load Status

    func loadStatus() async {
        isLoading = true
        error = nil
        do {
            switch portalType {
            case "canvas":
                let status = try await api.getCanvasStatus()
                if let conn = status.canvasConnection, conn.status == "active" {
                    isConnected = true
                    if let url = conn.instanceUrl, !url.isEmpty { instanceUrl = url }
                    lastSync = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                    stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "atividades"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                } else {
                    isConnected = false
                }

            case "webaluno", "mannesoft":
                // Use the same unified endpoint as Canvas — find the mannesoft connection specifically
                let status = try await api.getCanvasStatus()
                let conn = status.connections?.first { $0.portalType == "mannesoft" || $0.portalType == "webaluno" }
                if let conn {
                    // Always preserve instanceUrl for reconnection, even if expired
                    if let url = conn.instanceUrl, !url.isEmpty { instanceUrl = url }
                    if conn.status == "active" {
                        isConnected = true
                        lastSync = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                        stats = [
                            (conn.counts?.subjects ?? 0, "disciplinas"),
                            (conn.counts?.evaluations ?? 0, "notas"),
                            (conn.counts?.schedule ?? 0, "aulas"),
                        ]
                    } else {
                        isConnected = false
                    }
                } else {
                    isConnected = false
                }

            case "google_calendar":
                let data = try await api.getGoogleCalendarStatus()
                isConnected = data.connected
                subtitle = data.googleEmail
                lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                stats = [(data.counts?.events ?? 0, "eventos")]

            case "google_drive":
                let data = try await api.getGoogleDriveStatus()
                isConnected = data.connected
                subtitle = data.googleEmail
                lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                stats = [(data.counts?.files ?? 0, "arquivos")]

            default:
                // Generic portal lookup (moodle, sigaa, totvs, sagres, lyceum, etc).
                // /api/portal/status returns ALL connections regardless of type;
                // match by portalType so the screen renders "Conectado" + last
                // sync correctly for portals beyond canvas/mannesoft.
                let status = try await api.getCanvasStatus()
                let conn = status.connections?.first { $0.portalType == portalType }
                if let conn {
                    if let url = conn.instanceUrl, !url.isEmpty { instanceUrl = url }
                    if conn.status == "active" {
                        isConnected = true
                        lastSync = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                        stats = [
                            (conn.counts?.subjects ?? 0, "disciplinas"),
                            (conn.counts?.evaluations ?? 0, "notas"),
                            (conn.counts?.schedule ?? 0, "aulas"),
                        ]
                    } else {
                        isConnected = false
                    }
                } else {
                    isConnected = false
                }
            }
        } catch {
            isConnected = false
        }
        isLoading = false
    }

    // MARK: - Connect Mannesoft portal (server-side crawl)

    func connectMannesoft(cookie: String) {
        let connectStart = Date()
        VitaPostHogConfig.capture(event: "portal_connect_attempted", properties: [
            "portal_type": "mannesoft",
            "instance_url": instanceUrl,
        ])
        Task {
            isConnecting = true
            isSyncing = true
            error = nil
            successMessage = nil
            mannesoftSyncPhase = "login"
            mannesoftSyncMessage = "Conectando ao portal..."
            mannesoftSyncDone = false
            do {
                let url = instanceUrl
                mannesoftSyncPhase = "disciplines"
                mannesoftSyncMessage = "Vita buscando disciplinas..."
                let crawlResult = try await api.startVitaCrawl(cookies: cookie, instanceUrl: url)
                isConnecting = false
                // Trigger SilentSync — server can't fetch MannesoftPrime pages,
                // extraction must happen client-side via WKWebView + bridge.js
                SilentPortalSync.shared.syncIfNeeded(api: api)
                if let syncId = crawlResult.syncId, !syncId.isEmpty {
                    for _ in 0..<60 {
                        try await Task.sleep(for: .seconds(2))
                        let progress = try await api.getSyncProgress(syncId: syncId)
                        let label = (progress.label ?? "").isEmpty ? "Vita trabalhando..." : (progress.label ?? "")
                        mannesoftSyncMessage = label
                        // Map backend labels to phases
                        if label.contains("disciplina") || label.contains("matéria") {
                            mannesoftSyncPhase = "disciplines"
                        } else if label.contains("nota") || label.contains("grade") {
                            mannesoftSyncPhase = "grades"
                        } else if label.contains("horário") || label.contains("schedule") || label.contains("aula") {
                            mannesoftSyncPhase = "schedule"
                        } else if label.contains("extrai") || label.contains("extract") || label.contains("process") {
                            mannesoftSyncPhase = "extracting"
                        }
                        if progress.isDone {
                            mannesoftSyncPhase = "done"
                            mannesoftSyncMessage = "Extração completa!"
                            mannesoftSyncDone = true
                            isConnected = true
                            isSyncing = false
                            PostHogTracker.shared.event(.portalConnectSucceeded, properties: [
                                "portal_type": "mannesoft",
                                "instance_url": instanceUrl,
                                "seconds_elapsed": Int(Date().timeIntervalSince(connectStart)),
                            ])
                            await loadStatus()
                            return
                        }
                        if progress.isError {
                            error = label
                            isSyncing = false
                            PostHogTracker.shared.event(.portalConnectFailed, properties: [
                                "portal_type": "mannesoft",
                                "instance_url": instanceUrl,
                                "reason": label,
                            ])
                            return
                        }
                    }
                    // Timeout — still syncing in background
                    mannesoftSyncMessage = "Vita continua em background..."
                    isConnected = true
                    isSyncing = false
                } else {
                    // No syncId — crawl was instant
                    mannesoftSyncPhase = "done"
                    mannesoftSyncDone = true
                    isConnected = true
                    isSyncing = false
                    await loadStatus()
                }
            } catch {
                isConnecting = false
                isSyncing = false
                self.error = "Erro de conexão. Verifique sua internet."
                PostHogTracker.shared.event(.portalConnectFailed, properties: [
                    "portal_type": "mannesoft",
                    "instance_url": instanceUrl,
                    "reason": error.localizedDescription,
                ])
            }
        }
    }

    // MARK: - Send extracted pages from bridge.js

    func sendExtractedPages(_ pages: [CapturedPortalPage]) async {
        let apiPages = pages.map { page in
            PortalExtractRequestPagesInner(type: page.type, html: page.html, linkText: page.linkText)
        }
        guard !apiPages.isEmpty else { return }
        do {
            let result = try await api.extractPortalPages(
                pages: apiPages,
                instanceUrl: instanceUrl,
                university: ""
            )
            NSLog("[PortalConnect] Extract done: grades=%d, schedule=%d", result.grades ?? 0, result.schedule ?? 0)
            successMessage = "Dados extraídos com sucesso!"
            await loadStatus()
        } catch {
            NSLog("[PortalConnect] Extract failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Connect Canvas (on-device orchestrator)

    func connectCanvas(cookies: String, instanceUrl: String) {
        let canvasStart = Date()
        VitaPostHogConfig.capture(event: "portal_connect_attempted", properties: [
            "portal_type": "canvas",
            "instance_url": instanceUrl,
        ])
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSyncing = true
            self.error = nil
            self.canvasSyncPhase = .starting
            self.canvasSyncProgress = 0
            self.canvasSyncMessage = CanvasSyncOrchestrator.Phase.starting.rawValue

            let orchestrator = CanvasSyncOrchestrator(
                cookies: cookies,
                instanceUrl: instanceUrl,
                vitaAPI: api,
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.canvasSyncPhase = progress.phase
                        self.canvasSyncProgress = progress.percent
                        if let detail = progress.detail {
                            self.canvasSyncMessage = "\(progress.phase.rawValue) \(detail)"
                        } else {
                            self.canvasSyncMessage = progress.phase.rawValue
                        }
                    }
                }
            )

            do {
                let result = try await orchestrator.run()
                try Task.checkCancellation()
                self.isSyncing = false
                self.isConnected = true
                self.canvasSyncPhase = .done
                let summary = [
                    result.courses.map { "\($0) disciplinas" },
                    result.assignments.map { "\($0) atividades" },
                    result.pdfExtracted.map { "\($0) PDFs processados" },
                ].compactMap { $0 }.joined(separator: ", ")
                self.successMessage = summary.isEmpty ? "Extracao completa!" : "Pronto! \(summary)"
                PostHogTracker.shared.event(.portalConnectSucceeded, properties: [
                    "portal_type": "canvas",
                    "instance_url": instanceUrl,
                    "seconds_elapsed": Int(Date().timeIntervalSince(canvasStart)),
                    "subjects_count": result.courses ?? 0,
                    "evaluations_count": result.assignments ?? 0,
                ])
                await self.loadStatus()
            } catch is CancellationError {
                // cancelled
            } catch {
                self.isSyncing = false
                self.canvasSyncPhase = .error
                self.error = "Erro: \(error.localizedDescription)"
                PostHogTracker.shared.event(.portalConnectFailed, properties: [
                    "portal_type": "canvas",
                    "instance_url": instanceUrl,
                    "reason": error.localizedDescription,
                ])
            }
        }
    }

    // MARK: - Sync

    func sync() {
        VitaPostHogConfig.capture(event: "portal_sync_triggered", properties: [
            "portal_type": portalType,
            "instance_url": instanceUrl,
            "trigger": "manual",
        ])
        Task {
            isSyncing = true
            error = nil
            successMessage = nil
            do {
                switch portalType {
                case "canvas":
                    // Canvas sync needs fresh on-device cookies — handled by reconnect flow
                    isSyncing = false
                    error = "Para re-sincronizar, reconecte ao Canvas"
                    return
                case "webaluno", "mannesoft":
                    // Trigger SilentSync immediately using SharedPortalWebView
                    SilentPortalSync.shared.resetThrottle()
                    SilentPortalSync.shared.syncIfNeeded(api: api)
                    isSyncing = false
                    successMessage = "Sincronizando dados do portal..."
                    return
                case "google_calendar":
                    let result = try await api.syncGoogleCalendar()
                    let count = result.events > 0 ? result.events : result.synced
                    successMessage = "Sincronizado: \(count) eventos"
                case "google_drive":
                    let result = try await api.syncGoogleDrive()
                    let count = result.files > 0 ? result.files : result.synced
                    successMessage = "Sincronizado: \(count) arquivo(s)"
                default: break
                }
                isSyncing = false
                await loadStatus()
            } catch {
                isSyncing = false
                self.error = "Falha na sincronização"
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        Task {
            isDisconnecting = true
            error = nil
            successMessage = nil
            do {
                switch portalType {
                case "canvas":
                    try await api.disconnectCanvas()
                case "webaluno", "mannesoft":
                    try await api.disconnectPortal()
                case "google_calendar":
                    try await api.disconnectGoogleCalendar()
                case "google_drive":
                    try await api.disconnectGoogleDrive()
                default: break
                }
                isDisconnecting = false
                isConnected = false
                stats = []
                lastSync = nil
                subtitle = nil
                successMessage = "\(displayName) desconectado"
            } catch {
                isDisconnecting = false
                self.error = "Falha ao desconectar"
            }
        }
    }

    // MARK: - OAuth URL (Google services)

    func oauthURL() -> URL? {
        switch portalType {
        case "google_calendar":
            return URL(string: "\(AppConfig.apiBaseURL)/google/calendar/authorize")
        case "google_drive":
            return URL(string: "\(AppConfig.apiBaseURL)/google/drive/authorize")
        default:
            return nil
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        error = nil
        successMessage = nil
    }

    // MARK: - Helpers

    private func formatRelativeTime(_ isoDate: String) -> String? {
        var date: Date?
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let date else { return nil }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1  { return "agora" }
        if minutes < 60 { return "\(minutes)min atras" }
        let hours = minutes / 60
        if hours < 24   { return "\(hours)h atras" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        fmt.locale = Locale(identifier: "pt_BR")
        return fmt.string(from: date)
    }
}

// MARK: - Portal Config (display metadata)

enum PortalConnectConfig {
    static func displayName(for type: String) -> String {
        switch type {
        case "canvas": "Canvas LMS"
        case "webaluno", "mannesoft": "Portal Acadêmico"
        case "google_calendar": "Google Calendar"
        case "google_drive": "Google Drive"
        case "moodle": "Moodle"
        case "sigaa": "SIGAA"
        case "totvs": "TOTVS RM"
        case "lyceum": "Lyceum"
        case "sagres": "Sagres"
        case "blackboard": "Blackboard"
        case "platos": "Platos"
        default: University.displayName(for: type)
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "canvas": "building.columns"
        case "webaluno", "mannesoft": "graduationcap"
        case "google_calendar": "calendar"
        case "google_drive": "externaldrive"
        case "moodle": "book.closed"
        case "sigaa": "doc.text"
        default: "link"
        }
    }

    static func connectedIcon(for type: String) -> String {
        switch type {
        case "canvas": "cloud.fill"
        case "webaluno", "mannesoft": "cloud.fill"
        case "google_calendar": "calendar.badge.checkmark"
        case "google_drive": "externaldrive.fill.badge.checkmark"
        default: "checkmark.circle.fill"
        }
    }

    static func disconnectedIcon(for type: String) -> String {
        switch type {
        case "canvas": "cloud.slash.fill"
        case "webaluno", "mannesoft": "cloud.slash.fill"
        case "google_calendar": "calendar.badge.exclamationmark"
        case "google_drive": "externaldrive.badge.exclamationmark"
        default: "xmark.circle"
        }
    }

    static func howItWorks(for type: String) -> [String] {
        switch type {
        case "canvas":
            return [
                "Disciplinas, arquivos e atividades importados",
                "Planos de ensino processados pela IA Vita",
                "Eventos do calendário na sua agenda",
                "Sincronize quando quiser dados atualizados",
            ]
        case "webaluno", "mannesoft":
            return [
                "Notas parciais e finais aparecem em Insights",
                "Grade horaria aparece na sua Agenda",
                "Sessão pode expirar — reconecte se necessário",
            ]
        case "google_calendar":
            return [
                "Eventos e compromissos importados do seu Google Calendar",
                "Provas e deadlines aparecem na sua Agenda no VitaAI",
                "Sincronização segura via OAuth — sem armazenar sua senha",
                "Sincronize sempre que quiser dados atualizados",
            ]
        case "google_drive":
            return [
                "Arquivos PDF do seu Drive importados para o VitaAI",
                "PDFs processados para gerar flashcards e resumos com IA",
                "Sincronização segura via OAuth — sem armazenar sua senha",
                "Sincronize sempre que quiser dados atualizados",
            ]
        default:
            return [
                "Dados acadêmicos importados automaticamente",
                "Notas e horários sincronizados com VitaAI",
            ]
        }
    }
}
