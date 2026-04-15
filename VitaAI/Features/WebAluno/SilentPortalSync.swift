import Foundation
import WebKit

/// Silent portal sync — runs on app launch to keep data fresh.
/// Uses persisted WKWebView cookies (same .default() data store as the login WebView).
/// If Mannesoft session is still valid, bridge.js extracts and syncs silently.
/// If session expired, marks connection as expired so the user sees a "Reconecte" banner.
@MainActor
final class SilentPortalSync {
    static let shared = SilentPortalSync()

    private let minSyncInterval: TimeInterval = 900 // 15 min between syncs
    private var sessionCheckURL: String = ""
    private var webView: WKWebView?
    private var bridgeHandler: SilentBridgeHandler?
    private var isRunning = false
    private var lastLocalSyncAttempt: Date?

    private init() {}

    /// Reset throttle so next syncIfNeeded runs immediately
    func resetThrottle() {
        lastLocalSyncAttempt = nil
    }

    /// Call on app foreground / dashboard appear.
    /// Does nothing if last sync was recent or no active connection exists.
    /// Also triggers Canvas silent reauth if needed.
    func syncIfNeeded(api: VitaAPI) {
        guard !isRunning else {
            NSLog("[SilentSync] Already running, skipping")
            return
        }
        isRunning = true  // Set immediately to prevent race conditions

        // Also check Canvas reauth (runs independently)
        CanvasSilentReauth.shared.reauthIfNeeded(api: api)

        Task {
            defer { if !self.isRunning { /* already cleaned up */ } }
            // Check if we have an active portal connection
            do {
                let status = try await api.getPortalStatus()
                guard status.connected else {
                    self.isRunning = false
                    return
                }

                // Get the portal connection for mannesoft/webaluno
                let conn = status.connections?.first(where: { $0.portalType == "mannesoft" || $0.portalType == "webaluno" })

                // Use LOCAL timestamp to gate syncs — server lastSyncAt gets polluted by cron keepalive
                if let lastAttempt = lastLocalSyncAttempt {
                    let elapsed = Date().timeIntervalSince(lastAttempt)
                    if elapsed < minSyncInterval {
                        NSLog("[SilentSync] Last local sync %.0fs ago, skipping (min: %.0fs)", elapsed, minSyncInterval)
                        self.isRunning = false
                        return
                    }
                }

                // Get instance URL from the connection (not hardcoded)
                guard let portalUrl = conn?.instanceUrl, !portalUrl.isEmpty else {
                    NSLog("[SilentSync] No portal instance URL found, skipping")
                    self.isRunning = false
                    return
                }
                let baseUrl = portalUrl.hasSuffix("/") ? portalUrl : portalUrl + "/"
                sessionCheckURL = baseUrl + (baseUrl.contains("/webaluno") ? "" : "webaluno/")

                NSLog("[SilentSync] Starting silent sync for %@", sessionCheckURL)
                lastLocalSyncAttempt = Date()
                await performSilentSync(api: api)
            } catch {
                NSLog("[SilentSync] Status check failed: %@", String(describing: error))
                self.isRunning = false
            }
        }
    }

