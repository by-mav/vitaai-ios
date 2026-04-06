import Foundation
import Observation

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
                let url = state.instanceUrl.isEmpty ? "https://ac3949.mannesoftprime.com.br" : state.instanceUrl
                // Start Vita server-side crawl with cookies
                let crawlResult = try await api.startVitaCrawl(cookies: sessionCookie, instanceUrl: url)
                state.isConnecting = false
                state.isConnected = true
                state.status = "active"
                state.successMessage = "Vita extraindo dados do portal..."
                // Poll progress
                if let syncId = crawlResult.syncId, !syncId.isEmpty {
                    for _ in 0..<60 {
                        try await Task.sleep(for: .seconds(2))
                        let progress = try await api.getSyncProgress(syncId: syncId)
                        state.successMessage = (progress.label ?? "").isEmpty ? "Vita trabalhando..." : (progress.label ?? "")
                        if progress.isDone {
                            state.gradesCount = progress.grades ?? 0
                            state.scheduleCount = progress.schedule ?? 0
                            state.successMessage = "Extração completa! \(progress.grades ?? 0) notas, \(progress.schedule ?? 0) aulas"
                            await loadStatus()
                            return
                        }
                        if progress.isError {
                            state.error = (progress.label ?? "").isEmpty ? "Erro na extração" : (progress.label ?? "")
                            return
                        }
                    }
                    state.successMessage = "Vita continua em background..."
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
