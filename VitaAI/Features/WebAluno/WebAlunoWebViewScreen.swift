import SwiftUI
import WebKit

// MARK: - Constants

/// Landing page — loads first to establish Mannesoft domain cookies,
/// then auto-triggers loginGoogle() to start OAuth flow.
// MARK: - WebAlunoWebViewScreen

/// Presents the WebAluno portal in a WKWebView.
/// Loads /webaluno/ to establish cookies, then auto-redirects to Google OAuth
/// with login_hint so the user never types their email again.
struct WebAlunoWebViewScreen: View {
    var onBack: () -> Void
    /// Called once when a valid PHPSESSID is detected after login
    var onSessionCaptured: (String) -> Void
    /// Called when bridge.js extracts pages from the portal
    var onPagesExtracted: (([CapturedPortalPage]) -> Void)?
    /// User's institutional email from VitaAI login — used as login_hint for Google OAuth
    var userEmail: String?
    /// Portal instance URL — comes from university portal config, no hardcoded fallback
    var portalInstanceUrl: String = ""

    /// Build the webaluno URL from the portal instance URL
    private var webalunoWebURL: String {
        guard !portalInstanceUrl.isEmpty else { return "" }
        let base = portalInstanceUrl.hasSuffix("/") ? portalInstanceUrl : portalInstanceUrl + "/"
        return base.contains("/webaluno") ? base : base + "webaluno/"
    }

    @State private var isLoading: Bool = true
    @State private var loadProgress: Double = 0

    var body: some View {
        ZStack {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                navBar

                // Loading progress bar
                if isLoading {
                    ProgressView(value: loadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: VitaColors.accent))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.2), value: loadProgress)
                }

                // WebView — loads portal, auto-triggers Google OAuth with login_hint
                if let url = URL(string: webalunoWebURL), !webalunoWebURL.isEmpty {
                    WebAlunoWebView(
                        url: url,
                        userEmail: userEmail,
                        isLoading: $isLoading,
                        loadProgress: $loadProgress,
                        onSessionCaptured: onSessionCaptured,
                        onPagesExtracted: onPagesExtracted
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(VitaColors.accent)
                        Text("URL do portal não configurada")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Verifique a configuração do conector")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Voltar")
                        .font(VitaTypography.bodyLarge)
                }
                .foregroundColor(VitaColors.accent)
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Conectar WebAluno")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color(red: 0.06, green: 0.04, blue: 0.03))
        .zIndex(1)
    }
}

// MARK: - WebAlunoWebView (UIViewRepresentable)

