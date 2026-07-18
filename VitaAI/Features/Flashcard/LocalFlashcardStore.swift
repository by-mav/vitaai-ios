import Foundation

// MARK: - LocalFlashcardStore
//
// Agendamento FSRS PERSISTIDO NO DEVICE, estilo Anki — offline de verdade.
//
// Problema que resolve: no caminho offline (bundle da Biblioteca) o review NÃO
// persistia local — só tentava sincronizar com o servidor (que falha sem rede).
// Resultado: toda vez que o aluno abria uma disciplina, TODO card nascia `new`
// e a fila vinha SEMPRE na mesma ordem fixa do JSON. Sem agendamento, sem
// "vencidos primeiro", sem teto diário de novos.
//
// Aqui cada card guarda seu estado FSRS-5 (stability/difficulty/status/reps/
// lapses/lastReview/due). O `FlashcardViewModel` grava a cada review; o
// `FlashcardBuilderViewModel` lê ao abrir a disciplina pra ordenar a fila
// (vencidos por `due`, depois novos com teto) e re-hidratar o estado salvo.
//
// Persistência: JSON atômico em `Documents/flashcards/fsrs-state.json`. Igual o
// `TranscricaoLocalStore` (o padrão de store local do app). ~6.000 cards da
// Biblioteca cabem tranquilo em memória (a fonte de verdade é o dicionário
// carregado; o disco é só o backup durável). O Anki faz o mesmo com o
// `collection.anki2` local. Escrita atômica por review garante que fechar/matar
// o app nunca perde o agendamento; o sync ao servidor continua best-effort.
//
// Actor: serializa leitura/escrita fora da main thread, sem data race.
actor LocalFlashcardStore {
    static let shared = LocalFlashcardStore()

    // MARK: - Modelo persistido
    //
    // Espelha os campos do `FsrsCardState` (reusado do FsrsScheduler) + o `due`
    // materializado (= lastReview + scheduledDays) pra filtrar "vencidos" sem
    // recalcular. Codable próprio porque `FsrsCardState` mora em outro arquivo
    // (a conformidade sintetizada exigiria estar no mesmo arquivo do tipo).
    struct Entry: Codable, Equatable {
        var stability: Double
        var difficulty: Double
        var elapsedDays: Int
        var scheduledDays: Int
        var reps: Int
        var lapses: Int
        var status: FsrsCardStatus   // já é Int + Codable no FsrsScheduler
        var lastReview: Date?
        var due: Date?

        /// Reconstrói o estado FSRS completo (reps/lapses inclusive) pro scheduler.
        var fsrs: FsrsCardState {
            FsrsCardState(
                stability: stability,
                difficulty: difficulty,
                elapsedDays: elapsedDays,
                scheduledDays: scheduledDays,
                reps: reps,
                lapses: lapses,
                status: status,
                lastReviewDate: lastReview
            )
        }

        /// Vencido em `date`? Sem `due` (não deveria após um review) = vencido.
        func isDue(at date: Date) -> Bool {
            guard let due else { return true }
            return due <= date
        }

        init(state s: FsrsCardState, due: Date?) {
            self.stability     = s.stability
            self.difficulty    = s.difficulty
            self.elapsedDays   = s.elapsedDays
            self.scheduledDays = s.scheduledDays
            self.reps          = s.reps
            self.lapses        = s.lapses
            self.status        = s.status
            self.lastReview    = s.lastReviewDate
            self.due           = due
        }
    }

    /// Envelope em disco com versão — permite migração futura sem quebrar leitura.
    private struct DiskModel: Codable {
        var version: Int
        var entries: [String: Entry]
    }

    private static let schemaVersion = 1

    // MARK: - Estado em memória (fonte de verdade após load)

    private var entries: [String: Entry] = [:]
    private var loaded = false
    private let fm = FileManager.default

    private init() {}

    // MARK: - Caminhos

    /// `<Documents>/flashcards/`
    private var rootFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("flashcards", isDirectory: true)
    }

    /// `<Documents>/flashcards/fsrs-state.json`
    private var fileURL: URL {
        rootFolder.appendingPathComponent("fsrs-state.json")
    }

    // MARK: - Load (boot)

    /// Carrega o estado do disco pra memória. Idempotente — chamar 2x não relê.
    /// Ok chamar no boot pra aquecer o cache; qualquer leitura garante o load
    /// sozinha via `ensureLoaded()`, então correção nunca depende deste call.
    func load() {
        ensureLoaded()
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Formato atual (envelope versionado) primeiro; se falhar, tenta o mapa
        // cru (tolerante a um arquivo de versão anterior).
        if let model = try? decoder.decode(DiskModel.self, from: data) {
            entries = model.entries
        } else if let raw = try? decoder.decode([String: Entry].self, from: data) {
            entries = raw
        } else {
            NSLog("[LocalFlashcardStore] fsrs-state.json ilegível — começando vazio")
        }
    }

    // MARK: - Leitura

    /// Estado FSRS salvo de um card (nil = card nunca visto = New).
    func state(for id: String) -> FsrsCardState? {
        ensureLoaded()
        return entries[id]?.fsrs
    }

    /// Estados salvos em lote (uma passada) — pro builder montar a fila da
    /// disciplina sem N idas ao actor. Só devolve os ids que EXISTEM (o resto = New).
    func states(forIds ids: [String]) -> [String: FsrsCardState] {
        ensureLoaded()
        var out: [String: FsrsCardState] = [:]
        out.reserveCapacity(ids.count)
        for id in ids {
            if let e = entries[id] { out[id] = e.fsrs }
        }
        return out
    }

    /// Ids vencidos (due <= `date`), pro caller montar "revisar agora". Anki-style.
    func dueCardIds(before date: Date = Date()) -> [String] {
        ensureLoaded()
        return entries.compactMap { $0.value.isDue(at: date) ? $0.key : nil }
    }

    // MARK: - Escrita

    /// Persiste o novo estado FSRS de um card. `due` é materializado a partir de
    /// lastReview + scheduledDays (mesma conta do Anki). Escrita atômica imediata
    /// — durável a fechar/matar o app.
    func save(id: String, state: FsrsCardState) {
        ensureLoaded()
        let due = Self.dueDate(for: state)
        entries[id] = Entry(state: state, due: due)
        persist()
    }

    /// Data em que o card volta a vencer. Cards em learning/relearning têm
    /// scheduledDays 0 → vencem no mesmo instante (voltam ainda hoje, igual Anki).
    static func dueDate(for state: FsrsCardState) -> Date? {
        guard let last = state.lastReviewDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: state.scheduledDays, to: last) ?? last
    }

    // MARK: - Persistência

    private func persist() {
        do {
            try fm.createDirectory(at: rootFolder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let model = DiskModel(version: Self.schemaVersion, entries: entries)
            let data = try encoder.encode(model)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[LocalFlashcardStore] persist falhou: %@", String(describing: error))
        }
    }
}
