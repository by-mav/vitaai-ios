import SwiftUI

// MARK: - Skin equipada (Fase 1 — o Vita veste a skin do perfil no app todo)
//
// O backend manda `equippedSkin` no perfil (GET /api/profile). Este wrapper LÊ
// isso do AppDataManager e desenha o OrbMascot equipado. Regra §2.6: backend
// resolve, cliente só desenha. Pré-auth (login/onboarding) NÃO usa isto — mostra
// orb puro. Trocar 1 componente = muda em todas as telas pós-auth.

// `ProfileEquippedSkin` (head/face/neck/palette: String?) é GERADO do openapi
// (codegen swift6) — não redeclarar aqui. head/face/neck = MascotAccessory.rawValue.

extension MascotPalette {
    /// Mapeia o id da paleta (backend) → paleta. Desconhecido/nil = ouro Vita.
    static func forId(_ id: String?) -> MascotPalette {
        switch id {
        case "emerald": return .emerald
        case "sapphire": return .sapphire
        case "ruby": return .ruby
        case "amethyst": return .amethyst
        default: return .vita
        }
    }
}

extension ProfileEquippedSkin {
    /// Acessórios equipados (máx 1 por slot), na ordem de z (pescoço→cabeça→rosto).
    var accessories: [MascotAccessory] {
        [neck, head, face].compactMap { $0 }.compactMap { MascotAccessory(rawValue: $0) }
    }
}

/// O mascote Vita VESTIDO com a skin equipada do usuário. Usa nos callsites
/// pós-auth no lugar de `OrbMascot(palette: .vita, ...)`.
struct VitaMascotEquipped: View {
    @Environment(\.appData) private var appData
    @Environment(\.appContainer) private var container

    var state: VitaMascotState = .awake
    var size: CGFloat = 120
    var bounceEnabled: Bool = true
    var idleEnabled: Bool = true

    var body: some View {
        let equip = appData.profile?.equippedSkin
        OrbMascot(
            palette: MascotPalette.forId(equip?.palette),
            state: state,
            size: size,
            accessories: equip?.accessories ?? [],
            nameTag: Self.firstName(appData.profile?.displayName),
            photoURL: container.authManager.userImage.flatMap(URL.init(string:)),
            bounceEnabled: bounceEnabled,
            idleEnabled: idleEnabled
        )
    }

    /// Primeiro nome pro bordado "Dr. <nome>" do jaleco.
    static func firstName(_ name: String?) -> String? {
        guard let first = name?.split(separator: " ").first, !first.isEmpty else { return nil }
        return String(first)
    }
}
