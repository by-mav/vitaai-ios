import Foundation

/// Conteúdo curado da Vita EMBUTIDO no app (bundle read-only) — offline total.
///
/// Os cards da Biblioteca Vita (curados, iguais pra todo aluno) vêm no
/// `vita-flashcards-library.json` dentro da apk. Estudá-los NUNCA deve precisar
/// de rede — igual o Anki lê o `collection.anki2` local (Rafael 2026-07-17).
///
/// Isto é só a Biblioteca (conteúdo #1, congelado por versão do app). O que o
/// aluno cria (#2 escrito à mão, #3 gerado pela IA) vai pro banco local
/// read-write dele, não aqui.
///
/// As imagens dos cards já estão no bundle (`FlashcardMedia/`, 69 MB) e o
/// `FlashcardContentView` já as resolve — então texto + imagem ficam offline.
actor VitaContentBundle {
    static let shared = VitaContentBundle()

    private struct Payload: Decodable {
        let version: Int
        let totalCards: Int
        let cards: [BundleCard]
    }

    struct BundleCard: Decodable {
        let id: String
        let front: String
        let back: String
        let disciplineSlug: String
        let deckTitle: String
    }

    /// Índice disciplina → cards, montado uma vez (lazy). ~5.900 cards / ~2 MB —
    /// cabe em memória tranquilo (é o JSON pequeno; as 154k questões usam SQLite).
    private var byDiscipline: [String: [BundleCard]]?

    private func index() -> [String: [BundleCard]] {
        if let byDiscipline { return byDiscipline }
        var map: [String: [BundleCard]] = [:]
        guard
            let url = Bundle.main.url(forResource: "vita-flashcards-library", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            NSLog("[VitaContentBundle] vita-flashcards-library.json ausente ou inválido no bundle")
            byDiscipline = [:]
            return [:]
        }
        for card in payload.cards {
            map[card.disciplineSlug, default: []].append(card)
        }
        byDiscipline = map
        NSLog("[VitaContentBundle] %d cards curados em %d disciplinas (offline)", payload.cards.count, map.count)
        return map
    }

    /// Os cards curados de uma disciplina, do bundle — sem rede.
    func cards(disciplineSlug: String) -> [BundleCard] {
        index()[disciplineSlug] ?? []
    }

    /// Contagem por disciplina, pra tela montar a árvore sem chamar o servidor.
    func countsByDiscipline() -> [String: Int] {
        index().mapValues(\.count)
    }

    /// Disciplina da Biblioteca (slug + título humano). Usado pelo sheet
    /// "Mover para outro baralho" do navegador de cards.
    struct Discipline: Identifiable, Equatable {
        let slug: String
        let title: String
        let count: Int
        var id: String { slug }
    }

    /// Todas as disciplinas curadas, ordenadas por título — pra o picker de mover.
    func disciplines() -> [Discipline] {
        index().compactMap { slug, cards -> Discipline? in
            guard let first = cards.first else { return nil }
            return Discipline(slug: slug, title: first.deckTitle, count: cards.count)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Existe conteúdo curado embutido? (falso só se o JSON sumiu do bundle.)
    func isAvailable() -> Bool {
        !index().isEmpty
    }
}
