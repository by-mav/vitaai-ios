import Foundation

// MARK: - State

struct WebAlunoConnectViewState {
    var isLoading: Bool = true
    var isConnected: Bool = false
    var status: String? = nil
    var instanceUrl: String = ""
    var lastSyncAt: String? = nil

    // Data counts
    var gradesCount: Int = 0
    var scheduleCount: Int = 0
    var semestersCount: Int = 0

    // Operations
    var isConnecting: Bool = false
    var isSyncing: Bool = false

    // Messages
    var error: String? = nil
    var successMessage: String? = nil
}

// MARK: - ViewModel

@MainActor
@Observable
final class WebAlunoConnectViewModel {
    var state = WebAlunoConnectViewState()

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    func onAppear() {
        Task { await loadStatus() }
    }

    // MARK: - Status

    func loadStatus() async {
        state.isLoading = true
        state.error = nil
        do {
            let resp = try await api.getWebalunoStatus()
            state.isLoading = false
            state.isConnected = resp.connected
            state.status = resp.connection?.status
            state.instanceUrl = resp.connection?.instanceUrl ?? ""
            state.lastSyncAt = resp.connection?.lastSyncAt
            state.gradesCount = resp.counts?.grades ?? 0
            state.scheduleCount = resp.counts?.schedule ?? 0
            state.semestersCount = resp.counts?.semesters ?? 0
        } catch {
            state.isLoading = false
            state.isConnected = false
        }
    }

    // MARK: - Connect with session cookie (from WebView)

    func connectWithSession(_ sessionCookie: String) {
        Task {
            state.isConnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.connectWebalunoWithSession(
                    sessionCookie: sessionCookie
                )
                if result.success {
                    state.isConnecting = false
                    state.isConnected = true
                    state.status = "active"
                    state.gradesCount = result.grades
                    state.scheduleCount = result.schedule
                    state.successMessage = "WebAluno conectado! \(result.grades) notas, \(result.schedule) aulas importadas."
                } else {
                    state.isConnecting = false
                    state.error = result.error ?? "Sessão inválida ou expirada. Tente novamente."
                }
            } catch {
                state.isConnecting = false
                state.error = "Erro de conexão. Verifique sua internet."
            }
        }
    }

    // MARK: - Sync

    func sync() {
        Task {
            state.isSyncing = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.syncWebaluno()
                if result.success {
                    state.isSyncing = false
                    state.gradesCount = result.grades
                    state.scheduleCount = result.schedule
                    state.successMessage = "Sincronizado: \(result.grades) notas, \(result.schedule) aulas"
                    await loadStatus()
                } else {
                    state.isSyncing = false
                    state.error = result.error ?? "Falha na sincronização"
                }
            } catch {
                state.isSyncing = false
                state.error = "Falha na sincronização"
            }
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        state.error = nil
        state.successMessage = nil
    }
}
