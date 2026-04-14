import SwiftUI
import WebKit

/// Inline login sheet that shows ONLY the portal's login form.
/// Hides all page chrome (headers, banners, footers) via CSS injection.
/// Used by ConnectionsScreen so the user never leaves the connections page.
struct InlinePortalLoginSheet: View {
    let portalName: String
    let portalUrl: String
    var onBack: () -> Void
    var onSessionCaptured: (String) -> Void

    @State private var isLoading = true

    private var loginURL: String {
        guard !portalUrl.isEmpty else { return "" }
        let base = portalUrl.hasSuffix("/") ? portalUrl : portalUrl + "/"
        return base.contains("/webaluno") ? base : base + "webaluno/"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VitaColors.textSecondary)
                }
                Spacer()
                Text("Conectar \(portalName)")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)
                Spacer()
                // Balance spacer
                Color.clear.frame(width: 24, height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isLoading {
                ProgressView()
                    .tint(VitaColors.accent)
                    .padding(.bottom, 8)
            }

            if let url = URL(string: loginURL), !loginURL.isEmpty {
                PortalLoginWebView(
                    url: url,
                    isLoading: $isLoading,
                    onSessionCaptured: onSessionCaptured
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                Text("URL do portal não configurada")
                    .font(VitaTypography.bodySmall)
                    .foregroundColor(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - PortalLoginWebView

/// WKWebView that loads a portal page and hides everything except the login form.
struct PortalLoginWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onSessionCaptured: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Only clear PHPSESSID — preserve Cloudflare cookies
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.name.lowercased() == "phpsessid" {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // CSS injection: hide everything except .box-login, style it for dark theme
        let hideCSS = WKUserScript(
            source: """
                (function() {
                    var style = document.createElement('style');
                    style.textContent = `
                        /* Hide everything */
                        body > * { display: none !important; }
                        #tudo { display: block !important; }
                        #tudo > * { display: none !important; }

                        /* Show only the login box */
                        .box-login {
                            display: block !important;
                            margin: 0 auto !important;
                            padding: 16px !important;
                            width: 100% !important;
                            max-width: 100% !important;
                            box-sizing: border-box !important;
                            background: #1a1410 !important;
                            border-radius: 16px !important;
                            border: 1px solid rgba(255,255,255,0.08) !important;
                        }
                        .box-login * {
                            color: #e8dcc8 !important;
                        }
                        .box-login input {
                            background: rgba(255,255,255,0.06) !important;
                            border: 1px solid rgba(255,255,255,0.12) !important;
                            border-radius: 8px !important;
                            color: #fff !important;
                            padding: 10px !important;
                        }
                        .box-login .btn-google {
                            background: #c5a55a !important;
                            color: #1a1410 !important;
                            border: none !important;
                            border-radius: 8px !important;
                            padding: 10px 20px !important;
                            width: 100% !important;
                            font-weight: bold !important;
                            cursor: pointer !important;
                        }
                        .box-login .button-login button,
                        .box-login #ACESSAR,
                        .box-login #ACESSAR_ASC button {
                            background: #c5a55a !important;
                            color: #1a1410 !important;
                            border: none !important;
                            border-radius: 8px !important;
                            padding: 10px 20px !important;
                        }
                        /* Make login tabs visible */
                        .box-login .box-login-text-4 {
                            color: #c5a55a !important;
                        }
                        /* Hide header/footer inside box-login if any */
                        .box-login .box-login-borda-header { display: none !important; }
                        #header-externo, #footer-externo, .menu-externo { display: none !important; }

                        /* Dark background */
                        body {
                            background: #1a1410 !important;
                            margin: 0 !important;
                            padding: 8px !important;
                        }

                        /* Force Google login button visible */
                        #GOOGLE_ALUNO { display: block !important; margin-top: 12px !important; }
                    `;
                    document.head.appendChild(style);

                    // Walk up from .box-login — use setProperty with !important
                    // so it overrides the CSS rule `body > * { display: none !important; }`
                    var el = document.querySelector('.box-login');
                    while (el && el !== document.body) {
                        el.style.setProperty('display', 'block', 'important');
                        el = el.parentElement;
                    }
                })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(hideCSS)

        // DO NOT set customUserAgent — triggers Cloudflare
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: PortalLoginWebView
        var webView: WKWebView?
        var sessionCaptured = false

        init(parent: PortalLoginWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }

            guard !sessionCaptured else { return }
            let currentURL = webView.url?.absoluteString ?? ""
            NSLog("[PortalLogin] didFinish: %@", currentURL)

            // Check for session after login completes
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.sessionCaptured else { return }

                if let php = cookies.first(where: { $0.name.lowercased() == "phpsessid" && !$0.value.isEmpty }) {
                    // Only capture after user is past the login page
                    let isLoginPage = currentURL.contains("/login")
                        || currentURL.hasSuffix("/webaluno/")
                        || currentURL.hasSuffix("/webaluno")
                        || currentURL.contains("accounts.google.com")
                        || currentURL.contains("/autenticacao/")
                    guard !isLoginPage else { return }

                    self.sessionCaptured = true
                    DispatchQueue.main.async {
                        self.parent.onSessionCaptured(php.value)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        // Handle popups (OAuth opens via window.open)
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
