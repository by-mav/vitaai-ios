import UIKit

// MARK: - HapticManager
//
// Vibration feedback unificado. Todas chamadas passam por aqui pra
// (a) respeitar preferência do user (toggle Configurações > Preferências)
// (b) caching dos generators (Apple recomenda — evita allocation em cada tap)
// (c) prepare() proativo quando user toca em algo que pode disparar um haptic
//     (ex: prepare em swipe start, fire em swipe end).

enum HapticIntensity {
    case light, medium, heavy
    case soft, rigid    // iOS 13+, mais "macio"/mais "rígido"
    case success, warning, error

    fileprivate var isImpact: Bool {
        switch self {
        case .light, .medium, .heavy, .soft, .rigid: return true
        case .success, .warning, .error: return false
        }
    }
}

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private static let defaultsKey = "vita_haptic_enabled"

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    /// Lê preferência do user. Default ON.
    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.defaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.defaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    /// Dispara feedback. Se `prepare` true, prewarma o engine — útil quando
    /// se sabe que um haptic vem mas não é certeza qual (ex: swipe).
    func fire(_ intensity: HapticIntensity, prepare: Bool = false) {
        guard isEnabled else { return }
        switch intensity {
        case .light:
            if prepare { lightImpact.prepare() } else { lightImpact.impactOccurred() }
        case .medium:
            if prepare { mediumImpact.prepare() } else { mediumImpact.impactOccurred() }
        case .heavy:
            if prepare { heavyImpact.prepare() } else { heavyImpact.impactOccurred() }
        case .soft:
            if prepare { softImpact.prepare() } else { softImpact.impactOccurred() }
        case .rigid:
            if prepare { rigidImpact.prepare() } else { rigidImpact.impactOccurred() }
        case .success:
            if prepare { notification.prepare() } else { notification.notificationOccurred(.success) }
        case .warning:
            if prepare { notification.prepare() } else { notification.notificationOccurred(.warning) }
        case .error:
            if prepare { notification.prepare() } else { notification.notificationOccurred(.error) }
        }
    }
}
