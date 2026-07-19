import Foundation

// MARK: - VitaAPI + CardBrowser
//
// Métodos de mutação de UM card usados pelo Card Browser (CardBrowserScreen).
// Ambos os endpoints EXISTEM no contrato — não são invenção:
//   • PATCH  /api/study/flashcards/{id}  (updateFlashcard) — openapi.yaml:5531
//   • DELETE /api/study/flashcards/{id}  (deleteFlashcard) — openapi.yaml:5583
//
// Ficam num arquivo de extensão separado (mesmo padrão de VitaAPI+Missions /
// VitaAPI+Skins) pra não tocar o VitaAPI.swift central. `client` é internal
// justamente pra extensões em arquivos separados poderem chamá-lo.
extension VitaAPI {

    /// PATCH /api/study/flashcards/{id} — edita frente/verso do card (só cards
    /// do próprio usuário; card curado da Biblioteca Vita responde 403).
    ///
    /// Só front/back: são chaves de uma palavra, então o encoder padrão
    /// (convertToSnakeCase) não as altera — chegam intactas no zod do server.
    func updateFlashcard(cardId: String, front: String, back: String) async throws {
        struct Body: Encodable { let front: String; let back: String }
        try await client.patch("study/flashcards/\(cardId)", body: Body(front: front, back: back))
    }

    /// PATCH /api/study/flashcards/{id} com `deckId` — move o card pra outro
    /// baralho DO PRÓPRIO aluno (o server valida o dono do destino; mover pra
    /// deck da Biblioteca ou de terceiro responde 403/404).
    ///
    /// Usa patchRaw: o encoder padrão converteria `deckId`→`deck_id` e o zod
    /// camelCase-only dropa a chave em silêncio (mesma pegadinha do
    /// createFlashcard/deckTitle, ver VitaAPI.swift:237).
    func moveFlashcard(cardId: String, toDeckId deckId: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["deckId": deckId])
        let _: EmptyResponse = try await client.patchRaw("study/flashcards/\(cardId)", body: body)
    }

    /// DELETE /api/study/flashcards/{id} — soft-delete do card (só cards do
    /// próprio usuário). Server marca deletedAt; some das próximas queries.
    func deleteFlashcard(cardId: String) async throws {
        try await client.delete("study/flashcards/\(cardId)")
    }
}
