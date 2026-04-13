import Foundation

// MARK: - Domain Types

struct TranscriptionFlashcard: Identifiable, Sendable {
    let id: String
    let front: String
    let back: String
}

/// A saved transcription entry returned by GET /api/study/transcrição
struct TranscricaoEntry: Decodable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var duration: String?
    var detail: String?
    var date: String?
    var status: String? // "transcribed", "pending"
    var discipline: String?
    var fileName: String?
    var fileSize: Int?
    var createdAt: String?

    var isTranscribed: Bool {
        let s = status?.lowercased() ?? ""
        return s == "transcribed" || s == "completed" || s == "ready"
    }

    /// Parse createdAt ISO string into Date for grouping
    var parsedDate: Date? {
        guard let str = createdAt ?? date else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }

    /// Human-readable relative date
    var relativeDate: String {
        guard let d = parsedDate else { return date ?? "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return "Hoje \(fmt.string(from: d))"
        }
        if cal.isDateInYesterday(d) { return "Ontem" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: d)
    }

    /// File size formatted
    var formattedSize: String? {
        guard let s = fileSize, s > 0 else { return nil }
        if s < 1024 * 1024 {
            return "\(s / 1024) KB"
        }
        return String(format: "%.1f MB", Double(s) / 1_048_576.0)
    }
}

enum TranscricaoSSEEvent: Sendable {
    case progress(stage: String, percent: Int)
    case complete(transcript: String, summary: String, flashcards: [TranscriptionFlashcard])
    case error(message: String)
}

// MARK: - TranscricaoClient
//
// Actor-based SSE client for audio upload + streaming transcription pipeline.
// Mirrors Android's TranscricaoSseClient pattern: multipart/form-data POST -> SSE response.
//
// Endpoint: POST /ai/transcribe
// Events:  { type: "progress", stage, percent }
//          { type: "complete", transcript, summary, flashcards }
//          { type: "error", message }

actor TranscricaoClient {
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
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
        self.tokenRefresher = tokenRefresher ?? TokenRefresher(tokenStore: tokenStore)
    }

    func setOnUnauthorized(_ handler: @escaping @Sendable @MainActor () -> Void) {
        self.onUnauthorized = handler
    }

    // MARK: - Upload + Stream

    /// Uploads audio file and returns an SSE stream with progress/completion events.
    func uploadAndStream(fileURL: URL) -> AsyncThrowingStream<TranscricaoSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let fileData = try? Data(contentsOf: fileURL) else {
                        continuation.finish(throwing: APIError.noData)
                        return
                    }

                    let boundary = "VitaBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                    var body = Data()
                    body.append(formPart(boundary: boundary, name: "audio", filename: "audio.m4a",
                                         contentType: "audio/m4a", data: fileData))
                    body.append("--\(boundary)--\r\n".utf8Data)

                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/transcribe") else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    var didAttemptRefresh = false
                    var lastError: Error = APIError.unknown

                    for attempt in 0..<Self.maxRetries {
                        if attempt > 0 {
                            let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: delay)
                        }

                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.httpBody = body
                        request.timeoutInterval = 180

                        if let token = await self.tokenStore.token {
                            request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
                        }

                        let bytes: URLSession.AsyncBytes
                        let response: URLResponse
                        do {
                            (bytes, response) = try await self.session.bytes(for: request)
                        } catch {
                            lastError = APIError.networkError(error)
                            continue
                        }

                        guard let httpResponse = response as? HTTPURLResponse else {
                            lastError = APIError.unknown
                            continue
                        }

                        if httpResponse.statusCode == 401 {
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

                        guard (200...299).contains(httpResponse.statusCode) else {
                            if (500...599).contains(httpResponse.statusCode) {
                                lastError = APIError.serverError(httpResponse.statusCode)
                                continue
                            }
                            continuation.finish(throwing: APIError.serverError(httpResponse.statusCode))
                            return
                        }

                        // Connected — stream events (no retry mid-stream)
                        var eventType = ""
                        var dataLines: [String] = []

                        for try await line in bytes.lines {
                            if line.hasPrefix("event:") {
                                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            } else if line.hasPrefix("data:") {
                                let content = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                dataLines.append(content)
                            } else if line.isEmpty, !dataLines.isEmpty {
                                let rawJSON = dataLines.joined(separator: "\n")
                                dataLines = []
                                if let event = Self.parse(type: eventType, data: rawJSON) {
                                    continuation.yield(event)
                                    switch event {
                                    case .complete, .error:
                                        continuation.finish()
                                        return
                                    default:
                                        break
                                    }
                                }
                                eventType = ""
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

    // MARK: - Multipart Builder

    private func formPart(boundary: String, name: String, filename: String,
                          contentType: String, data: Data) -> Data {
        var part = Data()
        part.append("--\(boundary)\r\n".utf8Data)
        part.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8Data)
        part.append("Content-Type: \(contentType)\r\n\r\n".utf8Data)
        part.append(data)
        part.append("\r\n".utf8Data)
        return part
    }

    // MARK: - SSE Parser

    private static func parse(type: String, data: String) -> TranscricaoSSEEvent? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return nil }

        switch type {
        case "progress":
            return .progress(
                stage: json["stage"] as? String ?? "",
                percent: json["percent"] as? Int ?? 0
            )
        case "complete":
            let transcript = json["transcript"] as? String ?? ""
            let summary = json["summary"] as? String ?? ""
            let rawCards = json["flashcards"] as? [[String: String]] ?? []
            let cards = rawCards.enumerated().map { idx, card in
                TranscriptionFlashcard(
                    id: card["id"] ?? "\(idx)",
                    front: card["front"] ?? "",
                    back: card["back"] ?? ""
                )
            }
            return .complete(transcript: transcript, summary: summary, flashcards: cards)
        case "error":
            return .error(message: json["message"] as? String ?? "Erro desconhecido")
        default:
            return nil
        }
    }
}

// MARK: - Helper

private extension String {
    var utf8Data: Data { data(using: .utf8) ?? Data() }
}
