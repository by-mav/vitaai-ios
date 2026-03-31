import Foundation

// MARK: - OsceSseClient
// Streams OSCE evaluations from the backend using Server-Sent Events.
// Mirrors VitaChatClient pattern with retry + token refresh.

actor OsceSseClient {
    private let tokenStore: TokenStore
    private let session: URLSession
    private let tokenRefresher: TokenRefresher
    private var onUnauthorized: (@Sendable @MainActor () -> Void)?

    private static let maxRetries = 3

    init(tokenStore: TokenStore, tokenRefresher: TokenRefresher? = nil, session: URLSession? = nil) {
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
        self.tokenRefresher = tokenRefresher ?? TokenRefresher(tokenStore: tokenStore)
    }

    func setOnUnauthorized(_ handler: @escaping @Sendable @MainActor () -> Void) {
        self.onUnauthorized = handler
    }

    enum OsceEvent: Sendable {
        case textDelta(String)
        case stepComplete(currentStep: Int, stepName: String, score: Int?)
        case done
        case error(String)
    }

    func streamRespond(attemptId: String, response: String) -> AsyncThrowingStream<OsceEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/osce/\(attemptId)/answer") else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    let encodedBody = try encoder.encode(OsceRespondRequest(response: response))

                    var didAttemptRefresh = false
                    var lastError: Error = APIError.unknown

                    for attempt in 0..<Self.maxRetries {
                        if attempt > 0 {
                            let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: delay)
                        }

                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.httpBody = encodedBody

                        if let token = await self.tokenStore.token {
                            request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
                        }

                        let bytes: URLSession.AsyncBytes
                        let urlResponse: URLResponse
                        do {
                            (bytes, urlResponse) = try await self.session.bytes(for: request)
                        } catch {
                            lastError = APIError.networkError(error)
                            continue
                        }

                        guard let http = urlResponse as? HTTPURLResponse else {
                            lastError = APIError.unknown
                            continue
                        }

                        if http.statusCode == 401 {
                            if !didAttemptRefresh {
                                didAttemptRefresh = true
                                if await self.tokenRefresher.refreshSession() {
                                    continue
                                }
                            }
                            if let handler = self.onUnauthorized { await handler() }
                            continuation.finish(throwing: APIError.unauthorized)
                            return
                        }

                        guard (200...299).contains(http.statusCode) else {
                            if (500...599).contains(http.statusCode) {
                                lastError = APIError.serverError(http.statusCode)
                                continue
                            }
                            continuation.finish(throwing: APIError.serverError(http.statusCode))
                            return
                        }

                        // Connected — stream events (no retry mid-stream)
                        var eventType = ""
                        var eventData = ""

                        for try await line in bytes.lines {
                            if line.hasPrefix("event:") {
                                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            } else if line.hasPrefix("data:") {
                                eventData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                                switch eventType {
                                case "text_delta":
                                    if let data = eventData.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let text = json["text"] as? String {
                                        continuation.yield(.textDelta(text))
                                    }
                                case "step_complete":
                                    if let data = eventData.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                        let nextStep = json["current_step"] as? Int ?? 1
                                        let name = json["step_name"] as? String ?? ""
                                        let score = json["score"] as? Int
                                        continuation.yield(.stepComplete(currentStep: nextStep, stepName: name, score: score))
                                    }
                                case "done":
                                    continuation.yield(.done)
                                    continuation.finish()
                                    return
                                case "error":
                                    continuation.yield(.error(eventData))
                                    continuation.finish()
                                    return
                                default:
                                    break
                                }

                                eventType = ""
                                eventData = ""
                            }
                        }

                        continuation.finish()
                        return
                    }

                    // All retries exhausted
                    continuation.finish(throwing: lastError)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
