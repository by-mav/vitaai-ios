import SwiftUI
import WebKit

// MARK: - Constants

private let webalunoURL = "https://ac3949.mannesoftprime.com.br"

// MARK: - WebAlunoWebViewScreen

/// Presents the WebAluno portal in a WKWebView.
/// On successful login, captures the PHPSESSID cookie and calls `onSessionCaptured`.
struct WebAlunoWebViewScreen: View {
    var onBack: () -> Void
    /// Called once when a valid PHPSESSID is detected after login
    var onSessionCaptured: (String) -> Void

    @State private var isLoading: Bool = true
    @State private var loadProgress: Double = 0

    var body: some View {
        ZStack {
            VitaScreenBg()

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

                // WebView
                WebAlunoWebView(
                    url: URL(string: webalunoURL)!,
                    isLoading: $isLoading,
                    loadProgress: $loadProgress,
                    onSessionCaptured: onSessionCaptured
                )
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

            Text("Entrar no WebAluno")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .vitaScreenBg()
    }
}

// MARK: - WebAlunoWebView (UIViewRepresentable)

struct WebAlunoWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    var onSessionCaptured: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Clear any stale cookies before starting a fresh login
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeCookies],
            modifiedSince: .distantPast,
            completionHandler: {}
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Allow all content — equivalent to Android's mixed content compat
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor(VitaColors.surface)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Strip WebView marker from user-agent BEFORE loading — Google blocks OAuth in WebViews
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebAlunoWebView
        var webView: WKWebView?
        var sessionFound = false
        var progressObservation: NSKeyValueObservation?

        init(parent: WebAlunoWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
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

            guard !sessionFound else { return }

            // Inspect cookies for PHPSESSID after page load
            let currentURL = webView.url?.absoluteString ?? ""
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                if let phpSession = self.extractPhpSessionId(from: cookies, for: currentURL) {
                    // Only fire after the user has successfully logged in (URL changed past login page)
                    let isLoginPage = currentURL.hasSuffix("/")
                        || currentURL.contains("/login")
                        || currentURL.hasSuffix(".br")
                        || currentURL == webalunoURL
                        || currentURL == webalunoURL + "/"
                    guard !isLoginPage else { return }

                    self.sessionFound = true
                    DispatchQueue.main.async {
                        self.parent.onSessionCaptured(phpSession)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        // MARK: - Session extraction

        private func extractPhpSessionId(from cookies: [HTTPCookie], for urlString: String) -> String? {
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
        }
    )
    .preferredColorScheme(.dark)
}
#endif
