import Foundation
import Observation
import Sentry

// MARK: - Session State

enum FlashcardSessionPhase {
    case loading
    case studying
    case reviewing     // brief pause animating to next card
    case finished
    case empty         // no cards due
    case error(String)
}

// MARK: - FlashcardViewModel

@Observable
@MainActor
final class FlashcardViewModel {

    // MARK: Public state (read by views)

    private(set) var phase: FlashcardSessionPhase = .loading
    private(set) var deckTitle: String = ""
    private(set) var cards: [FlashcardCard] = []
    private(set) var currentIndex: Int = 0
    private(set) var isFlipped: Bool = false
    private(set) var totalReviewed: Int = 0
    private(set) var correctCount: Int = 0
    private(set) var result: FlashcardSessionResult? = nil
    private(set) var studySessionId: String? = nil

    /// "1 sessao aberta global" (open-session.ts): o create respondeu 409 porque
    /// ja ha treino aberto. A tela pergunta "encerrar e comecar novo?" — mesmo
    /// contrato/UX do QBank (QBankBuilderScreen). Sem isto o 409 ficava so num
    /// NSLog, `studySessionId` nascia nil e a sessao NUNCA fechava no servidor
    /// (39 abandoned / 0 finished no banco de dev).
    var openSessionConflict: OpenSessionInfo? = nil

    // Rating dado a cada card respondido, em ordem — alimenta os "risquinhos"
    // segmentados do progresso (cada traço colorido pela resposta do aluno).
    private(set) var ratingHistory: [ReviewRating] = []

    // Ponto de controle (a cada 10 cartas): visível pausa a sessão; enabled vem
    // do toggle de ajustes. Rafael 2026-07-17.
    var checkpointVisible: Bool = false
    var checkpointEnabled: Bool = true
    var checkpointInterval: Int = 10

    /// Dados do ponto de controle, derivados do histórico de respostas.
    var checkpointData: FlashcardCheckpointData {
        var counts = [ReviewRating: Int]()
        for r in ratingHistory { counts[r, default: 0] += 1 }
        // Nota ponderada: Erro=0, Difícil=⅓, Bom=⅔, Fácil=1.
        let weights: [ReviewRating: Double] = [.again: 0, .hard: 1.0/3, .good: 2.0/3, .easy: 1]
        let grade = ratingHistory.isEmpty ? 0
            : ratingHistory.reduce(0.0) { $0 + (weights[$1] ?? 0) } / Double(ratingHistory.count) * 100
        let studied = totalReviewed
        let total = cards.count
        let perCard = studied > 0 ? Double(elapsedSeconds) / Double(studied) : 0
        let remainingSecs = Int((Double(max(total - studied, 0)) * perCard).rounded())
        return FlashcardCheckpointData(
            gradePercent: Int(grade.rounded()),
            again: counts[.again] ?? 0,
            hard: counts[.hard] ?? 0,
            good: counts[.good] ?? 0,
            easy: counts[.easy] ?? 0,
            elapsedSeconds: elapsedSeconds,
            cardsStudied: studied,
            totalCards: total,
            estimatedRemainingSeconds: remainingSecs
        )
    }

    // FSRS-5 per-card state (parallel array, indexed by cards)
    private(set) var fsrsStates: [FsrsCardState] = []

    // Session timing
    private(set) var sessionStartDate: Date = Date()
    private(set) var cardStartDate: Date = Date()
    private var accumulatedElapsedSeconds: Int = 0

    // Undo support
    private(set) var canUndo: Bool = false
    private var undoSnapshot: UndoSnapshot?

    // MARK: Private

    private let api: VitaAPI
    private let gamificationEvents: GamificationEventManager
    private var scheduler = FsrsScheduler()
    private var leechThreshold: Int = 8
    /// Deck da fila em estudo — usado pra recriar a sessao no "comecar novo".
    private var currentDeckId: String = ""

