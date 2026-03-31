import Foundation

enum AppEnvironment {
    case development
    case production
}

enum AppConfig {
    #if DEBUG
    static let environment: AppEnvironment = .development
    #else
    static let environment: AppEnvironment = .production
    #endif

    static let onboardingKey = "vita_is_onboarded"
    static let legacyOnboardingKey = "vita_onboarding_done"

    static let demoUserName = "Rafael"
    static let demoUserEmail = "qa@vita-ai.cloud"
    static let demoUserImage = ""

    private static let defaultAPIBaseURL = "https://vita-ai.cloud/api"
    private static let defaultAuthBaseURL = "https://vita-ai.cloud"

    struct InjectedSession {
        let token: String
        let name: String?
        let email: String?
        let image: String?
    }

    private static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private static func truthy(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(value)
    }

    private static func hasLaunchFlag(_ flag: String, defaultsKey: String? = nil, envKey: String? = nil) -> Bool {
        if ProcessInfo.processInfo.arguments.contains(flag) {
            return true
        }
        if let defaultsKey, UserDefaults.standard.object(forKey: defaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        if let envKey {
            return truthy(ProcessInfo.processInfo.environment[envKey])
        }
        return false
    }

    private static func overrideValue(envKey: String, defaultsKey: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[envKey], !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(env)
        }
        if let defaults = UserDefaults.standard.string(forKey: defaultsKey), !defaults.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(defaults)
        }
        return nil
    }

    private static var apiOverrideValue: String? {
        overrideValue(envKey: "VITA_API_BASE_URL", defaultsKey: "vita_api_base_url")
    }

    private static var authOverrideValue: String? {
        overrideValue(envKey: "VITA_AUTH_BASE_URL", defaultsKey: "vita_auth_base_url")
    }

    private static func launchArgumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let idx = arguments.firstIndex(of: flag), idx + 1 < arguments.count else {
            return nil
        }
        return arguments[idx + 1]
    }

    private static func authBaseURL(from apiBaseURL: String) -> String {
        let normalizedAPI = normalized(apiBaseURL)
        if normalizedAPI.hasSuffix("/api") {
            return String(normalizedAPI.dropLast(4))
        }
        return normalizedAPI
    }

    static var apiBaseURL: String {
        if let override = apiOverrideValue {
            return override
        }
        return defaultAPIBaseURL
    }

    static var authBaseURL: String {
        if let override = authOverrideValue {
            return override
        }
        if let apiOverride = apiOverrideValue {
            return authBaseURL(from: apiOverride)
        }
        return defaultAuthBaseURL
    }

    static var isE2EDemoMode: Bool {
        hasLaunchFlag("--vita-e2e-demo", defaultsKey: "vita_e2e_demo", envKey: "VITA_E2E_DEMO")
            || hasLaunchFlag("--vita-demo-login", defaultsKey: "vita_demo_login", envKey: "VITA_DEMO_LOGIN")
    }

    static var isE2EProdAuthMode: Bool {
        hasLaunchFlag("--vita-e2e-prod-auth", defaultsKey: "vita_e2e_prod_auth", envKey: "VITA_E2E_PROD_AUTH")
    }

    static var shouldResetOnboarding: Bool {
        hasLaunchFlag("--reset-onboarding", defaultsKey: "vita_reset_onboarding", envKey: "VITA_RESET_ONBOARDING")
    }

    static var injectedSession: InjectedSession? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let idx = arguments.firstIndex(of: "--vita-inject-token"),
              idx + 1 < arguments.count
        else {
            return nil
        }

        return InjectedSession(
            token: arguments[idx + 1],
            name: idx + 2 < arguments.count ? arguments[idx + 2] : nil,
            email: idx + 3 < arguments.count ? arguments[idx + 3] : nil,
            image: idx + 4 < arguments.count ? arguments[idx + 4] : nil
        )
    }

    static var ciToken: String? {
        guard let token = ProcessInfo.processInfo.environment["VITA_CI_TOKEN"],
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return token
    }

    static var localForwardedHostHeader: String? {
        let candidate = authOverrideValue ?? apiOverrideValue
        guard let candidate,
              let url = URL(string: candidate),
              url.scheme?.lowercased() == "http" else {
            return nil
        }
        if let explicit = overrideValue(envKey: "VITA_FORWARDED_HOST", defaultsKey: "vita_forwarded_host") {
            return explicit
        }
        return "localhost"
    }

    static func isOnboardingComplete(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: onboardingKey) || defaults.bool(forKey: legacyOnboardingKey)
    }

    static func setOnboardingComplete(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: onboardingKey)
        defaults.set(value, forKey: legacyOnboardingKey)
    }

    static let deepLinkScheme = "vitaai"
    static let appName = "VitaAI"
    static let bundleId = "com.bymav.vitaai"
}
