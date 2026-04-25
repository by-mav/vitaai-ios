import Foundation

/// Single-connection SSE multiplexer pra GET /api/stream — gold-standard 2026
/// (ver shell.md secao 3.1 — REALTIME SYNC).
///
/// Mantem 1 conexao SSE persistente enquanto app foreground. Recebe frames
/// `id: <n>\ndata: <json>\n\n`, parseia, e despacha pro handler injetado
/// (em geral AppDataManager.applyEvent). Persiste ultimo id em UserDefaults
/// pra resume via Last-Event-ID na reconexao.
///
/// Backoff: 1s, 2s, 4s, 8s, 16s, 30s (cap). Reset apos primeiro frame
/// recebido com sucesso.
///
/// Vida util:
///   - VitaAIApp scenePhase=.active -> stream.connect()
///   - VitaAIApp scenePhase=.background -> stream.disconnect()
///
/// Auth: usa MESMO TokenStore que HTTPClient — header X-Extension-Token.
/// Backend resolve authId -> user_profiles.id pra LISTEN canal correto.
///
/// Implementacao usa URLSessionDataDelegate (urlSession:dataTask:didReceive:),
/// NAO URLSession.bytes — bytes() bufferiza frames pequenos no iOS, atrasando
/// entrega em ate ~10s. Delegate-based eh chunk-level e entrega imediato.
@MainActor
final class RealtimeStream {
    /// Frame parseado pronto pra aplicar no store.
    struct Event {
        let id: String
        let domain: String
        let op: String
        let recordId: String?
        let payload: [String: Any]?
    }

    typealias Handler = @MainActor (Event) -> Void

    var onEvent: Handler?
    private(set) var isConnected: Bool = false

    private let baseURL: URL
    private let tokenStore: TokenStore
    private var connectTask: Task<Void, Never>?
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var delegateBox: StreamDelegate?

    private static let lastEventIdKey = "vita.realtime.lastEventId"
    private var lastEventId: String? {
        get { UserDefaults.standard.string(forKey: Self.lastEventIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastEventIdKey) }
    }

    init(baseURL: URL, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    func connect() {
        guard connectTask == nil else { return }
        connectTask = Task { [weak self] in await self?.runWithBackoff() }
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        delegateBox = nil
        isConnected = false
    }

    // MARK: - Run loop

    private func runWithBackoff() async {
        var attempt = 0
        while !Task.isCancelled {
            let connected = await runOnce()
            if connected {
                attempt = 0  // reset backoff after successful connection
            } else {
                attempt += 1
            }
            if Task.isCancelled { return }
            let backoff = min(pow(2.0, Double(attempt)), 30.0)
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
        }
    }

    /// Returns true if connection opened successfully (regardless of duration).
    /// Returns false on immediate failure (network error, non-2xx).
    private func runOnce() async -> Bool {
        let url = baseURL.appendingPathComponent("/stream")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let token = await tokenStore.token {
            req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
        }
        if let lastId = lastEventId {
            req.setValue(lastId, forHTTPHeaderField: "Last-Event-ID")
        }

        // Delegate eh dono do parsing. Continuation pra esperar conexao
        // terminar (sucesso ou erro) — nao retornamos dessa funcao enquanto
        // stream estiver vivo.
        let delegate = StreamDelegate(
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let id = event.id { self.lastEventId = id }
                    self.onEvent?(Event(
                        id: event.id ?? "?",
                        domain: event.domain,
                        op: event.op,
                        recordId: event.recordId,
                        payload: event.payload
                    ))
                }
            }
        )
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        self.delegateBox = delegate
        self.session = session

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let task = session.dataTask(with: req)
            self.dataTask = task

            delegate.onConnect = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isConnected = true
                    NSLog("[RealtimeStream] connected (resume=%@)", self?.lastEventId ?? "none")
                }
            }
            delegate.onComplete = { [weak self] success in
                Task { @MainActor [weak self] in
                    self?.isConnected = false
                }
                cont.resume(returning: success)
            }
            task.resume()
        }
    }
}

// MARK: - Delegate (chunk-level SSE parser)

private final class StreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    struct ParsedEvent {
        let id: String?
        let domain: String
        let op: String
        let recordId: String?
        let payload: [String: Any]?
    }

    private let onEventCallback: (ParsedEvent) -> Void
    var onConnect: (() -> Void)?
    var onComplete: ((Bool) -> Void)?

    private let lock = NSLock()
    private var buffer = Data()
    private var pendingId: String?
    private var pendingData: String?
    private var didReceive2xx = false

    init(onEvent: @escaping (ParsedEvent) -> Void) {
        self.onEventCallback = onEvent
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            didReceive2xx = true
            onConnect?()
            completionHandler(.allow)
        } else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[RealtimeStream] non-2xx: %d", code)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)

        // Parse linhas terminadas em \n. SSE separa frames por \n\n (linha vazia).
        while let nlRange = buffer.range(of: Data([0x0A])) {  // 0x0A = '\n'
            let lineData = buffer.subdata(in: 0..<nlRange.lowerBound)
            buffer.removeSubrange(0..<nlRange.upperBound)

            // Trim trailing \r se presente
            var lineBytes = lineData
            if let last = lineBytes.last, last == 0x0D {
                lineBytes.removeLast()
            }
            let line = String(data: lineBytes, encoding: .utf8) ?? ""

            if line.isEmpty {
                // End-of-frame
                if let data = pendingData {
                    dispatch(id: pendingId, data: data)
                }
                pendingId = nil
                pendingData = nil
            } else if line.hasPrefix(":") {
                // Comment / heartbeat — ignore
            } else if line.hasPrefix("id:") {
                pendingId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                pendingData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("[RealtimeStream] complete with error: %@", "\(error)")
        }
        onComplete?(didReceive2xx)
    }

    private func dispatch(id: String?, data: String) {
        guard
            let raw = data.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let domain = json["domain"] as? String,
            let op = json["op"] as? String
        else {
            NSLog("[RealtimeStream] failed to parse frame: %@", String(data.prefix(200)))
            return
        }
        let recordId = json["recordId"] as? String
        let payload = json["payload"] as? [String: Any]
        onEventCallback(ParsedEvent(id: id, domain: domain, op: op, recordId: recordId, payload: payload))
    }
}