    private struct UndoSnapshot {
        let cardIndex: Int
        let fsrsState: FsrsCardState
        let wasFlipped: Bool
        let totalReviewed: Int
        let correctCount: Int
    }

    // MARK: Computed helpers

    var currentCard: FlashcardCard? {
        cards.indices.contains(currentIndex) ? cards[currentIndex] : nil
    }

    var elapsedSeconds: Int {
        accumulatedElapsedSeconds + Int(Date().timeIntervalSince(sessionStartDate))
    }

    /// FSRS-5 interval previews for the current card's rating buttons
    var intervalPreviews: [ReviewRating: Int] {
        guard fsrsStates.indices.contains(currentIndex) else { return [:] }
        let preview = scheduler.preview(card: fsrsStates[currentIndex])
        return [
            .again: preview.again,
            .hard:  preview.hard,
            .good:  preview.good,
            .easy:  preview.easy,
        ]
    }

    // MARK: - Init

    init(api: VitaAPI, gamificationEvents: GamificationEventManager) {
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Load

    func loadDeck(_ deckId: String, tagFilter: String? = nil, sessionId: String? = nil) {
        phase = .loading
        isFlipped = false
        currentIndex = 0
        totalReviewed = 0
        correctCount = 0
        ratingHistory = []
        result = nil
        studySessionId = nil
        accumulatedElapsedSeconds = 0
        sessionStartDate = Date()
        cardStartDate = Date()

        // OFFLINE do bundle: abrir uma disciplina da Biblioteca traz os cards
        // curados PRONTOS do handoff (VitaContentBundle) — monta a sessão sem
        // tocar a rede. É o offline de verdade: o card sempre abre. Um sessionId
        // "bundle:<slug>" (ou cards no handoff) marca este caminho.
        let bundle = FlashcardMultiDeckHandoff.shared.consumeBundleCards()
        if !bundle.cards.isEmpty {
            let deck = FlashcardDeck(
                id: deckId,
                title: bundle.title ?? "Flashcards",
                cards: bundle.cards
            )
            // Estudar baralho (inclusive Biblioteca/offline) tem que registrar
            // sessao no servidor, senao o card "Continuar" nunca mostra flashcards
            // (questoes/simulado criam sessao; este caminho nao criava). Best-effort:
            // online cria; offline cai no catch e o estudo segue local.
            Task { @MainActor in
                var retomada: FlashcardStudySession?
                if studySessionId == nil, !deck.cards.isEmpty {
                    retomada = await createSession(for: deck, abandonExisting: false)
                }
                // Retomada = continua de onde parou (senão o progresso salvo
                // seria sobrescrito por 0 ao sair).
                startSession(
                    deck: deck,
                    initialIndex: retomada?.currentIndex ?? 0,
                    initialCorrectCount: retomada?.correctCount ?? 0,
                    initialRatings: retomada?.ratings.compactMap(ReviewRating.init(rawValue:)) ?? []
                )
            }
            return
        }

        // Multi-seleção: se o builder gravou vários ids, estuda todos juntos.
        let handoff = FlashcardMultiDeckHandoff.shared.consume()
        let deckIds = (handoff.count > 1 && handoff.contains(deckId)) ? handoff : [deckId]
        // Sessão rápida (issue #188 I1): fila EXATA calculada pelo servidor.
        let quick = FlashcardMultiDeckHandoff.shared.consumeQuickSession()
        let requestedSessionId = sessionId ?? quick.sessionId

        Task { @MainActor in
            do {
                let persisted: FlashcardStudySession?
                if let requestedSessionId {
                    persisted = try await api.getFlashcardStudySession(id: requestedSessionId)
                } else {
                    persisted = nil
                }
                let queueIds = persisted?.cardIds ?? quick.cardIds
                let queueTitle = persisted?.title ?? quick.title
                studySessionId = persisted?.id ?? quick.sessionId
                accumulatedElapsedSeconds = persisted?.elapsedSeconds ?? 0
                sessionStartDate = Date()
                let deck = try await fetchDeck(
                    deckIds: deckIds,
                    tagFilter: tagFilter,
                    quickSession: queueIds.isEmpty ? nil : (queueIds, queueTitle)
                )
                // A sessao rapida ja nasce persistida no builder. Uma abertura
                // direta de baralho, por outro lado, precisa registrar a fila
                // exata que acabou de ser montada antes do primeiro review.
                var retomada: FlashcardStudySession?
                if studySessionId == nil, !deck.cards.isEmpty {
                    retomada = await createSession(for: deck, abandonExisting: false)
                }
                // `persisted` (sessão pedida por id) tem prioridade; `retomada` é
                // a que já estava aberta deste baralho — sem ela, reabrir zerava
                // o progresso no servidor.
                let base = persisted ?? retomada
                startSession(
                    deck: deck,
                    initialIndex: base?.currentIndex ?? 0,
                    initialCorrectCount: base?.correctCount ?? 0,
                    initialRatings: base?.ratings.compactMap(ReviewRating.init(rawValue:)) ?? []
                )
            } catch {
                phase = .error("Erro ao carregar flashcards: \(error.localizedDescription)")
            }
        }
    }

    /// Registra a fila no servidor. O 409 do guard "1 sessao aberta global"
    /// vira pergunta na tela (`openSessionConflict`) em vez de sumir num log:
    /// sem sessao registrada o estudo ate roda, mas `endSession()` nao tem o
    /// que fechar e a sessao antiga fica `active` pra sempre, bloqueando TODAS
    /// as proximas (a espiral que zerou os `finished`).
    /// Devolve a sessão RETOMADA quando já havia uma aberta deste mesmo baralho
    /// (nil quando criou uma nova ou quando o conflito é de outro baralho).
    @discardableResult
    private func createSession(for deck: FlashcardDeck, abandonExisting: Bool) async
        -> FlashcardStudySession? {
        do {
            let created = try await api.createFlashcardSession(
                body: FlashcardSessionBody(
                    groupSlugs: nil,
                    mode: "specific",
                    limit: nil,
                    showHints: nil,
                    skipEasy: nil,
                    cardIds: deck.cards.map(\.id),
                    deckId: deck.id,
                    title: deck.title,
                    abandonExisting: abandonExisting ? true : nil
                )
            )
            studySessionId = created.sessionId
            openSessionConflict = nil
        } catch let APIError.conflict(_, body) {
            if let conflict = try? JSONDecoder().decode(OpenSessionConflict.self, from: body),
               conflict.error == "open_session_exists" {
                // Aberta É DESTE baralho ⇒ é a mesma sessão: RETOMA de onde
                // parou, sem perguntar nada. Antes recomeçava do zero e, ao
                // sair, o persistSession gravava currentIndex=0 por cima do
                // progresso salvo — o treino sumia de "Em andamento" (que só
                // lista quem tem progresso > 0). Rafael 2026-07-24.
                // Identidade da sessão = a FILA de cards, não o deckId: o
                // servidor grava o deck REAL dos cards (um baralho da Biblioteca
                // agrupa vários), então o id que o app manda não volta igual.
                if conflict.openSession.type == "flashcards",
                   let aberta = try? await api.getFlashcardStudySession(id: conflict.openSession.id),
                   !aberta.cardIds.isEmpty,
                   aberta.deckId == deck.id
                     || Set(aberta.cardIds).isSubset(of: Set(deck.cards.map(\.id))) {
                    studySessionId = aberta.id
                    openSessionConflict = nil
                    return aberta
                }
                openSessionConflict = conflict.openSession
            } else {
                NSLog("[Flashcard] create study session conflict (unparsed)")
            }
        } catch {
            // Falha transitoria de rede: o estudo segue utilizavel; o log torna
            // a falha de persistencia visivel.
            NSLog("[Flashcard] create study session failed: %@", String(describing: error))
        }
        return nil
    }

    /// "Encerrar e comecar novo" do alerta de conflito: fecha a sessao aberta
    /// (qualquer atividade) e registra esta.
    func resolveOpenSessionConflict() async {
        openSessionConflict = nil
        guard studySessionId == nil, !cards.isEmpty else { return }
        let deck = FlashcardDeck(id: currentDeckId, title: deckTitle, cards: cards)
        await createSession(for: deck, abandonExisting: true)
    }

    // MARK: - User actions

    func flipCard() {
        guard case .studying = phase else { return }
        isFlipped.toggle()
    }

    func rateCard(_ rating: ReviewRating) {
        guard case .studying = phase, let card = currentCard else { return }
        guard fsrsStates.indices.contains(currentIndex) else { return }

        // Save undo snapshot before modifying state
        undoSnapshot = UndoSnapshot(
            cardIndex: currentIndex,
            fsrsState: fsrsStates[currentIndex],
            wasFlipped: isFlipped,
            totalReviewed: totalReviewed,
            correctCount: correctCount
        )
        canUndo = true
        ratingHistory.append(rating)

        phase = .reviewing

        // Apply FSRS-5 locally (instant, offline-capable)
        let result = scheduler.schedule(
            card: fsrsStates[currentIndex],
            rating: rating,
            now: Date()
        )
        fsrsStates[currentIndex] = result.card

        // Persiste o agendamento no device (offline-first, estilo Anki). É o que
        // faz a próxima abertura da disciplina ordenar por `due` em vez de
        // recomeçar tudo `new`. O sync ao servidor abaixo continua best-effort —
        // isto grava LOCAL primeiro, independente de rede.
        let scheduledState = result.card
        let scheduledCardId = card.id
        let scheduledRating = rating.rawValue
        Task {
            await LocalFlashcardStore.shared.save(
                id: scheduledCardId, state: scheduledState, rating: scheduledRating
            )
        }

        // Leech detection: auto-suspend cards that exceed the lapse threshold
        if result.card.lapses >= leechThreshold && leechThreshold < 999 {
            let leechCardId = card.id
            Task.detached { [api = self.api] in
                for attempt in 0..<2 {
                    do {
                        _ = try await api.suspendFlashcard(cardId: leechCardId)
                        break
                    } catch {
                        if attempt == 0 { try? await Task.sleep(for: .milliseconds(500)) }
                    }
                }
            }
        }

        // API review with retry — session advances regardless, but we retry failures
        let cardId = card.id
        let responseTimeMs = Int64(Date().timeIntervalSince(cardStartDate) * 1000)
        VitaAnalytics.capture(event: "flashcard_card_rated", properties: [
            "card_id": cardId,
            "rating": rating.rawValue,
            "seconds_elapsed": Int(responseTimeMs / 1000),
        ])
        let reviewId = UUID().uuidString
        Task.detached { [api = self.api, gamificationEvents = self.gamificationEvents] in
            for attempt in 0..<3 {
                do {
                    let response = try await api.reviewFlashcard(
                        cardId: cardId,
                        rating: rating.rawValue,
                        responseTimeMs: responseTimeMs,
                        reviewId: reviewId
                    )
                    if let award = response.award {
                        await gamificationEvents.handleActivityResponse(
                            award,
                            previousLevel: nil,
                            source: .flashcardReview
                        )
                    }
                    break
                } catch {
                    if attempt < 2 {
                        try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
                    } else {
                        print("[Flashcard] Review sync failed after 3 attempts for card \(cardId)")
                    }
                }
            }
        }

        // Brief pause for reviewing state visual feedback, then advance
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            advanceCard(rating: rating)
        }
    }

