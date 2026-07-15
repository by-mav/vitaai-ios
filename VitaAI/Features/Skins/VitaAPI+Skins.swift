import Foundation
import SwiftUI

// MARK: - Loja de skins (moeda de mérito + nível) — modelo HÍBRIDO (Rafael 2026-07-09)
//
// 3 endpoints do backend Vita (prod vita-ai.cloud), provados via curl:
//   GET  /api/skins        → nível + saldo + catálogo + equipado
//   POST /api/skins/buy    → compra ACESSÓRIO (402 saldo / 403 nível / 409 já possui / 400 id|cor)
//   POST /api/skins/equip  → equipa o ESTADO COMPLETO desejado (slot ausente = desequipa)
//
// Modelo híbrido: ACESSÓRIO = nível ABRE (fica comprável) + MOEDA compra; depois
// equipa grátis. COR (paleta) = grátis por JORNADA, desbloqueia só por nível.
// Só o Vita puro (Ouro nv1) é livre. A moeda deriva do XP (mérito).
//
// O `id` do catálogo bate 1:1 com MascotAccessory.rawValue (acessórios) e com
// MascotPalette.rawValue (paletas: vita/emerald/sapphire/ruby/amethyst). O backend
// é SOT: nível/preço/posse/trava decididos lá; o app só desenha e obedece.
//
// O HTTPClient decodifica com .convertFromSnakeCase, então os campos snake_case
// do backend mapeiam pros nomes camelCase abaixo automaticamente.

// MARK: - DTOs

/// Skin equipada — 1 item por slot (ou nil = slot vazio).
struct EquippedSkinDTO: Codable, Hashable, Sendable {
    var head: String?
    var face: String?
    var neck: String?
    var palette: String?
}

/// Item do catálogo. `slot` = head|face|neck|palette;
/// `rarity` = common|rare|epic|legendary.
/// `unlockLevel` = nível mínimo pra desbloquear; `locked` = user ainda não atingiu;
/// `owned` = já possui/liberado (acessório comprado, ou cor com nível atingido);
/// `free` = não passa por compra (toda paleta + Vita puro).
struct SkinStoreItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slot: String
    let name: String
    let rarity: String
    let price: Int
    let unlockLevel: Int
    let free: Bool
    let locked: Bool
    var owned: Bool
}

/// GET /api/skins
struct SkinStoreResponse: Codable, Sendable {
    let level: Int
    let balance: Int
    let earned: Int
    let spent: Int
    let equipped: EquippedSkinDTO?
    let catalog: [SkinStoreItem]
    /// Caixa paga aposentada; nil no backend atual.
    let lootboxPrice: Int?
    /// Baús da trilha (níveis 10,20,…,100) + estado. Opcional (backend antigo).
    let chests: [ChestState]?
    /// Compatibilidade do payload antigo; zero no backend atual.
    let keyPrice: Int?
}

/// Estado de um baú da trilha. `unlocked` = nível alcançado; `claimed` = já aberto.
struct ChestState: Codable, Sendable, Hashable {
    let level: Int
    let unlocked: Bool
    let claimed: Bool
}

/// POST /api/skins/lootbox → 200. Caixa Misteriosa: skin sorteada + saldo novo.
struct LootboxResult: Codable, Sendable, Identifiable {
    struct Won: Codable, Sendable, Hashable {
        let id: String
        let slot: String
        let name: String
        let rarity: String
        let unlockLevel: Int
    }
    let won: Won
    let price: Int
    let balance: Int
    let duplicate: Bool?
    // Pra apresentar via .fullScreenCover(item:).
    var id: String { won.id }
}

/// POST /api/skins/buy → 200
struct BuySkinResponse: Codable, Sendable {
    let skinId: String
    let price: Int
    let balance: Int
    let owned: [String]
}

/// POST /api/skins/equip → 200
struct EquipSkinResult: Codable, Sendable {
    let equippedSkin: EquippedSkinDTO?
}

