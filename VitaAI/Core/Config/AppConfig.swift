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

    static var apiBaseURL: String {
        switch environment {
        case .development:
            return "http://localhost:3070/api"
        case .production:
            return "https://medcoach.bymav.com/api"
        }
    }

    static var authBaseURL: String {
        switch environment {
        case .development:
            return "http://localhost:3070"
        case .production:
            return "https://medcoach.bymav.com"
        }
    }

    static let deepLinkScheme = "vitaai"
    static let appName = "VitaAI"
    static let bundleId = "com.bymav.vitaai"
}