    /// Persiste a fila e o ponto exato da sessão. Fechar a tela ou matar o app
    /// nunca encerra a sessão; o backend continua sendo a fonte de verdade.
    func persistSession() async {
        guard let studySessionId else { return }
        let elapsed = elapsedSeconds
        let progress = FlashcardStudySessionProgress(
            cardIds: cards.map(\.id),
            ratings: ratingHistory.map(\.rawValue),
            currentIndex: min(totalReviewed, cards.count),
            correctCount: min(correctCount, totalReviewed),
            elapsedSeconds: elapsed
        )
        do {
            _ = try await api.updateFlashcardStudySession(id: studySessionId, progress: progress)
            accumulatedElapsedSeconds = elapsed
            sessionStartDate = Date()
        } catch {
            NSLog("[Flashcard] persist session failed: %@", String(describing: error))
        }
    }

    /// Fecha a sessao no servidor (status `finished`). Chamado no fim natural da
    /// fila, no encerramento manual e quando suspender/enterrar esvazia a fila.
    ///
    /// Com retry (3x): um finish perdido deixa a sessao `active` pra sempre, e o
    /// guard "1 sessao aberta global" passa a barrar TODAS as proximas — o
    /// mesmo padrao de retry que `reviewFlashcard` ja usa.
    func endSession() async {
        guard let id = studySessionId else { return }
        await persistSession()
        for attempt in 1...3 {
            do {
                _ = try await api.finishFlashcardStudySession(id: id)
                studySessionId = nil
                return
            } catch {
                if attempt == 3 {
                    NSLog("[Flashcard] finish session failed after 3 attempts: %@", String(describing: error))
                    SentrySDK.capture(message: "flashcard finish session failed") { scope in
                        scope.setLevel(.warning)
                        scope.setExtra(value: id, key: "session_id")
                        scope.setExtra(value: String(describing: error), key: "error")
                    }
                } else {
                    try? await Task.sleep(for: .milliseconds(400 * attempt))
                }
            }
        }
    }

