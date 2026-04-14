import Foundation

/// Persists Mannesoft portal cookies (PHPSESSID + Cloudflare) across app launches.
/// WKWebView cookies don't survive app termination. SilentSync needs these
/// to inject into a hidden WKWebView for background data extraction.
enum MannesoftCookieStore {
    private static let cookiesKey = "mannesoft_portal_cookies"
    private static let domainKey = "mannesoft_portal_domain"

    static func save(_ cookies: String, domain: String) {
        UserDefaults.standard.set(cookies, forKey: cookiesKey)
        UserDefaults.standard.set(domain, forKey: domainKey)
    }

    static func load() -> (cookies: String, domain: String)? {
        guard let cookies = UserDefaults.standard.string(forKey: cookiesKey),
              let domain = UserDefaults.standard.string(forKey: domainKey),
              !cookies.isEmpty else { return nil }
        return (cookies, domain)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: cookiesKey)
        UserDefaults.standard.removeObject(forKey: domainKey)
    }
}
