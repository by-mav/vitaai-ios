import Foundation

// MARK: - LocalDeckStore
//
// Camada de EDIÇÃO LOCAL da Biblioteca curada (modelo Anki — Rafael 2026-07-18).
// A Biblioteca vem read-only do bundle (VitaContentBundle). Quando o aluno gerencia
// os cards (deletar / adicionar / editar / mover), a mudança NÃO toca o bundle nem o
// servidor — vira um OVERLAY salvo no device dele (`Documents/flashcards/deck-edits.json`).
// Cada usuário tem a SUA cópia editável, sem afetar o deck compartilhado dos outros.
//
// Persistência: JSON atômico, igual o LocalFlashcardStore (in-memory após load; disco
// é o backup durável).
actor LocalDeckStore {
    static let shared = LocalDeckStore()

    struct LocalCard: Codable, Equatable {
        var id: String
        var front: String
        var back: String
        var disciplineSlug: String
    }
    struct Edit: Codable, Equatable { var front: String; var back: String }

    private struct Overlay: Codable {
        var version: Int = 1
        var deleted: Set<String> = []
        var added: [LocalCard] = []
        var edited: [String: Edit] = [:]
        var moved: [String: String] = [:]     // card id → novo disciplineSlug
    }

    private var overlay = Overlay()
    private var loaded = false
    private let fm = FileManager.default

    private var fileURL: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("flashcards", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("deck-edits.json")
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Overlay.self, from: data) else { return }
        overlay = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(overlay) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Cards efetivos de uma disciplina: bundle + overlay (remove deletados, aplica
    /// edições, puxa os movidos-pra-cá e os adicionados). Ordem: adicionados no topo.
    func effectiveCards(bundle: [VitaContentBundle.BundleCard], disciplineSlug: String) -> [FlashcardEntry] {
        load()
        var out: [FlashcardEntry] = []
        // Adicionados nesta disciplina primeiro.
        for c in overlay.added where c.disciplineSlug == disciplineSlug && !overlay.deleted.contains(c.id) {
            out.append(entry(id: c.id, front: c.front, back: c.back))
        }
        // Cards do bundle que pertencem à disciplina (menos os movidos pra fora).
        for c in bundle {
            if overlay.deleted.contains(c.id) { continue }
            if let dest = overlay.moved[c.id], dest != disciplineSlug { continue }
            let e = overlay.edited[c.id]
            out.append(entry(id: c.id, front: e?.front ?? c.front, back: e?.back ?? c.back))
        }
        return out
    }

    private func entry(id: String, front: String, back: String) -> FlashcardEntry {
        FlashcardEntry(id: id, front: front, back: back)
    }

    // MARK: Mutações (persistem sempre)

    func delete(ids: Set<String>) {
        load()
        overlay.deleted.formUnion(ids)
        overlay.added.removeAll { ids.contains($0.id) }
        for id in ids { overlay.edited[id] = nil; overlay.moved[id] = nil }
        persist()
    }

    @discardableResult
    func add(front: String, back: String, disciplineSlug: String) -> String {
        load()
        let id = "local-\(overlay.added.count)-\(front.hashValue)-\(disciplineSlug)"
        overlay.added.insert(LocalCard(id: id, front: front, back: back, disciplineSlug: disciplineSlug), at: 0)
        persist()
        return id
    }

    func edit(id: String, front: String, back: String) {
        load()
        if let idx = overlay.added.firstIndex(where: { $0.id == id }) {
            overlay.added[idx].front = front
            overlay.added[idx].back = back
        } else {
            overlay.edited[id] = Edit(front: front, back: back)
        }
        persist()
    }

    /// Move cards pra outra disciplina (muda o disciplineSlug no overlay).
    func move(ids: Set<String>, to disciplineSlug: String) {
        load()
        for id in ids {
            if let idx = overlay.added.firstIndex(where: { $0.id == id }) {
                overlay.added[idx].disciplineSlug = disciplineSlug
            } else {
                overlay.moved[id] = disciplineSlug
            }
        }
        persist()
    }

    /// Duplica cards (cria cópias locais na mesma disciplina).
    func duplicate(cards: [(front: String, back: String)], in disciplineSlug: String) {
        load()
        for c in cards {
            _ = add(front: c.front, back: c.back, disciplineSlug: disciplineSlug)
        }
    }
}