    // MARK: - Editar / mover / excluir o card em estudo
    //
    // Cards da Biblioteca (sessão de bundle, sem deck do aluno) são acervo
    // compartilhado: o servidor responde 403. A tela esconde as ações nesse
    // caso — `canMutateCurrentCard` é o gate único.

    var canMutateCurrentCard: Bool { !currentDeckId.isEmpty && currentCard != nil }

    /// Salva frente/verso do card em estudo e reflete na tela na hora.
    func editCurrentCard(front: String, back: String) async -> Bool {
        guard let card = currentCard, cards.indices.contains(currentIndex) else { return false }
        let f = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty else { return false }
        do {
            try await api.updateFlashcard(cardId: card.id, front: f, back: b)
            var updated = card
            updated = FlashcardCard(
                id: card.id,
                front: f,
                back: b,
                stability: card.stability,
                difficulty: card.difficulty,
                state: card.state,
                scheduledDays: card.scheduledDays,
                nextReviewAt: card.nextReviewAt
            )
            cards[currentIndex] = updated
            return true
        } catch {
            NSLog("[Flashcard] edit card failed: %@", String(describing: error))
            return false
        }
    }

    /// Move o card em estudo pra outro baralho do aluno e tira ele da fila.
    func moveCurrentCard(toDeckId deckId: String) async -> Bool {
        guard let card = currentCard else { return false }
        do {
            try await api.moveFlashcard(cardId: card.id, toDeckId: deckId)
            removeCurrentCardFromQueue()
            return true
        } catch {
            NSLog("[Flashcard] move card failed: %@", String(describing: error))
            return false
        }
    }