/// Corpo do POST /api/skins/equip. Optional nil é OMITIDO pelo JSONEncoder →
/// o slot ausente desequipa aquele item no backend (mandamos o ESTADO COMPLETO
/// do preview, o backend substitui o equippedSkin).
private struct EquipSkinRequest: Encodable {
    let head: String?
    let face: String?
    let neck: String?
    let palette: String?
}

private struct BuySkinRequest: Encodable {
    let skinId: String
}
// EmptyBody (corpo vazio pro POST da Caixa) já existe em Core/Network/VitaAPI.swift.

// MARK: - VitaAPI

extension VitaAPI {
    /// GET /api/skins — nível, saldo, catálogo e skin equipada.
    func getSkins() async throws -> SkinStoreResponse {
        try await client.get("skins")
    }

    /// POST /api/skins/buy — compra o acessório. Lança APIError.serverError(4xx)
    /// quando saldo insuficiente (402) / nível travado (403) / já possui (409) /
    /// id inválido ou é cor (400).
    func buySkin(id: String) async throws -> BuySkinResponse {
        // Este endpoint segue o OpenAPI camelCase (`skinId`). O encoder global
        // converte propriedades para snake_case e causava `skin_id` -> HTTP 400
        // antes mesmo de o servidor conferir nível ou saldo.
        let body = try JSONEncoder().encode(BuySkinRequest(skinId: id))
        return try await client.postRaw("skins/buy", body: body)
    }

    /// POST /api/skins/equip — equipa o ESTADO COMPLETO. Slots nil são omitidos
    /// (desequipa). `palette: nil` volta pro Vita puro (ouro).
    func equipSkin(
        head: String?,
        face: String?,
        neck: String?,
        palette: String?
    ) async throws -> EquipSkinResult {
        try await client.post(
            "skins/equip",
            body: EquipSkinRequest(head: head, face: face, neck: neck, palette: palette)
        )
    }

    /// POST /api/skins/lootbox — abre a Caixa Misteriosa. Lança serverError(402)
    /// sem saldo, (409) quando não há mais o que ganhar no nível atual.
    func openLootbox() async throws -> LootboxResult {
        try await client.post("skins/lootbox", body: EmptyBody())
    }

    /// POST /api/chests/open — abre gratuitamente o baú do `level` uma única vez.
    /// Lança serverError(403) se o nível não foi alcançado e (409) se já abriu.
    func openChest(level: Int) async throws -> LootboxResult {
        try await client.post("chests/open", body: OpenChestRequest(level: level))
    }
}

private struct OpenChestRequest: Encodable {
    let level: Int
}

// MARK: - SkinStore (ViewModel)
//
// Cérebro da tela "Aparência". Server-authoritative: toda mutação (comprar/equipar)
// recarrega do backend, então a UI nunca diverge da verdade. Determinístico — a
// trava por nível/saldo é decidida no backend; a UI só reflete `locked`/`owned`/`balance`.

@MainActor
final class SkinStore: ObservableObject {
    @Published private(set) var level: Int = 1
    @Published private(set) var balance: Int = 0
    @Published private(set) var catalog: [SkinStoreItem] = []
    @Published private(set) var equipped: EquippedSkinDTO = .init()
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published private(set) var lootboxPrice: Int = 120   // preço da Caixa (backend sobrescreve no load)
    @Published private(set) var chests: [ChestState] = []  // baús da trilha (backend)
    @Published private(set) var keyPrice: Int = 0          // compatibilidade; baú atual é grátis
    @Published var errorMessage: String?

