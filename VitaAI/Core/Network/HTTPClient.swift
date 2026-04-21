import Foundation

actor HTTPClient {
    private let session: URLSession
    private let tokenStore: TokenStore
    private let decoder: JSONDecoder
    let tokenRefresher: TokenRefresher

    /// Called when auth is permanently expired (refresh failed). Triggers logout.
    private var onUnauthorized: (@Sendable @MainActor () -> Void)?

    private static let maxRetries = 3

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.tokenRefresher = TokenRefresher(tokenStore: tokenStore)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Permissive date decoder: accepts ISO8601 (with or without fractional
        // seconds), Postgres-style "2026-04-13 17:56:11.365+00", and bare dates.
        // Before this, a single endpoint (e.g. /api/study/overview returning
        // lastReviewAt in Postgres format) would throw DecodingError.dataCorrupted
        // and silently null out the entire StudyOverviewResponse — that is why
        // the Flashcards hero was stuck at 0 even after the hydrate fix.
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            // Fast paths
            if let d = HTTPClient.iso8601Fractional.date(from: raw) { return d }
            if let d = HTTPClient.iso8601Plain.date(from: raw) { return d }

            // Postgres-style "YYYY-MM-DD HH:MM:SS[.frac][+00]" — normalize to ISO
            var normalized = raw.replacingOccurrences(of: " ", with: "T")
            if normalized.hasSuffix("+00") { normalized += ":00" }
            else if normalized.hasSuffix("-00") { normalized += ":00" }
            if let d = HTTPClient.iso8601Fractional.date(from: normalized) { return d }
            if let d = HTTPClient.iso8601Plain.date(from: normalized) { return d }

            // Bare date "YYYY-MM-DD"
            if let d = HTTPClient.dateOnly.date(from: raw) { return d }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(raw)"
            )
        }
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func setOnUnauthorized(_ handler: @escaping @Sendable @MainActor () -> Void) {
        self.onUnauthorized = handler
    }

    /// Exposes the configured URLSession for SSE streaming clients.
    nonisolated var urlSession: URLSession { session }

    // MARK: - Core request with retry + refresh

    func request<T: Decodable>(
        _ method: String = "GET",
        path: String,
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> T {
        guard var components = URLComponents(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var encodedBody: Data?
        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encodedBody = try encoder.encode(body)
        }

        if method != "GET" {
            NSLog("[HTTPClient] %@ %@ (body: %d bytes)", method, url.absoluteString, encodedBody?.count ?? 0)
            if let encodedBody, let bodyStr = String(data: encodedBody, encoding: .utf8) {
                NSLog("[HTTPClient] Body preview: %@", String(bodyStr.prefix(2000)))
                NSLog("[HTTPClient] Body tail: %@", String(bodyStr.suffix(500)))
            }
        }
        let (data, _) = try await performWithRetry {
            var request = URLRequest(url: url)
            request.httpMethod = method
            if let timeoutInterval {
                request.timeoutInterval = timeoutInterval
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = await self.tokenStore.token {
                request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                request.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }
            request.httpBody = encodedBody
            let traceId = UUID().uuidString.prefix(8).lowercased()
            request.setValue(String(traceId), forHTTPHeaderField: "X-Trace-Id")
            return request
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            NSLog("[HTTPClient] DECODE FAILED for %@: %@", String(describing: T.self), "\(error)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Convenience

    /// In-flight GET coalescing. When two screens ask for the same URL
    /// at the same time, only the FIRST request actually hits the server
    /// and the second one awaits the same Task. Released when the task
    /// finishes. Before this, Rafael navigating Dashboard → Flashcards
    /// caused 3× identical GET /api/study/flashcards in a 4-second window
    /// (EstudosViewModel + FlashcardsListScreen + AppDataManager triggers)
    /// which pushed backend tail latency to 11s under contention.
    ///
    /// Only applies to GET (mutation responses can't be coalesced safely).
    private var inFlightGets: [String: Task<Data, Error>] = [:]

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        NSLog("[HTTPClient] GET %@ (type: %@)", path, String(describing: T.self))

        // Build the same URL the request() helper would.
        guard var components = URLComponents(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        if let queryItems, !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw APIError.invalidURL }
        let key = "GET \(url.absoluteString)"

        // If an identical GET is already in flight, await its Data and decode locally.
        if let existing = inFlightGets[key] {
            NSLog("[HTTPClient] COALESCED GET %@", path)
            let data = try await existing.value
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }

        // First request — spawn the network Task, stash it, release on completion.
        let task = Task<Data, Error> { [weak self] in
            guard let self else { throw APIError.invalidURL }
            let (data, _) = try await self.performWithRetry {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = await self.tokenStore.token {
                    req.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                    req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
                }
                if let forwardedHost = AppConfig.localForwardedHostHeader {
                    req.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
                }
                let traceId = UUID().uuidString.prefix(8).lowercased()
                req.setValue(String(traceId), forHTTPHeaderField: "X-Trace-Id")
                return req
            }
            return data
        }
        inFlightGets[key] = task
        defer { inFlightGets[key] = nil }

        let data = try await task.value
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            NSLog("[HTTPClient] DECODE FAILED for %@: %@", String(describing: T.self), "\(error)")
            throw APIError.decodingError(error)
        }
    }

    func post<T: Decodable>(_ path: String, body: (any Encodable)? = nil, timeoutInterval: TimeInterval? = nil) async throws -> T {
        try await request("POST", path: path, body: body, timeoutInterval: timeoutInterval)
    }

    /// POST with pre-serialized JSON data (bypasses convertToSnakeCase encoding).
    func postRaw<T: Decodable>(_ path: String, body: Data, timeoutInterval: TimeInterval? = nil) async throws -> T {
        guard let url = URL(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        NSLog("[HTTPClient] POST %@ (raw body: %d bytes)", url.absoluteString, body.count)
        let (data, _) = try await performWithRetry {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            if let timeoutInterval { request.timeoutInterval = timeoutInterval }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = await self.tokenStore.token {
                request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                request.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }
            request.httpBody = body
            let traceId = UUID().uuidString.prefix(8).lowercased()
            request.setValue(String(traceId), forHTTPHeaderField: "X-Trace-Id")
            NSLog("[HTTPClient] traceId=%@ POST %@", traceId, url.absoluteString)
            return request
        }
        return try decoder.decode(T.self, from: data)
    }

    func patch<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        try await request("PATCH", path: path, body: body)
    }

    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: path)
    }

    func delete(_ path: String, queryItems: [URLQueryItem]) async throws {
        let _: EmptyResponse = try await request("DELETE", path: path, queryItems: queryItems)
    }

    /// Downloads raw binary data (e.g. PDF bytes) from the given path.
    func downloadRaw(_ path: String) async throws -> Data {
        guard let url = URL(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        let (data, _) = try await performWithRetry {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            if let token = await self.tokenStore.token {
                req.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                req.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }
            return req
        }
        return data
    }

    /// Downloads a text response (e.g. JavaScript) from the given path.
    func downloadText(_ path: String) async throws -> String {
        let data = try await downloadRaw(path)
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError(
                NSError(domain: "HTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response is not valid UTF-8 text"])
            )
        }
        return text
    }

    /// Uploads multiple images as multipart/form-data.
    /// `images`: array of (Data, filename, mimeType) tuples, each sent as field "files".
    func uploadMultipart<T: Decodable>(_ path: String, images: [(Data, String, String)]) async throws -> T {
        guard let url = URL(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"

        var body = Data()
        for (imageData, filename, mimeType) in images {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, _) = try await performWithRetry {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let token = await self.tokenStore.token {
                req.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                req.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }
            req.httpBody = body
            return req
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Uploads a single file (exam) with subjectId as multipart/form-data.
    /// Field names: "file" (the document) + "subjectId" (text field).
    func uploadExamMultipart<T: Decodable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        subjectId: String
    ) async throws -> T {
        guard let url = URL(string: AppConfig.apiBaseURL + "/" + path) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"

        var body = Data()
        // subjectId text field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"subjectId\"\r\n\r\n".data(using: .utf8)!)
        body.append(subjectId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, _) = try await performWithRetry {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let token = await self.tokenStore.token {
                req.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                req.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }
            req.httpBody = body
            let traceId = UUID().uuidString.prefix(8).lowercased()
            req.setValue(String(traceId), forHTTPHeaderField: "X-Trace-Id")
            return req
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Retry engine

    /// Executes an HTTP request with exponential backoff retry (5xx, network errors)
    /// and automatic token refresh on 401.
    private func performWithRetry(
        buildRequest: () async -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = APIError.unknown
        var didAttemptRefresh = false

        for attempt in 0..<Self.maxRetries {
            // Exponential backoff: 0s, 1s, 2s
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
            }

            let request = await buildRequest()

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                lastError = APIError.networkError(error)
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown
            }

            switch http.statusCode {
            case 200...299:
                if let urlStr = request.url?.absoluteString, urlStr.contains("portal") || urlStr.contains("webaluno") {
                    let raw = String(data: data, encoding: .utf8) ?? "(non-utf8)"
                    NSLog("[HTTPClient] 200 %@ raw: %@", urlStr, String(raw.prefix(500)))
                }
                return (data, http)
            case 401:
                if !didAttemptRefresh {
                    didAttemptRefresh = true
                    if await tokenRefresher.refreshSession() {
                        continue // retry with refreshed token
                    }
                }
                if let handler = onUnauthorized { await handler() }
                throw APIError.unauthorized
            case 500...599:
                if let body = String(data: data, encoding: .utf8) {
                    NSLog("[HTTPClient] %d error body: %@", http.statusCode, String(body.prefix(500)))
                }
                lastError = APIError.serverError(http.statusCode)
                continue
            default:
                if let body = String(data: data, encoding: .utf8) {
                    NSLog("[HTTPClient] %d error body: %@", http.statusCode, String(body.prefix(500)))
                }
                throw APIError.serverError(http.statusCode)
            }
        }

        throw lastError
    }

}

struct EmptyResponse: Decodable {}