struct WebAlunoWebView: UIViewRepresentable {
    let url: URL
    let userEmail: String?
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    var onSessionCaptured: (String) -> Void
    /// Called when bridge.js extracts pages from the portal (after session capture)
    var onPagesExtracted: (([CapturedPortalPage]) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Only clear PHPSESSID for fresh login — NEVER clear all cookies.
        // Cloudflare uses __cf_bm and cf_clearance for bot detection;
        // wiping them triggers "You have been blocked".
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.name.lowercased() == "phpsessid" {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Allow all content — equivalent to Android's mixed content compat
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsInlineMediaPlayback = true

        // DO NOT set customUserAgent — WKWebView's default UA is already a real Safari UA.
        // Hardcoded UA mismatches TLS fingerprint and triggers Cloudflare bot detection.
        // Google OAuth works with the default WKWebView UA.

        // Use .recommended so WKWebView auto-scales desktop-layout pages to fit.
        // .mobile forces a narrow viewport that clips fixed-width sites like Mannesoft.
        configuration.defaultWebpagePreferences.preferredContentMode = .recommended

        // Register vitaBridge message handler for bridge.js extraction
        configuration.userContentController.add(context.coordinator, name: "vitaBridge")

        // Inject viewport meta BEFORE page renders so fixed-width pages scale to fit
        let viewportScript = WKUserScript(
            source: """
                var vp = document.createElement('meta');
                vp.name = 'viewport';
                vp.content = 'width=device-width, initial-scale=1.0, shrink-to-fit=yes';
                document.head.appendChild(vp);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(viewportScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true

        // Progress binding
        context.coordinator.webView = webView
        context.coordinator.progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.new]
        ) { _, change in
            DispatchQueue.main.async {
                self.loadProgress = change.newValue ?? 0
            }
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebAlunoWebView
        var webView: WKWebView?
        var sessionFound = false
        var bridgeInjected = false
        var progressObservation: NSKeyValueObservation?

        init(parent: WebAlunoWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
        }

        // MARK: - WKScriptMessageHandler (bridge.js messages)

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "vitaBridge",
                  let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }

            switch type {
            case "vita-bridge-progress":
                let label = dict["label"] as? String ?? ""
                NSLog("[WebAluno/Bridge] Progress: %@", label)

            case "vita-bridge-complete":
                guard let pagesArray = dict["pages"] as? [[String: Any]] else { return }
                let pages = pagesArray.compactMap { pageDict -> CapturedPortalPage? in
                    guard let pType = pageDict["type"] as? String,
                          let html = pageDict["html"] as? String,
                          let linkText = pageDict["linkText"] as? String else { return nil }
                    return CapturedPortalPage(type: pType, html: html, linkText: linkText)
                }
                NSLog("[WebAluno/Bridge] Extraction complete: %d pages", pages.count)

                // Re-save cookies AFTER bridge.js — PHP may have regenerated the session
                if let wv = webView {
                    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                        let portalCookies = cookies.filter { $0.domain.contains("mannesoftprime") }
                        let cookieStr = portalCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                        if !cookieStr.isEmpty {
                            MannesoftCookieStore.save(cookieStr, domain: wv.url?.absoluteString ?? "")
                            NSLog("[WebAluno/Bridge] Re-persisted %d cookies after bridge (%d chars)", portalCookies.count, cookieStr.count)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.parent.onPagesExtracted?(pages)
                }

            case "vita-bridge-error":
                let error = dict["error"] as? String ?? "Unknown"
                NSLog("[WebAluno/Bridge] Error: %@", error)

            default:
                break
            }
        }

        // Keep all navigation inside the WebView
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }

            // Force page to fit screen width — Mannesoft has fixed-width desktop layout.
            // shrink-to-fit=yes makes WKWebView scale the page down to fit the viewport.
            let viewportFix = """
                (function() {
                    var vp = document.querySelector('meta[name=viewport]');
                    if (vp) {
                        vp.content = 'width=device-width, initial-scale=1.0, shrink-to-fit=yes';
                    } else {
                        vp = document.createElement('meta');
                        vp.name = 'viewport';
                        vp.content = 'width=device-width, initial-scale=1.0, shrink-to-fit=yes';
                        document.head.appendChild(vp);
                    }
                })();
            """
            webView.evaluateJavaScript(viewportFix, completionHandler: nil)

            guard !sessionFound else { return }

            let currentURL = webView.url?.absoluteString ?? ""
            NSLog("[WebAluno] didFinish URL: %@", currentURL)

            // Auto-trigger Google OAuth with login_hint so user doesn't type email again.
            // Only on the initial /webaluno/ landing page (not during OAuth flow).
            let isLandingPage = currentURL.hasSuffix("/webaluno/") || currentURL.hasSuffix("/webaluno")
            if isLandingPage, let email = parent.userEmail, !email.isEmpty {
                let oauthJS = """
                    (function() {
                        var btn = document.querySelector('#GOOGLE_ALUNO, .btn-google, [onclick*="loginGoogle"]');
                        if (btn) {
                            // Try to find the loginGoogle function and add login_hint
                            if (typeof loginGoogle === 'function') {
                                // Override to add login_hint
                                var origAction = document.querySelector('form')?.action || '';
                                window.location.href = origAction || btn.getAttribute('onclick')?.match(/location\\.href\\s*=\\s*'([^']+)'/)?.[1] || '';
                            }
                            // Fallback: just click the Google button
                            btn.click();
                        }
                    })();
                """
                webView.evaluateJavaScript(oauthJS) { _, error in
                    if let error {
                        NSLog("[WebAluno] OAuth auto-trigger error: %@", error.localizedDescription)
                    }
                }
            }

            // Inspect cookies for PHPSESSID after page load
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else {
                    NSLog("[WebAluno] getAllCookies: self is nil")
                    return
                }
                NSLog("[WebAluno] getAllCookies: %d total cookies for URL %@", cookies.count, currentURL)
                let phpCookies = cookies.filter { $0.name.lowercased() == "phpsessid" }
                NSLog("[WebAluno] PHPSESSID cookies found: %d", phpCookies.count)
                for c in phpCookies {
                    NSLog("[WebAluno]   PHPSESSID domain=%@ value=%d chars", c.domain, c.value.count)
                }

                if let phpSession = self.extractPhpSessionId(from: cookies, for: currentURL) {
                    NSLog("[WebAluno] Session extracted: %d chars", phpSession.count)
                    // Don't fire during OAuth flow — only after landing on logged-in portal
                    let isAuthFlow = currentURL.contains("accounts.google.com")
                        || currentURL.contains("/autenticacao/")
                        || currentURL.contains("/login")
                        || currentURL.hasSuffix("/webaluno/")
                        || currentURL.hasSuffix("/webaluno")
                    guard !isAuthFlow else {
                        NSLog("[WebAluno] Skipping session capture — auth flow URL")
                        return
                    }

                    // We landed on a Mannesoft page that's NOT auth — user is logged in
                    NSLog("[WebAluno] Session captured! Firing onSessionCaptured")
                    self.sessionFound = true

                    // Store this WebView for SilentSync reuse — same browser fingerprint
                    SharedPortalWebView.shared.store(webView, url: currentURL)

                    // Persist ALL cookies for this domain for SilentSync
                    // WKWebView cookies don't survive app termination
                    // Log all cookies to diagnose which ones are needed
                    for c in cookies {
                        NSLog("[WebAluno] Cookie: name=%@ domain=%@ value=%d chars", c.name, c.domain, c.value.count)
                    }
                    // Save ALL cookies from the portal domain (not just PHPSESSID)
                    let portalDomain = URL(string: currentURL)?.host ?? ""
                    let allPortalCookies = cookies.filter { c in
                        c.domain.contains("mannesoftprime") || c.domain == portalDomain
                    }
                    let cookieStr = allPortalCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    MannesoftCookieStore.save(cookieStr, domain: currentURL)
                    NSLog("[WebAluno] Persisted %d cookies (%d chars) for SilentSync", allPortalCookies.count, cookieStr.count)

                    DispatchQueue.main.async {
                        self.parent.onSessionCaptured(phpSession)
                    }
                    // Inject bridge.js to extract portal data directly from this WebView
                    self.injectBridgeJS(into: webView)
                } else {
                    NSLog("[WebAluno] extractPhpSessionId returned nil")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        // MARK: - WKUIDelegate — handle popups (OAuth opens via window.open)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Don't create a new WebView — load the popup URL in the current one
            if let url = navigationAction.request.url {
                NSLog("[WebAluno] Popup intercepted → loading in same view: %@", url.absoluteString)
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // MARK: - Bridge.js injection

        private func injectBridgeJS(into webView: WKWebView) {
            guard !bridgeInjected else { return }
            bridgeInjected = true

            NSLog("[WebAluno/Bridge] Fetching bridge.js from server...")
            guard let bridgeURL = URL(string: AppConfig.apiBaseURL + "/portal/bridge") else {
                NSLog("[WebAluno/Bridge] Invalid bridge URL")
                return
            }

            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(from: bridgeURL)
                    guard (response as? HTTPURLResponse)?.statusCode == 200,
                          let js = String(data: data, encoding: .utf8) else {
                        NSLog("[WebAluno/Bridge] Failed to fetch bridge.js")
                        return
                    }
                    NSLog("[WebAluno/Bridge] Injecting bridge.js (%d bytes)", js.count)
                    // Wait 2s for page to fully render before bridge navigates
                    try await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        webView.evaluateJavaScript(js) { _, error in
                            if let error {
                                NSLog("[WebAluno/Bridge] Injection error: %@", error.localizedDescription)
                            } else {
                                NSLog("[WebAluno/Bridge] Injected successfully, extraction running...")
                            }
                        }
                    }
                } catch {
                    NSLog("[WebAluno/Bridge] Error: %@", error.localizedDescription)
                }
            }
        }

        // MARK: - Session extraction

        private func extractPhpSessionId(from cookies: [HTTPCookie], for urlString: String) -> String? {
            // Return just the PHPSESSID value — backend wraps with "PHPSESSID=" if needed
            return cookies
                .first { $0.name.lowercased() == "phpsessid" && !$0.value.isEmpty }
                .map { $0.value }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WebAlunoWebViewScreen") {
    WebAlunoWebViewScreen(
        onBack: {},
        onSessionCaptured: { cookie in
            print("Session captured: \(cookie)")
        },
        userEmail: "rafaelfloureiro93@rede.ulbra.br"
    )
    .preferredColorScheme(.dark)
}
#endif