    /// Carrega tudo do backend. Chame no onAppear/.task da tela.
    func load(api: VitaAPI) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await api.getSkins()
            apply(r)
        } catch {
            errorMessage = "Não consegui carregar o guarda-roupa. Tente de novo."
        }
    }

    /// Compra um acessório (moeda). Recarrega em seguida (SOT). Retorna sucesso.
    @discardableResult
    func buy(id: String, api: VitaAPI) async -> Bool {
        guard !isMutating else { return false }
        let candidate = item(id: id)
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await api.buySkin(id: id)
            await load(api: api)
            return true
        } catch APIError.serverError(409) {
            // Estado local antigo: recarrega e trata como sucesso se a posse já
            // estiver confirmada pelo servidor.
            await load(api: api)
            if item(id: id)?.owned == true { return true }
            errorMessage = "Este item já foi comprado. Atualizei seu guarda-roupa."
            return false
        } catch let error as APIError {
            switch error {
            case .serverError(402):
                let missing = max(0, (candidate?.price ?? 0) - balance)
                errorMessage = "Saldo insuficiente. Faltam \(missing) moedas Vita."
            case .serverError(403):
                errorMessage = "Este item libera no nível \(candidate?.unlockLevel ?? level)."
            case .serverError(400):
                errorMessage = "A loja recusou este item. Atualize o Vita e tente novamente."
            default:
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = "Não consegui concluir a compra agora. Tente novamente."
            return false
        }
    }

    /// Equipa o estado COMPLETO desejado (o backend substitui o equippedSkin).
    /// nil num slot = desequipa aquele slot. Recarrega em seguida. Retorna sucesso.
    @discardableResult
    func equip(head: String?, face: String?, neck: String?, palette: String?, api: VitaAPI) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }
        do {
            let r = try await api.equipSkin(head: head, face: face, neck: neck, palette: palette)
            if let eq = r.equippedSkin { equipped = eq }
            await load(api: api)
            return true
        } catch {
            errorMessage = "Não consegui equipar. Tente de novo."
            return false
        }
    }

    /// Abre a Caixa Misteriosa (moeda de mérito). Recarrega em seguida (SOT) pra
    /// saldo/posse baterem com o backend. Retorna a skin ganha, ou nil se falhou
    /// (sem saldo / já tem tudo do nível).
    @discardableResult
    func openLootbox(api: VitaAPI) async -> LootboxResult? {
        guard !isMutating else { return nil }
        isMutating = true
        defer { isMutating = false }
        do {
            let r = try await api.openLootbox()
            await load(api: api)
            return r
        } catch {
            errorMessage = "Não abriu a caixa. Confira o saldo — ou você já ganhou tudo que dá no seu nível."
            return nil
        }
    }

    /// Abre gratuitamente o baú do nível. Recarrega em seguida (SOT).
    @discardableResult
    func openChest(level: Int, api: VitaAPI) async -> LootboxResult? {
        guard !isMutating else { return nil }
        isMutating = true
        defer { isMutating = false }
        do {
            let r = try await api.openChest(level: level)
            await load(api: api)
            return r
        } catch {
            errorMessage = "Não abriu o baú. Ele pode estar bloqueado ou já ter sido aberto."
            return nil
        }
    }

    /// Estado do baú de um nível (nil = não é nível de baú).
    func chest(level: Int) -> ChestState? {
        chests.first { $0.level == level }
    }

    private func apply(_ r: SkinStoreResponse) {
        level = r.level
        balance = r.balance
        catalog = r.catalog
        equipped = r.equipped ?? .init()
        if let p = r.lootboxPrice { lootboxPrice = p }
        if let c = r.chests { chests = c }
        if let k = r.keyPrice { keyPrice = k }
    }

    // MARK: - Helpers de leitura (a tela consome)

    /// Itens de um slot (head|face|neck|palette), sempre do nível mais baixo
    /// para o mais alto. O sort defensivo preserva a progressão mesmo se um
    /// backend antigo devolver o catálogo fora de ordem.
    func items(slot: String) -> [SkinStoreItem] {
        catalog
            .filter { $0.slot == slot }
            .sorted {
                if $0.unlockLevel != $1.unlockLevel { return $0.unlockLevel < $1.unlockLevel }
                if $0.price != $1.price { return $0.price < $1.price }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func item(id: String?) -> SkinStoreItem? {
        guard let id else { return nil }
        return catalog.first { $0.id == id }
    }

    func equippedId(slot: String) -> String? {
        switch slot {
        case "head": return equipped.head
        case "face": return equipped.face
        case "neck": return equipped.neck
        case "palette": return equipped.palette
        default: return nil
        }
    }
}
