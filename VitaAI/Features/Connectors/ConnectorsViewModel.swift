import Foundation
import UIKit
import SafariServices
import Observation

// MARK: - ConnectorsViewModel
// Unified state for all portal connections, used by ConnectionsScreen.

@MainActor
@Observable
final class ConnectorsViewModel {
    // Per-connector state — academic
    var canvas = ConnectorState(id: "canvas", name: "Canvas LMS")

    // Per-connector state — productivity
    var calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
    var drive = ConnectorState(id: "google_drive", name: "Google Drive")
    var spotify = ConnectorState(id: "spotify", name: "Spotify")
    var whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")

    // University data
    var universityPortals: [UniversityPortal] = []
    var universityName: String = ""
    var universityCity: String = ""

    // Toast
    var toastMessage: String?
    var toastType: VitaToastType = .success

    private let api: VitaAPI
    private weak var dataManager: AppDataManager?

    // SFSafariViewController apresentado para OAuth in-app (Spotify, Google Drive,
    // Google Calendar). Guardado pra poder dismissar quando o deep link callback
    // (vitaai://integrations/done) volta — SafariViewController não fecha sozinho
    // como ASWebAuthenticationSession faria.
    private weak var presentedOAuthSafari: SFSafariViewController?

    init(api: VitaAPI, dataManager: AppDataManager? = nil) {
        self.api = api
        self.dataManager = dataManager
        // Listen pro callback de OAuth completar (postado pelo AppRouter quando
        // recebe o deep link vitaai://integrations/done?provider=X).
        NotificationCenter.default.addObserver(
            forName: .integrationOAuthCompleted,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.dismissOAuthSheet()
                if let provider = note.object as? String {
                    self?.toastMessage = "\(provider.capitalized) conectado"
                    self?.toastType = .success
                }
                await self?.loadAll()
            }
        }
    }

    @MainActor
    private func dismissOAuthSheet() {
        presentedOAuthSafari?.dismiss(animated: true)
        presentedOAuthSafari = nil
    }

    // MARK: - All integration connectors

    var allIntegrations: [ConnectorState] {
        [calendar, drive, spotify, whatsapp]
    }

    // MARK: - Computed

    var connectedCount: Int {
        ([canvas] + allIntegrations).filter { $0.status == .connected }.count
    }

    var totalPortals: Int {
        1 + allIntegrations.count
    }

    func state(for portalId: String) -> ConnectorState {
        switch portalId {
        case "canvas": canvas
        case "google_calendar": calendar
        case "google_drive": drive
        case "spotify": spotify
        case "whatsapp": whatsapp
        default: ConnectorState(id: portalId, name: portalId)
        }
    }

    // MARK: - Load All

    func loadAll() async {
        await loadUniversityPortals()
        await loadPortalConnections()
        await loadIntegrations()
    }

    /// Pull-to-refresh / "Sincronizar agora" handler.
    ///
    /// Pre-2026-04-27 the refresh gesture only re-fetched /api/portal/status
    /// (loadAll), which never advances lastSyncAt — so cards stayed pinned at
    /// "Sync travado · puxe pra atualizar" forever even when the user swiped
    /// down 10 times. Backend had no user-auth trigger endpoint either.
    ///
    /// Now: hit POST /api/portal/sync-now first (Canvas PAT/API re-scrape),
    /// then reload status.
    /// lastPingAt and lastSyncAt advance on the server after the Canvas PAT/API
    /// ingest succeeds, so the second loadAll() call already shows fresh state.
    func refreshAndSync() async {
        do {
            try await api.triggerPortalSyncNow()
        } catch {
            // Silent failure is OK: cron still covers the user. Fall through
            // to loadAll() so the card repaints with current backend state.
            // the card at minimum re-paints with current backend state.
            NSLog("[Connectors] sync-now trigger failed: \(error.localizedDescription)")
        }
        await loadAll()
    }

    // MARK: - University Portals

    private func loadUniversityPortals() async {
        do {
            // Reuse the cached profile from AppDataManager when present —
            // avoids an extra /api/profile round-trip every time the user
            // opens the connectors sheet.
            let profile: ProfileResponse
            if let cached = dataManager?.profile {
                profile = cached
            } else {
                profile = try await api.getProfile()
            }
            let uniId = profile.universityId
            let uniName = profile.university
            guard let uniId, !uniId.isEmpty else { return }

            let query = uniName ?? ""
            let response = try await api.getUniversities(query: query)
            if let uni = response.universities.first(where: { $0.id == uniId }) {
                universityName = uni.shortName.isEmpty ? uni.name : uni.shortName
                universityCity = uni.city
                if let portals = uni.portals, !portals.isEmpty {
                    universityPortals = portals
                }
            } else if let uniName, !uniName.isEmpty {
                universityName = uniName
            }
        } catch {
            print("[Connectors] University portals load failed: \(error)")
        }
    }

    // MARK: - Portal Connections (Canvas PAT/API)

    func loadPortalConnections() async {
        do {
            let data = try await api.getCanvasStatus()
            guard let connections = data.connections, !connections.isEmpty else {
                canvas.status = .disconnected
                return
            }

            for conn in connections {
                let status: ConnectionItemStatus = switch conn.status {
                case "expired": .expired
                case "inactive", "disconnected": .disconnected
                default: .connected
                }

                // Separamos os dois conceitos:
                // lastSyncAt  = última vez que dados foram extraídos com êxito
                // lastPingAt  = última vez que o token/sessão foi verificado vivo (keep-alive)
                // Se sync > 12h, card vira "stale" mesmo com status=connected.
                let syncRelative = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                let pingRelative = conn.lastPingAt.flatMap { formatRelativeTime($0) }
                let syncAbsolute = conn.lastSyncAt.flatMap { formatAbsoluteTime($0) }
                let stale = isStale(conn.lastSyncAt)
                // So mostra "Token vivo" se status=connected E ping for MAIS RECENTE que sync.
                // Se sync > ping, o ping antigo e irrelevante (acabou de reconectar).
                // Quando expired, token NAO e vivo — nunca mostrar.
                let pingNewerThanSync: Bool = {
                    guard let pingDate = conn.lastPingAt.flatMap({ parseISO($0) }),
                          let syncDate = conn.lastSyncAt.flatMap({ parseISO($0) }) else { return true }
                    return pingDate > syncDate
                }()
                let pingDifferent = status == .connected && pingRelative != nil && pingRelative != syncRelative && pingNewerThanSync

                switch conn.portalType {
                case "canvas":
                    canvas.status = status
                    canvas.lastSync = syncRelative ?? pingRelative
                    canvas.lastPing = pingDifferent ? pingRelative : nil
                    canvas.lastSyncAbsolute = syncAbsolute
                    canvas.isStale = stale
                    canvas.instanceUrl = conn.instanceUrl
                    canvas.connectionId = conn.id
                    canvas.stats = [
                        (conn.counts?.subjects ?? 0, "matérias"),
                        (conn.counts?.evaluations ?? 0, "atividades"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                default:
                    break
                }
            }
        } catch {
            print("[Connectors] Portal status load failed: \(error)")
        }
    }

    // MARK: - Load Integrations (unified endpoint)

    private func loadIntegrations() async {
        // Load Google Calendar & Drive via existing specific endpoints
        async let cal = loadCalendar()
        async let drv = loadDrive()
        async let wa = loadWhatsAppStatus()
        _ = await (cal, drv, wa)

        // Spotify: load from unified /api/integrations
        // Backend shape (canonical 2026-04-26): { providers: [{ name, status, ... }] }
        do {
            let data = try await api.getIntegrations()
            for item in data.providers {
                switch item.name {
                case "spotify":
                    spotify.status = connectionStatus(from: item.status)
                    spotify.lastSync = item.lastSyncAt.flatMap { formatRelativeTime($0) }
                    if let email = item.providerAccountEmail { spotify.subtitle = email }
                default: break
                }
            }
        } catch {
            // Decoder failure here = silent UX bug (connector stays "Conectar"
            // even with tokens in DB). Always surface in console.
            print("[Connectors] Integrations load failed: \(error)")
        }
    }

    // MARK: - WhatsApp

    func loadWhatsAppStatus() async {
        do {
            let data = try await api.getWhatsAppStatus()
            if data.verified, data.phone != nil {
                whatsapp.status = .connected
                whatsapp.subtitle = Self.formatPhone(data.phone)
            } else {
                whatsapp.status = .disconnected
                whatsapp.subtitle = nil
            }
        } catch {
            whatsapp.status = .disconnected
        }
    }

    func linkWhatsApp(phone: String) async throws {
        try await api.linkWhatsApp(phone: phone)
    }

    func verifyWhatsApp(code: String) async throws {
        let result = try await api.verifyWhatsApp(code: code)
        if result.verified {
            await loadWhatsAppStatus()
        }
    }

    private func connectionStatus(from status: String) -> ConnectionItemStatus {
        switch status {
        case "active", "connected": .connected
        case "expired": .expired
        default: .disconnected
        }
    }

    // MARK: - Google Calendar

    private func loadCalendar() async {
        do {
            let data = try await api.getGoogleCalendarStatus()
            if data.connected {
                calendar.status = data.status == "expired" ? .expired : .connected
                calendar.lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                calendar.stats = [(data.counts?.events ?? 0, "eventos")]
                calendar.subtitle = data.googleEmail
            } else {
                calendar.status = .disconnected
            }
        } catch {
            calendar.status = .disconnected
        }
    }

    // MARK: - Google Drive

    private func loadDrive() async {
        do {
            let data = try await api.getGoogleDriveStatus()
            if data.connected {
                drive.status = data.status == "expired" ? .expired : .connected
                drive.lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                drive.stats = [(data.counts?.files ?? 0, "arquivos")]
                drive.subtitle = data.googleEmail
            } else {
                drive.status = .disconnected
            }
        } catch {
            drive.status = .disconnected
        }
    }

    // MARK: - Disconnect

    func disconnect(_ connectorId: String) async {
        do {
            switch connectorId {
            case "canvas":
                try await api.disconnectCanvas()
                canvas = ConnectorState(id: "canvas", name: "Canvas LMS")
            case "google_calendar":
                try await api.disconnectIntegration("google_calendar")
                calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            case "google_drive":
                try await api.disconnectIntegration("google_drive")
                drive = ConnectorState(id: "google_drive", name: "Google Drive")
            case "spotify":
                try await api.disconnectIntegration("spotify")
                spotify = ConnectorState(id: "spotify", name: "Spotify")
            case "whatsapp":
                try await api.unlinkWhatsApp()
                whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")
            default: break
            }
            toastMessage = "Desconectado"
            toastType = .success
        } catch {
            print("[Connectors] Disconnect \(connectorId) error: \(error)")
            toastMessage = "Erro ao desconectar"
            toastType = .error
        }
    }

    // MARK: - Connect

    /// Apresenta SFSafariViewController in-app pro OAuth do provider (Spotify,
    /// Google Calendar, Google Drive). Cookies persistem no view: user loga
    /// 1x e nas próximas reconexões cai direto no "Authorize". Quando o
    /// backend retorna `vitaai://integrations/done`, o iOS abre o app e o
    /// observer de `integrationOAuthCompleted` dismissa a sheet.
    func connectIntegration(_ connectorId: String) async {
        do {
            let data = try await api.startIntegrationOAuth(connectorId)
            guard let authUrl = data.authUrl, let url = URL(string: authUrl) else { return }
            await MainActor.run { presentSafari(url: url) }
        } catch {
            toastMessage = "Erro ao conectar"
            toastType = .error
        }
    }

    @MainActor
    private func presentSafari(url: URL) {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else { return }
        // If something is already on top (e.g. a sheet), present from that.
        let presenter = root.presentedViewController ?? root
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(VitaColors.accent)
        safari.dismissButtonStyle = .cancel
        safari.modalPresentationStyle = .pageSheet
        presentedOAuthSafari = safari
        presenter.present(safari, animated: true)
    }

    // MARK: - Sync

    func syncCanvas() async {
        guard canvas.connectionId != nil || canvas.instanceUrl != nil else {
            toastMessage = "Para re-sincronizar, reconecte ao Canvas"
            toastType = .success
            return
        }

        canvas.status = .loading
        toastMessage = "Sincronizando Canvas..."
        toastType = .success

        do {
            if let connectionId = canvas.connectionId {
                _ = try await api.syncCanvas(connectionId: connectionId)
            } else {
                _ = try await api.syncCanvas()
            }
            toastMessage = "Canvas atualizado"
            toastType = .success
            await loadPortalConnections()
        } catch {
            toastMessage = "Token Canvas expirou — cole um PAT válido"
            toastType = .error
            canvas.status = .expired
        }
    }

    func syncCalendar() async {
        calendar.status = .loading
        do {
            _ = try await api.syncGoogleCalendar()
            await loadCalendar()
        } catch {
            calendar.status = .connected
        }
    }

    func syncDrive() async {
        drive.status = .loading
        do {
            _ = try await api.syncGoogleDrive()
            await loadDrive()
        } catch {
            drive.status = .connected
        }
    }

    // MARK: - Helpers

    private func parseISO(_ isoDate: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
    }

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

    /// Data absoluta em PT-BR para ancora temporal: "11 abr, 19:54"
    /// Se for hoje, vira "hoje, 19:54". Se > 7 dias, "11/04/26".
    private func formatAbsoluteTime(_ isoDate: String) -> String? {
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        if Calendar.current.isDateInToday(date) {
            fmt.dateFormat = "'hoje,' HH:mm"
        } else if Date().timeIntervalSince(date) < 7 * 86_400 {
            fmt.dateFormat = "dd MMM, HH:mm"
        } else {
            fmt.dateFormat = "dd/MM/yy"
        }
        return fmt.string(from: date)
    }

    /// Format BR phone: "5551989484243" → "+55 51 98948-4243"
    private static func formatPhone(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 10 else { return "+\(digits)" }
        if digits.count == 13 {
            // +CC AA 9XXXX-XXXX
            let cc = digits.prefix(2)
            let area = digits.dropFirst(2).prefix(2)
            let part1 = digits.dropFirst(4).prefix(5)
            let part2 = digits.dropFirst(9)
            return "+\(cc) \(area) \(part1)-\(part2)"
        }
        if digits.count == 11 {
            // AA 9XXXX-XXXX
            let area = digits.prefix(2)
            let part1 = digits.dropFirst(2).prefix(5)
            let part2 = digits.dropFirst(7)
            return "+55 \(area) \(part1)-\(part2)"
        }
        return "+\(digits)"
    }

    /// Considera stale quando a última extração com dados foi > 1h atrás.
    /// Threshold reduzido de 12h -> 1h em 2026-04-27 (Rafael): user merece saber
    /// que sync travou, não esperar meio dia. Pull-to-refresh força re-sync.
    private func isStale(_ isoDate: String?) -> Bool {
        guard let isoDate else { return false }
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else { return false }
        return Date().timeIntervalSince(date) > 3600 // 1h
    }
}

// MARK: - ConnectorState

struct ConnectorState {
    let id: String
    let name: String
    var status: ConnectionItemStatus = .disconnected
    var lastSync: String?          // "dados extraidos" — relativo (ex: "3h atras")
    var lastPing: String?          // "sessao viva" — relativo (so quando diferente de lastSync)
    var lastSyncAbsolute: String?  // "11 abr as 19:54" para sheet e ancora temporal
    var isStale: Bool = false      // true se lastSync > 12h (conectado mas dados velhos)
    var stats: [(value: Int, label: String)] = []
    var subtitle: String?
    var instanceUrl: String?
    var connectionId: String?
}
