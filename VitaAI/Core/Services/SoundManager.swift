import AVFoundation
import Foundation

// MARK: - SoundManager
//
// Som de UI (tap, acerto/erro flashcard, conquista, level up). Usa AudioServicesPlaySystemSound
// pra evitar overhead de AVAudioPlayer em sons curtos (<1s). Sons custom em Assets/Sounds/
// referenciados via SystemSoundID quando o asset existir; fallback pra tones nativos do iOS.
//
// Persiste preferência via UserDefaults — preferência local, ZERO server roundtrip.
// Toggle em Configurações > Preferências > Efeitos sonoros.

enum SoundEffect: String, CaseIterable {
    case tap            // micro tap em botão (UISound 1104)
    case success        // acerto flashcard / questão correta (UISound 1322)
    case error          // erro flashcard / questão incorreta (UISound 1257)
    case levelUp        // subiu de nível (UISound 1335)
    case achievement    // desbloqueou conquista (UISound 1325)
    case streakSaved    // não perdeu streak (UISound 1306)

    /// SystemSoundID nativo iOS — não exige asset custom. Quando tivermos
    /// `.caf` próprio em Assets/Sounds/, troca pelo `loadCustomSound(...)`.
    fileprivate var systemSoundID: SystemSoundID {
        switch self {
        case .tap:          return 1104
        case .success:      return 1322
        case .error:        return 1257
        case .levelUp:      return 1335
        case .achievement:  return 1325
        case .streakSaved:  return 1306
        }
    }
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private static let defaultsKey = "vita_sound_enabled"
    private init() {}

    /// Lê preferência do user. Default ON.
    var isEnabled: Bool {
        get {
            // Default ON: chave inexistente vira true
            if UserDefaults.standard.object(forKey: Self.defaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.defaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }
}