    private func performSilentSync(api: VitaAPI) async {
        // isRunning already set by syncIfNeeded

        // PRIORITY 1: Reuse the SAME WKWebView from login (same browser fingerprint)
        // Mannesoft binds PHPSESSID to TLS/UA fingerprint — new WebView = session rejected
        let usingShared: Bool
        let wv: WKWebView

        if let shared = SharedPortalWebView.shared.webView {
            NSLog("[SilentSync] Reusing shared login WebView (same fingerprint)")
            wv = shared
            usingShared = true
            // Remove login coordinator's delegate — it would re-trigger OAuth on /webaluno/ load
            wv.navigationDelegate = nil
            wv.uiDelegate = nil
            // Register bridge handler on shared WebView
            let handler = SilentBridgeHandler()
            wv.configuration.userContentController.removeScriptMessageHandler(forName: "vitaBridge")
            wv.configuration.userContentController.add(handler, name: "vitaBridge")
            self.bridgeHandler = handler
        } else {
            NSLog("[SilentSync] No shared WebView — creating new one with persisted cookies")
            usingShared = false
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            // Match login WebView config EXACTLY — Mannesoft may fingerprint differences
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
            config.allowsInlineMediaPlayback = true
            config.defaultWebpagePreferences.preferredContentMode = .recommended

            let handler = SilentBridgeHandler()
            config.userContentController.add(handler, name: "vitaBridge")
            self.bridgeHandler = handler

            // Use realistic frame size — 1x1 may affect viewport/UA behavior
            let newWV = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
            wv = newWV

            // Inject persisted cookies
            if let stored = MannesoftCookieStore.load() {
                NSLog("[SilentSync] Using MannesoftCookieStore (%d chars)", stored.cookies.count)
                await injectCookies(stored.cookies, into: wv, for: sessionCheckURL)
            } else {
                let backendCookie = await fetchBackendSessionCookie(api: api)
                if let cookieStr = backendCookie {
                    let cleaned = cookieStr.replacingOccurrences(of: "PHPSESSID=PHPSESSID=", with: "PHPSESSID=")
                    NSLog("[SilentSync] Using backend cookie (%d chars)", cleaned.count)
                    await injectCookies(cleaned, into: wv, for: sessionCheckURL)
                } else {
                    NSLog("[SilentSync] No cookies available, skipping")
                    cleanup()
                    return
                }
            }
        }
        self.webView = wv

        // NEVER navigate to /webaluno/ root — it calls session_start() which kills the PHPSESSID.
        // Always navigate to /webaluno/index.php which reuses the existing session.
        let targetURL: String
        if usingShared, let lastURL = SharedPortalWebView.shared.lastURL, lastURL.contains("index.php") {
            targetURL = lastURL
            NSLog("[SilentSync] Using shared WebView's last URL: %@", targetURL)
        } else {
            // Replace /webaluno/ with /webaluno/index.php
            targetURL = sessionCheckURL.hasSuffix("/")
                ? sessionCheckURL + "index.php"
                : sessionCheckURL + "/index.php"
            NSLog("[SilentSync] Using index.php URL: %@", targetURL)
        }
        let url = URL(string: targetURL)!
        wv.load(URLRequest(url: url))

        // Wait for initial page load
        let loadResult = await waitForLoad(wv, timeout: 15)
        guard loadResult else {
            NSLog("[SilentSync] Page load timeout/failed")
            cleanup()
            return
        }

        // Mannesoft uses JS redirects (window.location = 'index.php?...')
        // After initial load, wait for JS to execute and trigger redirect
        var finalURL = wv.url?.absoluteString ?? ""
        NSLog("[SilentSync] Initial load URL: %@", finalURL)

        // Wait up to 8s for JS redirects to settle
        for i in 0..<16 {
            try? await Task.sleep(for: .milliseconds(500))
            let newURL = wv.url?.absoluteString ?? ""
            if newURL != finalURL {
                NSLog("[SilentSync] JS redirect detected: %@", newURL)
                finalURL = newURL
                // Wait for the new page to finish loading
                _ = await waitForLoad(wv, timeout: 10)
            }
            // If we're on a logged-in page, stop waiting
            if finalURL.contains("index.php") || finalURL.contains("modulo=") {
                break
            }
        }

        NSLog("[SilentSync] Final URL after redirects: %@", finalURL)

        // Check if we landed on logged-in page or login page
        // Mannesoft login page is ALSO at index.php — check page content, not just URL
        let isAuthPage = finalURL.contains("autenticacao") || finalURL.contains("oauth") || finalURL.contains("login")
        let pageHasLoginForm = (try? await wv.evaluateJavaScript("""
            document.body.innerHTML.indexOf('Esqueceu sua senha') !== -1
            || document.querySelector('input[name="cpf_email"]') !== null
            || document.querySelector('input[name="senha"]') !== null
            || document.querySelector('form[action*="autenticacao"]') !== null
            """) as? Bool) ?? false
        let isLoggedIn = (finalURL.contains("index.php") || finalURL.contains("modulo=")) && !pageHasLoginForm

        if !isLoggedIn || isAuthPage {
            NSLog("[SilentSync] Session expired (landed on: %@, loginForm: %@)", finalURL, pageHasLoginForm ? "yes" : "no")
            SharedPortalWebView.shared.release()
            MannesoftCookieStore.clear()
            cleanup()
            return
        }

        NSLog("[SilentSync] Session valid! Injecting bridge.js...")

        // Capture all relevant cookies (PHPSESSID + Cloudflare) for server-side sync
        let sessionCookie = await extractAllCookies(from: wv)

        // Wait 5s for page + iframes to fully render (Mannesoft uses frames for menus)
        try? await Task.sleep(for: .seconds(5))

        // Fetch and inject bridge.js
        guard let bridgeJS = await fetchBridgeJS(api: api) else {
            NSLog("[SilentSync] Could not fetch bridge.js")
            cleanup()
            return
        }

        // Mark: bridge not yet injected — ignore stale messages from login WebView
        bridgeHandler?.armed = false

        bridgeHandler?.onComplete = { [weak self] pages in
            guard let self else { return }
            Task { @MainActor in
                NSLog("[SilentSync] Bridge captured %d pages, sending to extract...", pages.count)
                // Re-persist cookies after bridge (PHP may have regenerated session)
                let freshCookies = await self.extractAllCookies(from: wv)
                if let fresh = freshCookies {
                    MannesoftCookieStore.save(fresh, domain: self.sessionCheckURL)
                    NSLog("[SilentSync] Re-persisted cookies after bridge extraction")
                }
                await self.sendToExtract(pages: pages, api: api, sessionCookie: freshCookies ?? sessionCookie)
                self.cleanup()
            }
        }

        bridgeHandler?.onError = { [weak self] error in
            NSLog("[SilentSync] Bridge error: %@", error)
            Task { @MainActor in self?.cleanup() }
        }

        // Quick pre-check: what does the page look like?
        let preCheck = try? await wv.evaluateJavaScript("""
            JSON.stringify({
                url: location.href,
                hostname: location.hostname,
                title: document.title,
                anchorsAll: document.querySelectorAll('a[href]').length,
                anchorsIndexPhp: document.querySelectorAll('a[href*="index.php?"]').length,
                frames: document.querySelectorAll('iframe, frame').length,
                bodyLen: document.body ? document.body.innerHTML.length : 0
            })
            """) as? String
        NSLog("[SilentSync] Pre-bridge page state: %@", preCheck ?? "nil")

        // Inject bridge.js — arm the handler AFTER injection
        bridgeHandler?.armed = true
        do {
            try await wv.evaluateJavaScript(bridgeJS)
            NSLog("[SilentSync] Bridge injected, waiting for extraction...")
        } catch {
            NSLog("[SilentSync] Bridge injection failed: %@", String(describing: error))
            cleanup()
            return
        }

        // Wait up to 30s for bridge to complete
        try? await Task.sleep(for: .seconds(30))
        if isRunning {
            NSLog("[SilentSync] Bridge timeout")
            cleanup()
        }
    }

