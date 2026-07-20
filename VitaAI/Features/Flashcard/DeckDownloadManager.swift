import Foundation
import Observation

// MARK: - DeckDownloadManager — baixar baralho da Biblioteca (progresso + cancelar)
//
// Spec: flashcards-offline-download-por-baralho.md. Ação DELIBERADA do aluno:
// toca em baixar → barra de progresso → baixado → offline pra sempre.
// Mecanismo = o mesmo do Atlas 3D (URLSessionDownloadDelegate com fração), aqui
// centralizado num manager observável porque a lista de Baralhos precisa
// refletir o estado de vários baralhos ao mesmo tempo.
@MainActor
@Observable
final class DeckDownloadManager {
    static let shared = DeckDownloadManager()

    enum State: Equatable {
        case idle
        /// Baixando os bytes do pack (0...1).
        case downloading(Double)
        /// Baixou; extraindo/instalando no device (sem fração — é rápido e local).
        case installing
        case failed(String)
    }

    /// Estado por slug — a linha do baralho observa o seu.
    private(set) var states: [String: State] = [:]
    /// Baralhos instalados (slug → manifest), espelhado do disco pra a UI ler síncrono.
    private(set) var installed: [String: DeckPackStore.Manifest] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]

    func state(for slug: String) -> State { states[slug] ?? .idle }
    func isDownloaded(_ slug: String) -> Bool { installed[slug] != nil }
    func isBusy(_ slug: String) -> Bool {
        switch state(for: slug) {
        case .downloading, .installing: return true
        default: return false
        }
    }

    /// Relê o disco (chamar ao abrir a lista de Baralhos).
    func refreshInstalled() async {
        let manifests = await DeckPackStore.shared.allManifests()
        installed = Dictionary(uniqueKeysWithValues: manifests.map { ($0.slug, $0) })
    }

    func totalBytes() -> Int64 { installed.values.reduce(0) { $0 + $1.bytes } }

    // MARK: - Baixar / cancelar / remover

    func download(slug: String, title: String, tokenStore: TokenStore) {
        guard tasks[slug] == nil else { return }
        states[slug] = .downloading(0)
        tasks[slug] = Task { [weak self] in
            defer { Task { @MainActor in self?.tasks[slug] = nil } }
            do {
                let (packURL, version) = try await Self.fetchPack(
                    slug: slug,
                    token: await tokenStore.token,
                    onProgress: { fraction in
                        Task { @MainActor in self?.states[slug] = .downloading(fraction) }
                    }
                )
                if Task.isCancelled { return }
                await MainActor.run { self?.states[slug] = .installing }
                let manifest = try await DeckPackStore.shared.install(
                    packURL: packURL, slug: slug, title: title, version: version
                )
                try? FileManager.default.removeItem(at: packURL)
                DeckMediaResolver.invalidate()
                await MainActor.run {
                    self?.installed[slug] = manifest
                    self?.states[slug] = .idle
                }
            } catch is CancellationError {
                await MainActor.run { self?.states[slug] = .idle }
            } catch {
                NSLog("[DeckDownload] %@ falhou: %@", slug, error.localizedDescription)
                await MainActor.run { self?.states[slug] = .failed(error.localizedDescription) }
            }
        }
    }

    func cancel(slug: String) {
        tasks[slug]?.cancel()
        tasks[slug] = nil
        states[slug] = .idle
    }

    func remove(slug: String) async {
        await DeckPackStore.shared.remove(slug: slug)
        DeckMediaResolver.invalidate()
        installed[slug] = nil
        states[slug] = .idle
    }

    func clearError(slug: String) {
        if case .failed = state(for: slug) { states[slug] = .idle }
    }

    // MARK: - Rede

    private static func fetchPack(
        slug: String,
        token: String?,
        onProgress: @escaping (Double) -> Void
    ) async throws -> (URL, String) {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/study/flashcards/library/\(slug)/pack") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        if let token {
            request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
            request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
        }
        if let forwardedHost = AppConfig.localForwardedHostHeader {
            request.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
        }

        let delegate = PackDownloadDelegate(onProgress: onProgress)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        // Pack grande (Medicina ~ centenas de MB) em rede de faculdade: teto alto.
        config.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (tmpURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.serverError(http.statusCode)
        }
        let version = http.value(forHTTPHeaderField: "X-Pack-Version") ?? "1"

        // O arquivo temporário do URLSession some ao sair do escopo — move já.
        let kept = FileManager.default.temporaryDirectory
            .appendingPathComponent("pack-\(slug)-\(UUID().uuidString).apkg")
        try? FileManager.default.removeItem(at: kept)
        try FileManager.default.moveItem(at: tmpURL, to: kept)
        return (kept, version)
    }
}

/// Progresso do download (espelho do delegate do Atlas 3D).
private final class PackDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    // Exigido pelo protocolo; o arquivo é entregue pelo await session.download.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}
