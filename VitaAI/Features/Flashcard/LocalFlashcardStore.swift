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
        /// Quantas vezes o aluno apertou cada botão NESTE card (índice = rating
        /// FSRS 1..4 = Novamente/Difícil/Bom/Fácil). O `reps`/`lapses` sozinhos
        /// não dizem isso, e a tela do baralho mostra a distribuição — sem estes
        /// contadores aquele bloco seria chute. Opcional: entrada antiga (que não
        /// tem o campo) decodifica e começa zerada.
        var ratingCounts: [Int]?

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

        init(state s: FsrsCardState, due: Date?, ratingCounts: [Int]? = nil) {
            self.stability     = s.stability
            self.difficulty    = s.difficulty
            self.elapsedDays   = s.elapsedDays
            self.scheduledDays = s.scheduledDays
            self.reps          = s.reps
            self.lapses        = s.lapses
            self.status        = s.status
            self.lastReview    = s.lastReviewDate
            self.due           = due
            self.ratingCounts  = ratingCounts
        }

        /// Soma o rating recém-dado aos contadores (1..4).
        func counting(rating: Int) -> [Int] {
            var counts = ratingCounts ?? [0, 0, 0, 0]
            if counts.count < 4 { counts += Array(repeating: 0, count: 4 - counts.count) }
            let idx = min(max(rating, 1), 4) - 1
            counts[idx] += 1
            return counts
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

    /// Resumo do estudo OFFLINE (Biblioteca) pra tela de Estatísticas — que antes
    /// lia só do servidor e mostrava tudo 0. Deriva do estado FSRS por card:
    /// reps = nº de reviews (soma = total), lapses = erros, lastReview = dia da
    /// última revisão. `reviewsPerDay`/`streak` são aproximados (guardamos só o
    /// ÚLTIMO review de cada card, não o log completo) — bom o bastante pra o
    /// heatmap e a sequência não ficarem zerados. Rafael 2026-07-18.
    struct Aggregate: Sendable {
        var totalReviews = 0
        var cardsStudied = 0
        var lapses = 0
        var todayReviews = 0
        var dueCount = 0
        var youngCards = 0
        var matureCards = 0
        var reviewsPerDay: [String: Int] = [:]   // "yyyy-MM-dd" → nº de cards revisados naquele dia
        var streakDays = 0
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func aggregate(now: Date = Date()) -> Aggregate {
        ensureLoaded()
        let cal = Calendar.current
        var agg = Aggregate()
        for e in entries.values {
            agg.totalReviews += e.reps
            agg.lapses += e.lapses
            if let due = e.due, due <= now { agg.dueCount += 1 }
            // Só conta como estudo/review REAL se rateou (reps>0). Card só "visto"
            // pode ter estado salvo com reps=0 — não infla streak/heatmap/hoje.
            guard e.reps > 0 else { continue }
            agg.cardsStudied += 1
            switch CardMaturity.classify(reps: e.reps, intervalDays: e.scheduledDays) {
            case .mature: agg.matureCards += 1
            case .young:  agg.youngCards += 1
            case .new:    break   // reps>0 nunca é new
            }
            if let lr = e.lastReview {
                let key = Self.dayKeyFormatter.string(from: lr)
                agg.reviewsPerDay[key, default: 0] += 1
                if cal.isDateInToday(lr) { agg.todayReviews += 1 }
            }
        }
        // Sequência: dias consecutivos com ≥1 revisão terminando hoje (ou ontem,
        // pra não zerar antes de estudar no dia).
        var cursor = cal.startOfDay(for: now)
        if agg.reviewsPerDay[Self.dayKeyFormatter.string(from: cursor)] == nil {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while agg.reviewsPerDay[Self.dayKeyFormatter.string(from: cursor)] != nil {
            agg.streakDays += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return agg
    }

    // MARK: - Escrita

    /// Persiste o novo estado FSRS de um card. `due` é materializado a partir de
    /// lastReview + scheduledDays (mesma conta do Anki). Escrita atômica imediata
    /// — durável a fechar/matar o app.
    /// `rating` (1..4) acumula a distribuição de respostas do card — é o que a
    /// tela do baralho mostra em Novamente/Difícil/Bom/Fácil.
    func save(id: String, state: FsrsCardState, rating: Int? = nil) {
        ensureLoaded()
        let due = Self.dueDate(for: state)
        var counts = entries[id]?.ratingCounts
        if let rating {
            var next = counts ?? [0, 0, 0, 0]
            if next.count < 4 { next += Array(repeating: 0, count: 4 - next.count) }
            next[min(max(rating, 1), 4) - 1] += 1
            counts = next
        }
        entries[id] = Entry(state: state, due: due, ratingCounts: counts)
        persist()
    }

    /// Resumo POR BARALHO (ids do deck) pra tela central: quantos novos, quantos
    /// pra revisar hoje, quantos já estudados e a distribuição de respostas.
    struct DeckSummary: Sendable, Equatable {
        var total = 0
        var studied = 0
        var due = 0
        var newCards = 0
        /// [Novamente, Difícil, Bom, Fácil]
        var ratings = [0, 0, 0, 0]

        /// Nota = acertos "de primeira" sobre o total de respostas (Bom+Fácil).
        var scorePercent: Int {
            let total = ratings.reduce(0, +)
            guard total > 0 else { return 0 }
            return Int((Double(ratings[2] + ratings[3]) / Double(total) * 100).rounded())
        }
    }

    func deckSummary(cardIds: [String], now: Date = Date()) -> DeckSummary {
        ensureLoaded()
        var s = DeckSummary()
        s.total = cardIds.count
        for id in cardIds {
            guard let e = entries[id], e.reps > 0 else {
                s.newCards += 1
                continue
            }
            s.studied += 1
            if e.isDue(at: now) { s.due += 1 }
            if let counts = e.ratingCounts {
                for (i, c) in counts.prefix(4).enumerated() { s.ratings[i] += c }
            }
        }
        return s
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
