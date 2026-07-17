import Foundation
import UIKit
import SafariServices
import Observation

// MARK: - ConnectorsViewModel

@MainActor
@Observable
final class ConnectorsViewModel {
    var canvas = ConnectorState(id: "canvas", name: "Canvas")
    var moodle = ConnectorState(id: "moodle", name: "Moodle")
    var calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
    var drive = ConnectorState(id: "google_drive", name: "Google Drive")
    var whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")

    var universityPortals: [UniversityPortal] = []
    var universityName = ""
    var universityCity = ""

    var toastMessage: String?
    var toastType: VitaToastType = .success
    var hasLoaded = false

    @ObservationIgnored private let api: VitaAPI
    @ObservationIgnored private weak var dataManager: AppDataManager?
    @ObservationIgnored private weak var presentedOAuthSafari: SFSafariViewController?
    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var isBackgroundSyncing = false

    init(api: VitaAPI, dataManager: AppDataManager? = nil) {
        self.api = api
        self.dataManager = dataManager

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .integrationOAuthCompleted,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    await self?.handleOAuthCompleted(provider: note.object as? String)
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .integrationOAuthFailed,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    await self?.handleOAuthFailed(
                        provider: note.object as? String,
                        reason: note.userInfo?["reason"] as? String
                    )
                }
            }
        )
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    var allIntegrations: [ConnectorState] {
        [calendar, drive, whatsapp]
    }

    var connectedCount: Int {
        ([canvas, moodle] + allIntegrations)
            .filter { $0.status == .connected }
            .count
    }

    var totalPortals: Int { 5 }

    func state(for portalID: String) -> ConnectorState {
        switch portalID {
        case "canvas": canvas
        case "moodle": moodle
        case "google_calendar": calendar
        case "google_drive": drive
        case "whatsapp": whatsapp
        default: ConnectorState(id: portalID, name: portalID)
        }
    }

    func loadAll() async {
        await loadUniversityPortals()
        await loadPortalConnections()
        await loadIntegrations()
        hasLoaded = true
    }

    /// Refresh visible state immediately, then update every connected provider
    /// concurrently. Canvas can legitimately take close to a minute, so making
    /// `.refreshable` await all providers would pin the native spinner and make
    /// a healthy screen look frozen.
    func refreshAndSync() async {
        await loadAll()

        guard !isBackgroundSyncing else { return }
        isBackgroundSyncing = true

        let syncCanvas = canvas.status == .connected
        let syncMoodle = moodle.status == .connected
        let moodleConnectionID = moodle.connectionId
        let syncCalendar = calendar.status == .connected
        let syncDrive = drive.status == .connected

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isBackgroundSyncing = false }

            async let canvasResult: Void = self.syncCanvasIfNeeded(syncCanvas)
            async let moodleResult: Void = self.syncMoodleIfNeeded(
                syncMoodle,
                connectionID: moodleConnectionID
            )
            async let calendarResult: Void = self.syncIntegrationIfNeeded(
                syncCalendar,
                provider: "google_calendar",
                displayName: "Google Calendar"
            )
            async let driveResult: Void = self.syncIntegrationIfNeeded(
                syncDrive,
                provider: "google_drive",
                displayName: "Google Drive"
            )

            _ = await (canvasResult, moodleResult, calendarResult, driveResult)
            await self.loadAll()
        }
    }

    private func syncCanvasIfNeeded(_ shouldSync: Bool) async {
        guard shouldSync else { return }
        do { try await api.triggerPortalSyncNow() }
        catch { logRefreshFailure("Canvas", error: error) }
    }

    private func syncMoodleIfNeeded(_ shouldSync: Bool, connectionID: String?) async {
        guard shouldSync else { return }
        do { _ = try await api.syncMoodle(connectionId: connectionID) }
        catch { logRefreshFailure("Moodle", error: error) }
    }

    private func syncIntegrationIfNeeded(
        _ shouldSync: Bool,
        provider: String,
        displayName: String
    ) async {
        guard shouldSync else { return }
        do { _ = try await api.syncIntegration(provider) }
        catch { logRefreshFailure(displayName, error: error) }
    }

    // MARK: University

    private func loadUniversityPortals() async {
        universityPortals = []
        universityName = ""
        universityCity = ""

        do {
            let profile: ProfileResponse
            if let cached = dataManager?.profile {
                profile = cached
            } else {
                profile = try await api.getProfile()
            }

            guard let universityID = profile.universityId, !universityID.isEmpty else {
                if let name = profile.university { universityName = name }
                return
            }

            let response = try await api.getUniversities(query: profile.university ?? "")
            if let university = response.universities.first(where: { $0.id == universityID }) {
                universityName = university.shortName.isEmpty
                    ? university.name
                    : university.shortName
                universityCity = university.city
                universityPortals = university.portals ?? []
            } else if let name = profile.university {
                universityName = name
            }
        } catch {
            NSLog("[Connectors] University metadata failed: %@", error.localizedDescription)
        }
    }

    // MARK: Learning portals

    func loadPortalConnections() async {
        do {
            let response = try await api.getCanvasStatus()
            canvas = ConnectorState(id: "canvas", name: "Canvas")
            moodle = ConnectorState(id: "moodle", name: "Moodle")
            for connection in response.connections ?? [] {
                applyPortalConnection(connection)
            }
        } catch {
            NSLog("[Connectors] Portal status failed: %@", error.localizedDescription)
        }
    }

    private func applyPortalConnection(_ connection: CanvasStatusResponse.PortalConnectionDetail) {
        guard let portalType = connection.portalType else { return }
        let status: ConnectionItemStatus
        switch connection.status {
        case "expired": status = .expired
        case "inactive", "disconnected": status = .disconnected
        default: status = .connected
        }

        let relativeSync = connection.lastSyncAt.flatMap(formatRelativeTime)
        let relativePing = connection.lastPingAt.flatMap(formatRelativeTime)
        let pingIsNewer = isLater(connection.lastPingAt, than: connection.lastSyncAt)
        let distinctPing = status == .connected
            && relativePing != nil
            && relativePing != relativeSync
            && pingIsNewer

        var state = ConnectorState(
            id: portalType,
            name: portalType == "moodle" ? "Moodle" : "Canvas"
        )
        state.status = status
        state.lastSync = relativeSync ?? relativePing
        state.lastPing = distinctPing ? relativePing : nil
        state.lastSyncAbsolute = connection.lastSyncAt.flatMap(formatAbsoluteTime)
        state.isStale = isStale(connection.lastSyncAt)
        state.instanceUrl = connection.instanceUrl
        state.connectionId = connection.id
        state.stats = [
            (
                connection.counts?.subjects ?? 0,
                String(localized: "connector_stat_subjects")
            ),
            (
                connection.counts?.evaluations ?? 0,
                String(localized: "connector_stat_activities")
            ),
            (
                connection.counts?.documents ?? 0,
                String(localized: "connector_stat_files")
            ),
        ]

        switch portalType {
        case "canvas": canvas = state
        case "moodle": moodle = state
        default: break
        }
    }

    // MARK: Google and WhatsApp

    private func loadIntegrations() async {
        await loadWhatsAppStatus()

        do {
            let response = try await api.getIntegrations()
            calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            drive = ConnectorState(id: "google_drive", name: "Google Drive")
            for provider in response.providers {
                switch provider.name {
                case "google_calendar":
                    applyIntegration(
                        provider,
                        to: &calendar,
                        countLabel: String(localized: "connector_stat_events")
                    )
                case "google_drive":
                    applyIntegration(
                        provider,
                        to: &drive,
                        countLabel: String(localized: "connector_stat_files")
                    )
                default:
                    break
                }
            }
        } catch {
            NSLog("[Connectors] Integrations status failed: %@", error.localizedDescription)
        }
    }

    private func applyIntegration(
        _ provider: IntegrationProviderInfo,
        to connector: inout ConnectorState,
        countLabel: String
    ) {
        connector.status = provider.connected
            ? connectionStatus(from: provider.status)
            : .disconnected
        connector.lastSync = provider.lastSyncAt.flatMap(formatRelativeTime)
        connector.lastSyncAbsolute = provider.lastSyncAt.flatMap(formatAbsoluteTime)
        connector.isStale = isStale(provider.lastSyncAt)
        connector.subtitle = provider.providerAccountEmail
        connector.stats = provider.counts.map { [($0.total, countLabel)] } ?? []
    }

    func loadWhatsAppStatus() async {
        do {
            let status = try await api.getWhatsAppStatus()
            var next = ConnectorState(id: "whatsapp", name: "WhatsApp")
            if status.verified, status.phone != nil {
                next.status = .connected
                next.subtitle = Self.maskPhone(status.phone)
            }
            whatsapp = next
        } catch {
            NSLog("[Connectors] WhatsApp status failed: %@", error.localizedDescription)
        }
    }

    func linkWhatsApp(phone: String) async throws {
        try await api.linkWhatsApp(phone: phone)
    }

    func verifyWhatsApp(code: String) async throws {
        let result = try await api.verifyWhatsApp(code: code)
        if result.verified { await loadWhatsAppStatus() }
    }

    // MARK: Connection lifecycle

    func disconnect(_ connectorID: String) async {
        do {
            switch connectorID {
            case "canvas":
                try await api.disconnectCanvas()
                canvas = ConnectorState(id: "canvas", name: "Canvas")
            case "moodle":
                try await api.disconnectPortal("moodle")
                moodle = ConnectorState(id: "moodle", name: "Moodle")
            case "google_calendar":
                try await api.disconnectIntegration("google_calendar")
                calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            case "google_drive":
                try await api.disconnectIntegration("google_drive")
                drive = ConnectorState(id: "google_drive", name: "Google Drive")
            case "whatsapp":
                try await api.unlinkWhatsApp()
                whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")
            default:
                return
            }
            toastMessage = String(localized: "connector_toast_disconnected")
            toastType = .success
        } catch {
            toastMessage = String(localized: "connector_toast_disconnect_error")
            toastType = .error
            NSLog("[Connectors] Disconnect failed: %@", error.localizedDescription)
        }
    }

    func connectIntegration(_ connectorID: String) async {
        guard connectorID == "google_calendar" || connectorID == "google_drive" else {
            return
        }

        setIntegrationStatus(connectorID, .loading)
        do {
            let response = try await api.startIntegrationOAuth(connectorID)
            guard let rawURL = response.authUrl, let url = URL(string: rawURL) else {
                setIntegrationStatus(connectorID, .disconnected)
                toastMessage = String(localized: "connector_toast_invalid_authorization")
                toastType = .error
                return
            }
            presentSafari(url: url)
        } catch {
            setIntegrationStatus(connectorID, .disconnected)
            toastMessage = String(localized: "connector_toast_connect_error")
            toastType = .error
        }
    }

    @MainActor
    private func presentSafari(url: URL) {
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
        presentedOAuthSafari = safari
        presenter.present(safari, animated: true)
    }

    private func handleOAuthCompleted(provider: String?) async {
        dismissOAuthSheet()
        guard let provider else {
            await loadAll()
            return
        }

        let displayName = Self.providerDisplayName(provider)
        toastMessage = String(
            format: String(localized: "connector_toast_connected_format"),
            displayName
        )
        toastType = .success

        do {
            _ = try await api.syncIntegration(provider)
        } catch {
            toastMessage = String(localized: "connector_toast_initial_sync_deferred")
        }
        await loadAll()
    }

    private func handleOAuthFailed(provider: String?, reason: String?) async {
        dismissOAuthSheet()
        let displayName = provider.map(Self.providerDisplayName)
            ?? String(localized: "connector_generic_name")
        toastMessage = reason == "access_denied"
            ? String(
                format: String(localized: "connector_toast_cancelled_format"),
                displayName
            )
            : String(
                format: String(localized: "connector_toast_connect_error_format"),
                displayName
            )
        toastType = .error
        await loadAll()
    }

    private func dismissOAuthSheet() {
        presentedOAuthSafari?.dismiss(animated: true)
        presentedOAuthSafari = nil
    }

    // MARK: Manual sync

    func syncCanvas() async {
        guard canvas.connectionId != nil || canvas.instanceUrl != nil else {
            toastMessage = String(localized: "connector_toast_canvas_reconnect")
            toastType = .error
            return
        }

        canvas.status = .loading
        do {
            if let connectionID = canvas.connectionId {
                _ = try await api.syncCanvas(connectionId: connectionID)
            } else {
                _ = try await api.syncCanvas()
            }
            toastMessage = String(localized: "connector_toast_canvas_updated")
            toastType = .success
            await loadPortalConnections()
        } catch {
            canvas.status = .expired
            toastMessage = String(localized: "connector_toast_canvas_expired")
            toastType = .error
        }
    }

    func syncMoodle() async {
        moodle.status = .loading
        do {
            _ = try await api.syncMoodle(connectionId: moodle.connectionId)
            await loadPortalConnections()
            toastMessage = String(localized: "connector_toast_moodle_updated")
            toastType = .success
        } catch {
            moodle.status = .expired
            toastMessage = String(localized: "connector_toast_moodle_reconnect")
            toastType = .error
        }
    }

    func syncCalendar() async {
        calendar.status = .loading
        do {
            _ = try await api.syncIntegration("google_calendar")
            await loadIntegrations()
            toastMessage = String(localized: "connector_toast_calendar_updated")
            toastType = .success
        } catch {
            calendar.status = .connected
            toastMessage = String(localized: "connector_toast_calendar_update_error")
            toastType = .error
        }
    }

    func syncDrive() async {
        drive.status = .loading
        do {
            _ = try await api.syncIntegration("google_drive")
            await loadIntegrations()
            toastMessage = String(localized: "connector_toast_drive_updated")
            toastType = .success
        } catch {
            drive.status = .connected
            toastMessage = String(localized: "connector_toast_drive_update_error")
            toastType = .error
        }
    }

    private func setIntegrationStatus(_ connectorID: String, _ status: ConnectionItemStatus) {
        switch connectorID {
        case "google_calendar": calendar.status = status
        case "google_drive": drive.status = status
        default: break
        }
    }

    private func connectionStatus(from status: String) -> ConnectionItemStatus {
        switch status {
        case "active", "connected": .connected
        case "expired": .expired
        default: .disconnected
        }
    }

    private static func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "google_calendar": "Google Calendar"
        case "google_drive": "Google Drive"
        default: provider
        }
    }

    // MARK: Formatting

    private func parseISO(_ rawDate: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate)
    }

    private func formatRelativeTime(_ rawDate: String) -> String? {
        guard let date = parseISO(rawDate) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatAbsoluteTime(_ rawDate: String) -> String? {
        guard let date = parseISO(rawDate) else { return nil }
        if Calendar.current.isDateInToday(date) {
            let time = DateFormatter.localizedString(
                from: date,
                dateStyle: .none,
                timeStyle: .short
            )
            return String(
                format: String(localized: "connector_time_today_format"),
                time
            )
        }
        return DateFormatter.localizedString(
            from: date,
            dateStyle: .medium,
            timeStyle: .short
        )
    }

    private func isLater(_ lhs: String?, than rhs: String?) -> Bool {
        guard let lhs, let lhsDate = parseISO(lhs) else { return false }
        guard let rhs, let rhsDate = parseISO(rhs) else { return true }
        return lhsDate > rhsDate
    }

    private func isStale(_ rawDate: String?) -> Bool {
        guard let rawDate, let date = parseISO(rawDate) else { return false }
        return Date().timeIntervalSince(date) > 3_600
    }

    private static func maskPhone(_ rawPhone: String?) -> String? {
        guard let rawPhone else { return nil }
        let digits = rawPhone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return String(
            format: String(localized: "connector_phone_mask_format"),
            String(digits.suffix(4))
        )
    }

    private func logRefreshFailure(_ provider: String, error: Error) {
        NSLog(
            "[Connectors] %@ refresh failed: %@",
            provider,
            error.localizedDescription
        )
    }
}

struct ConnectorState {
    let id: String
    let name: String
    var status: ConnectionItemStatus = .disconnected
    var lastSync: String?
    var lastPing: String?
    var lastSyncAbsolute: String?
    var isStale = false
    var stats: [(value: Int, label: String)] = []
    var subtitle: String?
    var instanceUrl: String?
    var connectionId: String?
}
