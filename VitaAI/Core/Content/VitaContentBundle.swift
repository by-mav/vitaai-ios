import Foundation

/// Conteúdo curado da Vita — os cards que o aluno BAIXOU no device.
///
/// 🚨 Nada de conteúdo vai embarcado na apk (Rafael 2026-07-19, spec
/// `flashcards-offline-download-por-baralho.md`): o aluno TOCA em baixar, o
/// pack `.apkg` do baralho vem do servidor e fica salvo — a partir daí estuda
/// offline pra sempre, até remover. Antes o app carregava 71 MB
/// (`FlashcardMedia/` + `vita-flashcards-library.json`) que TODO aluno baixava
/// na App Store mesmo sem abrir flashcards.
///
/// Esta camada é a leitura: o `DeckPackStore` guarda os packs; aqui eles viram
/// os cards que as telas consomem. O que o aluno cria (escrito à mão ou gerado
/// pela IA) vive no banco dele, não aqui.
actor VitaContentBundle {
    static let shared = VitaContentBundle()

    struct BundleCard: Decodable {
        let id: String
        let front: String
        let back: String
        let disciplineSlug: String
        let deckTitle: String
    }

    /// Os cards curados de uma disciplina BAIXADA — sem rede, sem bundle.
    /// Vazio = o aluno ainda não baixou esse baralho (a tela oferece baixar).
    func cards(disciplineSlug: String) async -> [BundleCard] {
        let packed = await DeckPackStore.shared.cards(slug: disciplineSlug)
        guard !packed.isEmpty else { return [] }
        let title = await DeckPackStore.shared.manifest(slug: disciplineSlug)?.title
            ?? disciplineSlug
        return packed.map {
            BundleCard(
                id: $0.id,
                front: $0.front,
                back: $0.back,
                disciplineSlug: disciplineSlug,
                deckTitle: title
            )
        }
    }

    /// Contagem por disciplina baixada (tela monta a árvore offline).
    func countsByDiscipline() async -> [String: Int] {
        var map: [String: Int] = [:]
        for m in await DeckPackStore.shared.allManifests() {
            map[m.slug] = m.cardCount
        }
        return map
    }

    /// Total de cards curados NO DEVICE (Estatísticas conta o que existe aqui).
    func totalCards() async -> Int {
        await DeckPackStore.shared.allManifests().reduce(0) { $0 + $1.cardCount }
    }

    /// Disciplina curada baixada (slug + título humano) — picker de mover.
    struct Discipline: Identifiable, Equatable {
        let slug: String
        let title: String
        let count: Int
        var id: String { slug }
    }

    func disciplines() async -> [Discipline] {
        await DeckPackStore.shared.allManifests()
            .map { Discipline(slug: $0.slug, title: $0.title, count: $0.cardCount) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// O aluno já baixou algum baralho curado?
    func isAvailable() async -> Bool {
        !(await DeckPackStore.shared.allManifests().isEmpty)
    }
}
