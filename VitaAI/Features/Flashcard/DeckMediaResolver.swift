import Foundation
import UIKit

// MARK: - DeckMediaResolver — acha a mídia dos baralhos BAIXADOS
//
// O renderer do card (`FlashcardContentView`, `FlashcardAudioSegment`) resolve
// `<img src="medicina/x.jpg">` de forma SÍNCRONA. Os packs guardam a mídia
// achatada em `Documents/flashcards/decks/<slug>/media/x.jpg`, então aqui fica
// um índice nome→caminho montado uma vez (e invalidado quando um baralho é
// baixado/removido) pra a busca não varrer o disco a cada card.
enum DeckMediaResolver {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var index: [String: String]?

    /// Descarta o índice — chamar após instalar ou remover um baralho.
    static func invalidate() {
        lock.lock()
        index = nil
        lock.unlock()
    }

    /// Caminho absoluto do arquivo de mídia baixado, por nome (ex "x.jpg").
    static func path(named fileName: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if index == nil { index = buildIndex() }
        return index?[fileName]
    }

    static func image(named fileName: String) -> UIImage? {
        guard let path = path(named: fileName) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private static func buildIndex() -> [String: String] {
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("flashcards/decks", isDirectory: true)
        guard let decks = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var map: [String: String] = [:]
        for deck in decks {
            let media = deck.appendingPathComponent("media", isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: media, includingPropertiesForKeys: nil) else {
                continue
            }
            for file in files {
                // Primeiro baralho que tiver o nome ganha (nomes colidindo entre
                // baralhos são o mesmo arquivo da Biblioteca).
                map[file.lastPathComponent] = file.path
            }
        }
        return map
    }
}
