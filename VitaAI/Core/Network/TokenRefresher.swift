import Foundation

/// Shared token refresh logic used by HTTPClient and all SSE clients.
/// Ensures a single refresh path so token handling is consistent.
actor TokenRefresher {
    private let tokenStore: TokenStore
    private let session: URLSession

    /// Guards against concurrent refresh attempts — only one in-flight at a time.
    private var refreshTask: Task<Bool, Never>?

    init(tokenStore: TokenStore, session: URLSession? = nil) {
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    /// Attempts to refresh the session via Better Auth's get-session endpoint.
    /// Returns true if the session was refreshed (or is still valid).
    /// Serializes concurrent calls — only one refresh request in flight at a time.
    func refreshSession() async -> Bool {
        // If a refresh is already in progress, wait for it instead of firing another.
        if let existing = refreshTask {
            return await existing.value
        }

        let task = Task<Bool, Never> {
            defer { refreshTask = nil }

            guard let currentToken = await tokenStore.token,
                  let url = URL(string: AppConfig.authBaseURL + "/api/auth/get-session")
            else { return false }

            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("__Secure-better-auth.session_token=\(currentToken)", forHTTPHeaderField: "Cookie")
            if let forwardedHost = AppConfig.localForwardedHostHeader {
                req.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
            }

            guard let (_, response) = try? await session.data(for: req),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else { return false }

            // Better Auth may return a refreshed token in Set-Cookie
            if let setCookie = http.allHeaderFields["Set-Cookie"] as? String,
               let newToken = Self.extractSessionToken(from: setCookie) {
                await tokenStore.updateToken(newToken)
            }

            // 200 means session is valid (even without new cookie)
            return true
        }

        refreshTask = task
        return await task.value
    }

    // MARK: - Set-Cookie parser

    static func extractSessionToken(from setCookie: String) -> String? {
        for part in setCookie.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: "better-auth.session_token=") {
                let afterPrefix = trimmed[range.upperBound...]
                let value = afterPrefix.components(separatedBy: ";").first ?? ""
                let decoded = value.removingPercentEncoding ?? String(value)
                if !decoded.isEmpty { return decoded }
            }
        }
        return nil
    }
}