    /// Exclui (soft-delete) o card em estudo. NÃO-otimista: só sai da fila
    /// depois do server confirmar, pra nunca ressuscitar num re-fetch.
    func deleteCurrentCard() async -> Bool {
        guard let card = currentCard else { return false }
        do {
            try await api.deleteFlashcard(cardId: card.id)
            removeCurrentCardFromQueue()
            return true
        } catch {
            NSLog("[Flashcard] delete card failed: %@", String(describing: error))
            return false
        }
    }

    /// Tira o card atual da fila — mesma mecânica de índice do suspend/bury,
    /// inclusive fechar a sessão quando o card removido era o último.
    private func removeCurrentCardFromQueue() {
        guard cards.indices.contains(currentIndex) else { return }
        cards.remove(at: currentIndex)
        if fsrsStates.indices.contains(currentIndex) { fsrsStates.remove(at: currentIndex) }

        if cards.isEmpty {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(Date().timeIntervalSince(sessionStartDate) * 1000),
                streakCount: correctCount
            )
            phase = .finished
            Task { await endSession() }
        } else if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }
        isFlipped = false
        cardStartDate = Date()
        Task { await persistSession() }
    }

    /// Baralhos de destino (os outros do aluno) pro sheet de mover.
    func moveDestinations() async -> [VitaContentBundle.Discipline] {
        guard let decks = try? await api.getFlashcardDecks(deckLimit: 1000, summary: true) else { return [] }
        return decks
            .filter { $0.userId != nil && $0.id != currentDeckId }
            .map { VitaContentBundle.Discipline(slug: $0.id, title: $0.title, count: $0.cardCount) }
    }

    /// Remove the current card from the session (suspend)
    func suspendCurrentCard() {
        guard case .studying = phase, let card = currentCard else { return }

        // Fire-and-forget API call to suspend on server
        let cardId = card.id
        Task.detached { [api = self.api] in
            _ = try? await api.suspendFlashcard(cardId: cardId)
        }

        // Remove from local session
        cards.remove(at: currentIndex)
        fsrsStates.remove(at: currentIndex)

        if cards.isEmpty {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(Date().timeIntervalSince(sessionStartDate) * 1000),
                streakCount: correctCount
            )
            phase = .finished
            // Suspender o ultimo card TERMINA a sessao — fechar aqui tambem,
            // senao ela fica `active` e trava as proximas (guard 1-global).
            Task { await endSession() }
        } else if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }
        isFlipped = false
        cardStartDate = Date()
        Task { await persistSession() }
    }

    /// Undo the last rating — go back to previous card
    func undoLastRating() {
        guard let snapshot = undoSnapshot else { return }
        guard case .studying = phase else { return }

        // Restore state
        currentIndex = snapshot.cardIndex
        fsrsStates[snapshot.cardIndex] = snapshot.fsrsState
        totalReviewed = snapshot.totalReviewed
        correctCount = snapshot.correctCount
        isFlipped = false
        cardStartDate = Date()
        if !ratingHistory.isEmpty { ratingHistory.removeLast() }

        undoSnapshot = nil
        canUndo = false
        Task { await persistSession() }
    }

    /// Bury current card — hide until tomorrow (remove from session, don't delete)
    func buryCurrentCard() {
        guard case .studying = phase, let card = currentCard else { return }

        // Fire-and-forget API call to bury on server
        let cardId = card.id
        Task.detached { [api = self.api] in
            _ = try? await api.buryFlashcard(cardId: cardId)
        }

        // Remove from local session
        cards.remove(at: currentIndex)
        fsrsStates.remove(at: currentIndex)

        if cards.isEmpty {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(Date().timeIntervalSince(sessionStartDate) * 1000),
                streakCount: correctCount
            )
            phase = .finished
            // Enterrar o ultimo card TERMINA a sessao — mesmo motivo do suspend.
            Task { await endSession() }
        } else if currentIndex >= cards.count {
            currentIndex = cards.count - 1
        }
        isFlipped = false
        cardStartDate = Date()
        Task { await persistSession() }
    }

    /// Apply settings from the settings sheet
    func applySettings(_ settings: FlashcardSettings) {
        // Update FSRS scheduler with desired retention
        scheduler = FsrsScheduler(params: FsrsParameters(requestedRetention: settings.desiredRetention))
        leechThreshold = settings.leechThreshold
        checkpointEnabled = settings.checkpointEnabled
        checkpointInterval = settings.checkpointInterval

        // Sort order
        switch settings.sortOrder {
        case .random:
            let combined = Array(zip(cards, fsrsStates))
            let shuffled = combined.shuffled()
            cards = shuffled.map { $0.0 }
            fsrsStates = shuffled.map { $0.1 }
        case .dueDate:
            // Sort by FSRS scheduled days (ascending = most overdue first)
            let combined = Array(zip(cards, fsrsStates)).sorted { $0.1.scheduledDays < $1.1.scheduledDays }
            cards = combined.map { $0.0 }
            fsrsStates = combined.map { $0.1 }
        case .added:
            break // Keep original order
        }
        currentIndex = 0
        isFlipped = false

        // Filter by session mode
        switch settings.sessionMode {
        case .newOnly:
            let filtered = (0..<cards.count).filter { fsrsStates[$0].status == .new }
            cards = filtered.map { cards[$0] }
            fsrsStates = filtered.map { fsrsStates[$0] }
        case .reviewOnly:
            let filtered = (0..<cards.count).filter { fsrsStates[$0].status != .new }
            cards = filtered.map { cards[$0] }
            fsrsStates = filtered.map { fsrsStates[$0] }
        case .all:
            break
        }

        // Apply daily limits
        let newLimit = settings.dailyNewLimit
        let reviewLimit = settings.dailyReviewLimit
        var newCount = 0
        var reviewCount = 0
        var keep: [Int] = []
        for i in 0..<cards.count {
            if fsrsStates[i].status == .new {
                if newCount < newLimit { keep.append(i); newCount += 1 }
            } else {
                if reviewCount < reviewLimit { keep.append(i); reviewCount += 1 }
            }
        }
        cards = keep.map { cards[$0] }
        fsrsStates = keep.map { fsrsStates[$0] }

        currentIndex = min(currentIndex, max(0, cards.count - 1))

        if cards.isEmpty {
            phase = .empty
        }
        Task { await persistSession() }
    }

    // MARK: - Private

    private func startSession(
        deck: FlashcardDeck,
        initialIndex: Int = 0,
        initialCorrectCount: Int = 0,
        initialRatings: [ReviewRating] = []
    ) {
        guard !deck.cards.isEmpty else {
            deckTitle = deck.title
            result = FlashcardSessionResult(totalCards: 0, correctCount: 0, timeSpentMs: 0, streakCount: 0)
            phase = .empty
            return
        }

        deckTitle = deck.title
        currentDeckId = deck.id
        cards = deck.cards
        let safeIndex = min(max(0, initialIndex), deck.cards.count)
        currentIndex = min(safeIndex, max(0, deck.cards.count - 1))
        isFlipped = false
        totalReviewed = safeIndex
        correctCount = min(initialCorrectCount, safeIndex)
        ratingHistory = Array(initialRatings.prefix(safeIndex))
        sessionStartDate = Date()
        cardStartDate = Date()
        VitaAnalytics.capture(event: "flashcard_review_started", properties: [
            "deck_id": deck.id,
            "cards_count": deck.cards.count,
        ])

        // Initialise FSRS-5 state from card metadata.
        // Cards that previously used SM-2 fields (easeFactor/interval) are migrated
        // via FsrsCardState.migratedFromSM2() — data is never lost.
        fsrsStates = cards.map { card in
            if card.difficulty > 0 && card.stability > 0 {
                // Already has FSRS-5 native state
                return FsrsCardState(
                    stability:     card.stability,
                    difficulty:    card.difficulty,
                    elapsedDays:   0,
                    scheduledDays: card.scheduledDays,
                    reps:          card.state > 0 ? 1 : 0,
                    lapses:        0,
                    status:        FsrsCardStatus(rawValue: card.state) ?? .new,
                    lastReviewDate: card.nextReviewAt.map { Calendar.current.date(byAdding: .day, value: -card.scheduledDays, to: $0) } ?? nil
                )
            } else {
                // Legacy SM-2 card — migrate gracefully
                return FsrsCardState.migratedFromSM2(
                    easeFactor:     max(1.3, card.stability == 0 ? 2.5 : card.stability),
                    repetitions:    card.state > 0 ? 1 : 0,
                    interval:       card.scheduledDays,
                    lastReviewDate: card.nextReviewAt.map {
                        Calendar.current.date(byAdding: .day, value: -card.scheduledDays, to: $0)
                    } ?? nil
                )
            }
        }

        if safeIndex >= cards.count {
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: Int64(elapsedSeconds * 1000),
                streakCount: correctCount
            )
            phase = .finished
            Task { await endSession() }
        } else {
            phase = .studying
        }
    }

    private func advanceCard(rating: ReviewRating) {
        correctCount += rating.isCorrect ? 1 : 0
        totalReviewed += 1
        let nextIndex = currentIndex + 1

        if nextIndex >= cards.count {
            let elapsed = Int64(Date().timeIntervalSince(sessionStartDate) * 1000)
            result = FlashcardSessionResult(
                totalCards: totalReviewed,
                correctCount: correctCount,
                timeSpentMs: elapsed,
                streakCount: correctCount
            )
            phase = .finished
            VitaAnalytics.capture(event: "flashcard_review_ended", properties: [
                "cards_reviewed": totalReviewed,
                "correct_count": correctCount,
                "seconds_elapsed": Int(elapsed / 1000),
            ])
            Task { await endSession() }

        } else {
            currentIndex = nextIndex
            isFlipped = false
            cardStartDate = Date()
            phase = .studying
            // Ponto de controle: a cada 10 cartas, pausa e mostra o progresso da
            // sessão (nota, distribuição, tempo). Desligável nos ajustes. Rafael 2026-07-17.
            if checkpointEnabled, checkpointInterval > 0, totalReviewed % checkpointInterval == 0 {
                checkpointVisible = true
            }
            Task { await persistSession() }
        }
    }

    // MARK: - API fetch with domain mapping

    /// Busca 1..N decks (deckLimit=1000 acha qualquer deck) e faz MERGE dos cards.
    /// N>1 = "Estudar selecionados" (Cardiologia + Medicina de Família juntos, etc).
    private func fetchDeck(
        deckIds: [String],
        tagFilter: String? = nil,
        quickSession: (cardIds: [String], title: String?)? = nil
    ) async throws -> FlashcardDeck {
        let limit = tagFilter != nil ? 9999 : nil
        async let allTask = api.getFlashcardDecks(tag: tagFilter, cardsLimit: limit, deckLimit: 1000)
        async let dueTask = api.getFlashcardDecks(dueOnly: true, tag: tagFilter, cardsLimit: limit, deckLimit: 1000)
        let (allDecks, dueDecks) = try await (allTask, dueTask)

        // Sessão rápida (issue #188 I1): monta a fila pelos cardIds que o
        // servidor devolveu, preservando a ordem FSRS (mais atrasado primeiro).
        if let quick = quickSession {
            var byId: [String: FlashcardEntry] = [:]
            for deck in allDecks {
                for card in deck.cards { byId[card.id] = card }
            }
            let queue = quick.cardIds.compactMap { byId[$0] }
            guard !queue.isEmpty else { throw URLError(.resourceUnavailable) }
            return FlashcardDeck(
                id: deckIds.first ?? "",
                title: quick.title ?? "Sessão rápida",
                cards: queue.map { $0.toDomain() }
            )
        }

        var mergedCards: [FlashcardEntry] = []
        var firstTitle: String? = nil
        for id in deckIds {
            guard let deck = allDecks.first(where: { $0.id == id }) else { continue }
            if firstTitle == nil { firstTitle = deck.title }
            // Prefer due cards; fall back to all cards in the deck
            let dueDeck = dueDecks.first(where: { $0.id == id })
            let source = (dueDeck.map { !$0.cards.isEmpty } == true) ? dueDeck!.cards : deck.cards
            mergedCards.append(contentsOf: source)
        }
        guard !mergedCards.isEmpty else { throw URLError(.resourceUnavailable) }

        let title = deckIds.count > 1 ? "\(deckIds.count) baralhos" : (firstTitle ?? "Flashcards")
        return FlashcardDeck(
            id: deckIds.first ?? "",
            title: title,
            cards: mergedCards.map { $0.toDomain() }
        )
    }
}
