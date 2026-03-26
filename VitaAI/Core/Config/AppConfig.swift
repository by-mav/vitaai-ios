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
            return "http://100.112.8.71:3110/api"
        case .production:
            return "https://vita-ai.cloud/api"
        }
    }

    static var authBaseURL: String {
        switch environment {
        case .development:
            return "http://100.112.8.71:3110"
        case .production:
            return "https://vita-ai.cloud"
        }
    }

    static let deepLinkScheme = "vitaai"
    static let appName = "VitaAI"
    static let bundleId = "com.bymav.vitaai"
}