    private func waitForLoad(_ wv: WKWebView, timeout: Int) async -> Bool {
        for _ in 0..<(timeout * 2) {
            try? await Task.sleep(for: .milliseconds(500))
            if !wv.isLoading { return true }
        }
        return false
    }

    /// Fetch the stored PHPSESSID from backend — works on any device
    private func fetchBackendSessionCookie(api: VitaAPI) async -> String? {
        guard let url = URL(string: AppConfig.apiBaseURL + "/portal/session-cookie") else { return nil }
        do {
            var request = URLRequest(url: url)
            let token = await TokenStore().token
            if let token {
                request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let cookie = json?["cookie"] as? String
            if let cookie, !cookie.isEmpty {
                NSLog("[SilentSync] Got backend cookie (%d chars)", cookie.count)
            }
            return cookie
        } catch {
            NSLog("[SilentSync] Backend cookie fetch failed: %@", String(describing: error))
            return nil
        }
    }

    /// Inject cookie string into WKWebView cookie store before page load
    private func injectCookies(_ cookieString: String, into webView: WKWebView, for urlString: String) async {
        guard let url = URL(string: urlString), let host = url.host else { return }
        let pairs = cookieString.components(separatedBy: "; ")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name, .value: value, .domain: host, .path: "/",
            ]
            if url.scheme == "https" { props[.secure] = true }
            if let cookie = HTTPCookie(properties: props) {
                await webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
        }
        NSLog("[SilentSync] Injected %d cookies for %@", pairs.count, host)
    }

