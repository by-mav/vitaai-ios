import Foundation
import SQLite3
import ZIPFoundation

// MARK: - DeckPackStore — baralhos BAIXADOS no device (offline de verdade)
//
// Spec: agent-brain/specs/vitaai/flashcards-offline-download-por-baralho.md.
// Nada de conteúdo vai embarcado na apk: o aluno TOCA em baixar, o app pega o
// pack `.apkg` do baralho (rota /api/study/flashcards/library/{slug}/pack) e
// guarda no device — depois disso, estuda offline pra sempre até remover.
//
// Layout em Documents/flashcards/decks/<slug>/:
//   cards.json   — cards já extraídos do .apkg (front/back/cardType/id)
//   media/       — imagens e áudios com o nome achatado do pack
//   manifest.json— version/cardCount/mediaCount/baixado em
//
// Por que extrair na hora do download em vez de ler o SQLite a cada estudo:
// o parse roda UMA vez (no download, com o aluno esperando de propósito) e o
// estudo depois é leitura de JSON — sem custo, sem SQLite aberto no caminho
// quente. O `.apkg` cru é descartado após extrair (economiza o dobro de disco).
//
// O `guid` da nota no pack É o id do nosso card — é assim que o FSRS local
// (LocalFlashcardStore) reencontra o agendamento salvo.
actor DeckPackStore {
    static let shared = DeckPackStore()

    struct Manifest: Codable, Equatable {
        let slug: String
        let title: String
        let version: String
        let cardCount: Int
        let mediaCount: Int
        let downloadedAt: Date
        /// Bytes ocupados no device (cards.json + media/).
        var bytes: Int64 = 0
    }

    struct PackCard: Codable, Equatable {
        let id: String
        let front: String
        let back: String
        let cardType: String
    }

    enum PackError: LocalizedError {
        case badArchive
        case noCollection
        case sqlite(String)

        var errorDescription: String? {
            switch self {
            case .badArchive: return "O pacote do baralho veio corrompido."
            case .noCollection: return "O pacote do baralho está sem os cartões."
            case .sqlite(let m): return "Não consegui ler os cartões (\(m))."
            }
        }
    }

    // MARK: - Caminhos

    private var root: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("flashcards/decks", isDirectory: true)
    }

    private func deckDir(_ slug: String) -> URL {
        root.appendingPathComponent(slug, isDirectory: true)
    }

    /// Caminho absoluto da mídia baixada (o renderer resolve refs relativas por aqui).
    nonisolated func mediaPath(slug: String, fileName: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent("flashcards/decks/\(slug)/media", isDirectory: true)
            .appendingPathComponent(fileName)
            .path
    }

    // MARK: - Consulta

    func manifest(slug: String) -> Manifest? {
        let url = deckDir(slug).appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    func isDownloaded(slug: String) -> Bool { manifest(slug: slug) != nil }

    /// Todos os baralhos baixados (pra tela de Downloads / total no device).
    func allManifests() -> [Manifest] {
        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }
        return dirs.compactMap { manifest(slug: $0.lastPathComponent) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func cards(slug: String) -> [PackCard] {
        let url = deckDir(slug).appendingPathComponent("cards.json")
        guard let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([PackCard].self, from: data)
        else { return [] }
        return cards
    }

    func remove(slug: String) {
        try? FileManager.default.removeItem(at: deckDir(slug))
    }

    // MARK: - Instalar um pack baixado

    /// Extrai o `.apkg` baixado pro diretório do baralho e grava o manifest.
    /// Roda fora da main thread (actor) — o parse de 5k cards não trava a UI.
    func install(
        packURL: URL,
        slug: String,
        title: String,
        version: String
    ) throws -> Manifest {
        let dir = deckDir(slug)
        let fm = FileManager.default
        // Instala do zero: pack novo substitui o anterior por completo.
        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir.appendingPathComponent("media"), withIntermediateDirectories: true)

        // 1) Descompacta o .apkg num temporário.
        let tmp = fm.temporaryDirectory.appendingPathComponent("pack-\(slug)-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        do {
            try fm.unzipItem(at: packURL, to: tmp)
        } catch {
            throw PackError.badArchive
        }

        // 2) Cards do collection.anki2 (schema v11).
        let collection = ["collection.anki21", "collection.anki2"]
            .map { tmp.appendingPathComponent($0) }
            .first { fm.fileExists(atPath: $0.path) }
        guard let collection else { throw PackError.noCollection }
        let cards = try Self.readCards(sqlitePath: collection.path)

        // 3) Mídia: `media` (JSON índice→nome) + arquivos numerados.
        var mediaCount = 0
        if let mediaData = try? Data(contentsOf: tmp.appendingPathComponent("media")),
           let index = try? JSONDecoder().decode([String: String].self, from: mediaData) {
            for (idx, name) in index {
                let src = tmp.appendingPathComponent(idx)
                guard fm.fileExists(atPath: src.path) else { continue }
                let dst = dir.appendingPathComponent("media").appendingPathComponent(name)
                try? fm.removeItem(at: dst)
                try? fm.moveItem(at: src, to: dst)
                mediaCount += 1
            }
        }

        // 4) cards.json + manifest.
        let cardsURL = dir.appendingPathComponent("cards.json")
        try JSONEncoder().encode(cards).write(to: cardsURL, options: .atomic)

        var manifest = Manifest(
            slug: slug, title: title, version: version,
            cardCount: cards.count, mediaCount: mediaCount, downloadedAt: Date()
        )
        manifest.bytes = Self.directorySize(dir)
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: dir.appendingPathComponent("manifest.json"), options: .atomic)
        NSLog("[DeckPackStore] %@ instalado: %d cards, %d mídias, %.1f MB",
              slug, cards.count, mediaCount, Double(manifest.bytes) / 1_048_576)
        return manifest
    }

    // MARK: - Leitura do SQLite v11 (SQLite3 do sistema — zero dependência)

    /// Lê as notas do pack. Campos vêm separados por 0x1f; frente = 1º campo,
    /// verso = 2º; `guid` = id do nosso card; model type 1 = cloze.
    private static func readCards(sqlitePath: String) throws -> [PackCard] {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(sqlitePath, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = handle
        else {
            throw PackError.sqlite("abrir")
        }
        defer { sqlite3_close(db) }

        // Quais models são cloze (col.models é um JSON com id → {type}).
        var clozeModels = Set<Int64>()
        var colStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT models FROM col LIMIT 1", -1, &colStmt, nil) == SQLITE_OK,
           sqlite3_step(colStmt) == SQLITE_ROW,
           let cText = sqlite3_column_text(colStmt, 0),
           let data = String(cString: cText).data(using: .utf8),
           let models = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            for (mid, value) in models {
                if let dict = value as? [String: Any], (dict["type"] as? Int) == 1,
                   let id = Int64(mid) {
                    clozeModels.insert(id)
                }
            }
        }
        sqlite3_finalize(colStmt)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT guid, mid, flds FROM notes", -1, &stmt, nil) == SQLITE_OK else {
            throw PackError.sqlite("notes")
        }
        defer { sqlite3_finalize(stmt) }

        var cards: [PackCard] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let guidText = sqlite3_column_text(stmt, 0),
                  let fldsText = sqlite3_column_text(stmt, 2)
            else { continue }
            let mid = sqlite3_column_int64(stmt, 1)
            let fields = String(cString: fldsText).components(separatedBy: "\u{1f}")
            let front = fields.first ?? ""
            guard !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            cards.append(PackCard(
                id: String(cString: guidText),
                front: front,
                back: fields.count > 1 ? fields[1] : "",
                cardType: clozeModels.contains(mid) ? "cloze" : "basic"
            ))
        }
        return cards
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let f as URL in e {
            total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
