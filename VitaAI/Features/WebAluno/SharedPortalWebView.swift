import Foundation
import WebKit

/// Holds a reference to the WKWebView used for Mannesoft login.
/// SilentSync reuses this SAME instance instead of creating a new one.
/// Why: Mannesoft binds PHPSESSID to browser fingerprint (UA, TLS, etc).
/// A new WKWebView gets a different fingerprint → session rejected.
@MainActor
final class SharedPortalWebView {
    static let shared = SharedPortalWebView()

    /// The WKWebView from the login flow — kept alive for SilentSync reuse
    private(set) var webView: WKWebView?

    /// The URL the WebView last navigated to
    private(set) var lastURL: String?


    private init() {}

    /// Store the login WebView for reuse by SilentSync.
    /// Called after successful session capture in WebAlunoWebViewScreen.
    func store(_ wv: WKWebView, url: String) {
        self.webView = wv
        self.lastURL = url
        NSLog("[SharedPortalWV] Stored WebView for reuse (url: %@)", url)
    }

    /// Release the WebView (on disconnect or explicit cleanup)
    func release() {
        webView?.stopLoading()
        webView = nil
        lastURL = nil
        NSLog("[SharedPortalWV] Released WebView")
    }

    /// Check if we have a usable WebView with valid session
    var hasWebView: Bool { webView != nil }
}