    private func fetchBridgeJS(api: VitaAPI) async -> String? {
        guard let url = URL(string: AppConfig.apiBaseURL + "/portal/bridge") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func extractAllCookies(from webView: WKWebView) async -> String? {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        let relevant = cookies.filter { c in
            let n = c.name.lowercased()
            return n == "phpsessid" || n.hasPrefix("cf_") || n.hasPrefix("__cf")
        }
        guard !relevant.isEmpty else {
            NSLog("[SilentSync] No relevant cookies found")
            return nil
        }
        let str = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        NSLog("[SilentSync] Captured %d cookies for server-side sync", relevant.count)
        return str
    }

    private func sendToExtract(pages: [CapturedPortalPage], api: VitaAPI, sessionCookie: String? = nil) async {
        let apiPages = pages.map { page in
            PortalExtractRequestPagesInner(type: page.type, html: page.html, linkText: page.linkText)
        }
        guard !apiPages.isEmpty else { return }

        do {
            // Extract base domain from sessionCheckURL for instanceUrl
            let baseInstance = sessionCheckURL.components(separatedBy: "/webaluno").first ?? sessionCheckURL
            let result = try await api.extractPortalPages(
                pages: apiPages,
                instanceUrl: baseInstance,
                university: "",
                sessionCookie: sessionCookie
            )
            NSLog("[SilentSync] Extract done: grades=%d, schedule=%d", result.grades ?? 0, result.schedule ?? 0)
        } catch {
            NSLog("[SilentSync] Extract failed: %@", String(describing: error))
        }
    }

    private func cleanup() {
        // Don't destroy the shared WebView — it's reused across syncs
        if webView === SharedPortalWebView.shared.webView {
            // Just remove our bridge handler, keep the WebView alive
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "vitaBridge")
        } else {
            webView?.stopLoading()
            webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        }
        webView = nil
        bridgeHandler = nil
        isRunning = false
    }

    private func parseISO(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }
}

// MARK: - Silent bridge message handler

final class SilentBridgeHandler: NSObject, WKScriptMessageHandler {
    var onComplete: (([CapturedPortalPage]) -> Void)?
    var onError: ((String) -> Void)?
    var armed = false  // Ignore messages until bridge.js is actually injected

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "vitaBridge",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        if !armed {
            NSLog("[SilentSync] Ignoring stale bridge message (type=%@) — bridge not yet injected", type)
            return
        }

        switch type {
        case "vita-bridge-debug":
            // Log discovery debug info from bridge.js
            let menuCount = dict["menuLinksCount"] as? Int ?? -1
            let anchorsInDoc = dict["anchorsInDoc"] as? Int ?? -1
            let framesInDoc = dict["framesInDoc"] as? Int ?? -1
            let allAnchors = dict["allAnchors"] as? Int ?? -1
            let bodyLen = dict["bodyLength"] as? Int ?? -1
            let links = dict["menuLinks"] as? [String] ?? []
            NSLog("[SilentSync] Bridge debug: menuLinks=%d, anchors(index.php?)=%d, frames=%d, allAnchors=%d, bodyLen=%d, links=%@",
                  menuCount, anchorsInDoc, framesInDoc, allAnchors, bodyLen, links as NSArray)

        case "vita-bridge-complete":
            guard let pagesArray = dict["pages"] as? [[String: Any]] else { return }
            let pages = pagesArray.compactMap { pageDict -> CapturedPortalPage? in
                guard let type = pageDict["type"] as? String,
                      let html = pageDict["html"] as? String,
                      let linkText = pageDict["linkText"] as? String else { return nil }
                return CapturedPortalPage(type: type, html: html, linkText: linkText)
            }
            onComplete?(pages)

        case "vita-bridge-error":
            let error = dict["error"] as? String ?? "Unknown error"
            onError?(error)

        default:
            break
        }
    }
}
