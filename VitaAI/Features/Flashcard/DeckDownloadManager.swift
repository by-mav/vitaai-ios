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

    /// Progresso rico o bastante pra o aluno DECIDIR se espera ou desiste
    /// (Rafael 2026-07-20: "não mostrou porcentagem, nem velocidade, nem
    /// tamanho, nem sei se baixou — o usuário fica perdido"). Só a fração 0…1
    /// não basta: sem bytes e sem velocidade, um download parado e um lento
    /// são idênticos na tela.
    struct Progress: Equatable {
        let fraction: Double        // 0…1
        let received: Int64         // bytes já baixados
        let total: Int64            // bytes totais (0 = servidor não informou)
        let bytesPerSecond: Double  // velocidade média da janela recente

        /// "12,4 MB de 33,4 MB" — o que o aluno lê.
        var sizeText: String {
            let f = ByteCountFormatter()
            f.countStyle = .file
            let r = f.string(fromByteCount: received)
            return total > 0 ? "\(r) de \(f.string(fromByteCount: total))" : r
        }

        /// "2,1 MB/s" — vazio quando ainda não dá pra estimar.
        var speedText: String {
            guard bytesPerSecond > 1024 else { return "" }
            let f = ByteCountFormatter()
            f.countStyle = .file
            return "\(f.string(fromByteCount: Int64(bytesPerSecond)))/s"
        }

        /// "faltam ~8s" — só quando há total e velocidade confiáveis.
        var etaText: String {
            guard total > 0, bytesPerSecond > 1024 else { return "" }
            let restam = Double(total - received) / bytesPerSecond
            guard restam.isFinite, restam > 0 else { return "" }
            if restam < 60 { return "faltam ~\(Int(restam.rounded()))s" }
            return "faltam ~\(Int((restam / 60).rounded()))min"
        }
    }

    enum State: Equatable {
        case idle
        /// Baixando os bytes do pack — com números, não só a barra.
        case downloading(Progress)
        /// Baixou; extraindo/instalando no device. É local e rápido, mas PRECISA
        /// aparecer: sem isso a barra chega em 100% e a tela congela sem explicar.
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
        states[slug] = .downloading(.init(fraction: 0, received: 0, total: 0, bytesPerSecond: 0))
        tasks[slug] = Task { [weak self] in
            defer { Task { @MainActor in self?.tasks[slug] = nil } }
            do {
                let (packURL, version) = try await Self.fetchPack(
                    slug: slug,
                    token: await tokenStore.token,
                    onProgress: { progresso in
                        Task { @MainActor in self?.states[slug] = .downloading(progresso) }
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
        onProgress: @escaping (DeckDownloadManager.Progress) -> Void
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

/// Progresso do download. O sistema JÁ entrega bytes recebidos e total a cada
/// pedaço — antes a gente descartava isso e repassava só a fração, e a tela não
/// tinha como mostrar tamanho nem velocidade. Aqui aproveitamos tudo e medimos
/// a taxa numa janela curta (média instantânea oscila demais pra ser lida).
private final class PackDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (DeckDownloadManager.Progress) -> Void
    private var janelaInicio = Date()
    private var janelaBytes: Int64 = 0
    private var taxa: Double = 0

    init(onProgress: @escaping (DeckDownloadManager.Progress) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Velocidade por janela de ~0,5s: suaviza o serrilhado sem parecer travada.
        janelaBytes += bytesWritten
        let decorrido = Date().timeIntervalSince(janelaInicio)
        if decorrido >= 0.5 {
            let nova = Double(janelaBytes) / decorrido
            // média móvel leve — evita o número pulando a cada atualização
            taxa = taxa == 0 ? nova : (taxa * 0.6 + nova * 0.4)
            janelaBytes = 0
            janelaInicio = Date()
        }

        // `totalBytesExpectedToWrite` vem -1 quando o servidor não manda tamanho;
        // nesse caso ainda mostramos os bytes baixados (melhor que 0% mudo).
        let total = max(totalBytesExpectedToWrite, 0)
        let fracao = total > 0 ? Double(totalBytesWritten) / Double(total) : 0
        onProgress(
            .init(fraction: fracao, received: totalBytesWritten, total: total, bytesPerSecond: taxa)
        )
    }

    // Exigido pelo protocolo; o arquivo é entregue pelo await session.download.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}
