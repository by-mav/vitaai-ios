import Foundation
import Observation

// MARK: - State

struct CanvasConnectViewState {
    var isLoading: Bool = true
    var isConnected: Bool = false
    var status: String? = nil
    var instanceUrl: String = "https://ulbra.instructure.com"
    var lastSyncAt: String? = nil

    // Form
    var tokenInput: String = ""
    var instanceUrlInput: String = "https://ulbra.instructure.com"

    // Operations
    var isConnecting: Bool = false
    var isSyncing: Bool = false
    var isDisconnecting: Bool = false

    // Messages
    var error: String? = nil
    var successMessage: String? = nil

    // Sync results
    var lastSyncCourses: Int = 0
    var lastSyncFiles: Int = 0
    var lastSyncAssignments: Int = 0
}

// MARK: - ViewModel

@MainActor
@Observable
final class CanvasConnectViewModel {
    var state = CanvasConnectViewState()

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    func onAppear() {
        Task { await loadStatus() }
    }

    // MARK: - Input

    func updateTokenInput(_ value: String) {
        state.tokenInput = value
        state.error = nil
    }

    func updateInstanceUrlInput(_ value: String) {
        state.instanceUrlInput = value
        state.error = nil
    }

    // MARK: - Status

    func loadStatus() async {
        state.isLoading = true
        state.error = nil
        do {
            let status = try await api.getCanvasStatus()
            state.isLoading = false
            state.isConnected = status.connected
            state.status = status.status
            if let url = status.instanceUrl, !url.isEmpty {
                state.instanceUrl = url
            }
            state.lastSyncAt = status.lastSyncAt
        } catch {
            state.isLoading = false
            state.isConnected = false
        }
    }

    // MARK: - Connect

    func connect() {
        let token = state.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            state.error = "Insira o token de acesso do Canvas"
            return
        }
        Task {
            state.isConnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.connectCanvas(
                    accessToken: token,
                    instanceUrl: state.instanceUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                if result.success {
                    state.isConnecting = false
                    state.isConnected = true
                    state.status = "active"
                    state.tokenInput = ""
                    state.successMessage = "Canvas conectado com sucesso!"
                    // Auto-sync after connecting
                    await sync()
                } else {
                    state.isConnecting = false
                    state.error = result.error ?? "Falha ao conectar. Verifique o token."
                }
            } catch {
                state.isConnecting = false
                state.error = "Erro de conexão. Verifique sua internet."
            }
        }
    }

    // MARK: - Sync

    func sync() async {
        state.isSyncing = true
        state.error = nil
        state.successMessage = nil
        do {
            let result = try await api.syncCanvas()
            state.isSyncing = false
            state.lastSyncCourses = result.courses
            state.lastSyncFiles = result.files
            state.lastSyncAssignments = result.assignments
            state.successMessage = "Sincronizado: \(result.courses) disciplinas, \(result.files) arquivos, \(result.assignments) atividades"
            // Refresh status to get new lastSyncAt
            await loadStatus()
        } catch {
            state.isSyncing = false
            state.error = "Falha na sincronização"
        }
    }

    func syncNow() {
        Task { await sync() }
    }

    // MARK: - Disconnect

    func disconnect() {
        Task {
            state.isDisconnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                try await api.disconnectCanvas()
                state = CanvasConnectViewState(
                    isLoading: false,
                    isConnected: false,
                    successMessage: "Canvas desconectado"
                )
            } catch {
                state.isDisconnecting = false
                state.error = "Falha ao desconectar"
            }
        }
    }

    // MARK: - Sync via WebView cookies (universal Vita crawl)

    /// Called after WebView login: send cookies to Vita server-side crawler
    func syncWithWebView(cookies: String, instanceUrl: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            state.isSyncing = true
            state.error = nil
            state.successMessage = "Vita iniciando extração..."
            do {
                let result = try await api.startVitaCrawl(cookies: cookies, instanceUrl: instanceUrl)
                guard let syncId = result.syncId, !syncId.isEmpty else {
                    state.isSyncing = false
                    state.error = "Erro ao iniciar extração"
                    return
                }
                // Poll progress
                state.successMessage = "Vita extraindo dados do portal..."
                for _ in 0..<60 { // max 2 min
                    try await Task.sleep(for: .seconds(2))
                    let progress = try await api.getSyncProgress(syncId: syncId)
                    state.successMessage = progress.label.isEmpty ? "Vita trabalhando..." : progress.label
                    if progress.isDone {
                        state.isSyncing = false
                        state.isConnected = true
                        state.status = "active"
                        state.successMessage = progress.label.isEmpty ? "Extração completa!" : progress.label
                        await loadStatus()
                        return
                    }
                    if progress.isError {
                        state.isSyncing = false
                        state.error = progress.label.isEmpty ? "Erro na extração" : progress.label
                        return
                    }
                }
                // Timeout
                state.isSyncing = false
                state.successMessage = "Vita continua extraindo em background..."
            } catch {
                state.isSyncing = false
                state.error = "Erro: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        state.error = nil
        state.successMessage = nil
    }
}
