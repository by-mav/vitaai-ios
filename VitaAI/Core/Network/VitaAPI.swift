import Foundation

actor VitaAPI {
    let client: HTTPClient // internal so feature extensions in separate files can access (Apr 2026)

    init(client: HTTPClient) {
        self.client = client
    }

    private static func encodeCamelCase<T: Encodable>(_ body: T) throws -> Data {
        try JSONEncoder().encode(body)
    }

    // â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
    // â”‚  WORKING ENDPOINTS â€” backend route.ts exists    â”‚
    // â”‚  Validated by: scripts/lint-api-endpoints.sh    â”‚
    // â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

    // MARK: - Dashboard

    func getDashboard() async throws -> DashboardResponse {
        try await client.get("dashboard")
    }

    // MARK: - Profile

    func getProfile() async throws -> ProfileResponse {
        try await client.get("profile")
    }

    /// PATCH /api/profile â€” atualiza campos do perfil. Server resolve denorm de
    /// university/state/lms a partir de universityId. Spec: openapi.yaml linha 6716.
    func updateProfile(_ body: UpdateProfileRequest) async throws -> ProfileResponse {
        try await client.patch("profile", body: body)
    }

    /// GET /api/user/export â€” LGPD art. 18 V (portabilidade). Retorna JSON com
    /// TUDO que o usuÃ¡rio produziu (perfil, academic, study, qbank, etc).
    /// Spec: openapi.yaml linha 7334. SLA legal: 30 dias.
    func exportUserData() async throws -> Data {
        try await client.downloadRaw("user/export")
    }

    // MARK: - Progress

    func getProgress() async throws -> ProgressResponse {
        try await client.get("progress")
    }

    // MARK: - Activity / Gamification

    func logActivity(action: String, metadata: [String: String]? = nil) async throws -> LogActivityResponse {
        try await client.post("activity", body: LogActivityRequest(action: action, metadata: metadata))
    }

    /// GET /api/leaderboard?scope=user|university&period=weekly|monthly|all
    /// Default scope=user, period=weekly. Spec: openapi.yaml /api/leaderboard.
    func getLeaderboard(
        scope: LeaderboardScope = .user,
        period: String = "weekly",
        limit: Int = 20
    ) async throws -> [LeaderboardEntry] {
        try await client.get("leaderboard", queryItems: [
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Privacy Preferences

    /// GET /api/user/privacy-preferences
    func getPrivacyPreferences() async throws -> PrivacyPreferences {
        try await client.get("user/privacy-preferences")
    }

    /// PATCH /api/user/privacy-preferences (parcial â€” sÃ³ campos enviados)
    func updatePrivacyPreferences(_ body: UpdatePrivacyPreferencesRequest) async throws -> PrivacyPreferences {
        try await client.patch("user/privacy-preferences", body: body)
    }

    // MARK: - Focus Session (Pomodoro)

    /// POST /api/study/focus/session â€” inicia sessÃ£o
    func startFocusSession(plannedDurationMinutes: Int, subjectId: String? = nil) async throws -> StartFocusSession200Response {
        try await client.post(
            "study/focus/session",
            body: StartFocusSessionRequest(plannedDurationMinutes: plannedDurationMinutes, subjectId: subjectId)
        )
    }

    /// POST /api/study/focus/session/{id}/end â€” finaliza, calcula XP
    func endFocusSession(
        id: String,
        completed: Bool,
        leaks: [EndFocusSessionRequestLeaksInner] = []
    ) async throws -> EndFocusSession200Response {
        try await client.post(
            "study/focus/session/\(id)/end",
            body: EndFocusSessionRequest(completed: completed, leaks: leaks.isEmpty ? nil : leaks)
        )
    }

    /// GET /api/study/focus/sessions?limit=20 â€” histÃ³rico
    func getFocusSessions(limit: Int = 20) async throws -> [FocusSession] {
        try await client.get("study/focus/sessions", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Referrals (Rafael 2026-04-26)

    /// GET /api/referrals/me â€” meu cÃ³digo + stats. Lazy init na primeira chamada.
    func getMyReferral() async throws -> MyReferralResponse {
        try await client.get("referrals/me")
    }

    /// POST /api/referrals/redeem â€” vincula user logado a cÃ³digo.
    func redeemReferralCode(code: String, source: RedeemReferralCodeRequest.Source = .universalLink) async throws -> RedeemReferralCode200Response {
        try await client.post(
            "referrals/redeem",
            body: RedeemReferralCodeRequest(code: code, source: source)
        )
    }

    /// POST /api/referrals/customize â€” trocar cÃ³digo (1x apenas).
    func customizeReferralCode(code: String) async throws -> CustomizeReferralCode200Response {
        try await client.post(
            "referrals/customize",
            body: CustomizeReferralCodeRequest(code: code)
        )
    }

    // MARK: - Achievements

    func getAchievements() async throws -> [BadgeWithStatus] {
        try await client.get("achievements")
    }

    // MARK: - Notifications

    func getNotifications() async throws -> [VitaNotification] {
        try await client.get("notifications")
    }

    func markNotificationsRead(ids: [String]? = nil, markAll: Bool = false) async throws {
        struct Body: Encodable { let ids: [String]?; let markAll: Bool? }
        let _: EmptyResponse = try await client.post("notifications", body: Body(ids: ids, markAll: markAll ? true : nil))
    }

    func deleteNotifications(ids: [String]? = nil, deleteAllRead: Bool = false) async throws {
        struct Body: Encodable { let ids: [String]?; let deleteAllRead: Bool? }
        try await client.delete("notifications", body: Body(ids: ids, deleteAllRead: deleteAllRead ? true : nil))
    }

    // MARK: - Universities

    func getUniversities(query: String? = nil) async throws -> UniversitiesResponse {
        var items: [URLQueryItem] = [.init(name: "limit", value: "500")]
        if let query, !query.isEmpty { items.append(.init(name: "q", value: query)) }
        return try await client.get("universities", queryItems: items)
    }

    // MARK: - Server-Driven UI

    func getScreen(screenId: String) async throws -> ScreenResponse {
        try await client.get("screen/\(screenId)")
    }

    // MARK: - Flashcards

    func getMockupFlashcards(dueOnly: Bool = false) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardDecks(subjectId: String? = nil, dueOnly: Bool = false, tag: String? = nil, cardsLimit: Int? = nil, deckLimit: Int? = nil, summary: Bool = false, scope: String? = nil) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        if let tag { items.append(.init(name: "tag", value: tag)) }
        if let cardsLimit { items.append(.init(name: "cardsLimit", value: String(cardsLimit))) }
        if let deckLimit { items.append(.init(name: "deckLimit", value: String(deckLimit))) }
        if summary { items.append(.init(name: "summary", value: "true")) }
        if let scope { items.append(.init(name: "scope", value: scope)) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardTopics(deckId: String) async throws -> [FlashcardTopic] {
        try await client.get("study/flashcards", queryItems: [.init(name: "topics", value: deckId)])
    }

    func getFlashcardStats() async throws -> FlashcardStatsResponse {
        try await client.get("study/flashcards/stats")
    }

    // Anki v2 — config de estudo (retencao, novos/dia, ordem, bury). Rafael 2026-07-10.
    func getFlashcardSettings() async throws -> FlashcardStudySettings {
        try await client.get("study/flashcards/settings")
    }
    @discardableResult
    func updateFlashcardSettings(_ settings: FlashcardStudySettings) async throws -> FlashcardStudySettings {
        try await client.patch("study/flashcards/settings", body: settings)
    }

    func generateFlashcards(discipline: String, count: Int = 30) async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let discipline: String; let count: Int }
        return try await client.post("study/flashcards/generate", body: Body(discipline: discipline, count: count))
    }

    /// Cria 1 flashcard solto. Cliente pode passar `deckTitle` pra criar/usar
    /// um deck com aquele tÃ­tulo (server resolve por nome quando deckId nil).
    /// Usado pelo Atlas 3D (botÃ£o "Estudar 3 cards" no MeshDetailSheet).
    @discardableResult
    func createFlashcard(
        front: String,
        back: String,
        deckTitle: String? = nil,
        subjectId: String? = nil
    ) async throws -> CreateFlashcardResponse {
        // POST /study/flashcards espera camelCase (deckTitle/subjectId). O encoder
        // padrão converte pra snake_case e o zod do server (camelCase-only) DROPA
        // deck_title → o card caía no deck fallback "Meus Flashcards" em vez do
        // baralho escolhido. postRaw preserva as chaves. E2E 2026-07-12, issue #188.
        var payload: [String: Any] = ["front": front, "back": back]
        if let deckTitle { payload["deckTitle"] = deckTitle }
        if let subjectId { payload["subjectId"] = subjectId }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try await client.postRaw("study/flashcards", body: data)
    }

    struct CreateFlashcardResponse: Decodable {
        var id: String?
        var deckId: String?
    }

    /// POST /api/study/flashcards/decks — cria baralho VAZIO, idempotente por
    /// título (server reusa se já existe). Criação manual pelo menu "+" do
    /// builder (issue vitaai-web#188). Encoder converte pra {title, discipline_slug?}.
    @discardableResult
    func createDeck(title: String, disciplineSlug: String? = nil) async throws -> CreateDeckResponse {
        struct Body: Encodable {
            let title: String
            let disciplineSlug: String?
        }
        return try await client.post(
            "study/flashcards/decks",
            body: Body(title: title, disciplineSlug: disciplineSlug)
        )
    }

    struct CreateDeckResponse: Decodable {
        var id: String?
        var title: String?
    }

    @discardableResult
    func generateFlashcardsAutoSeed() async throws -> AutoSeedResponse {
        struct Body: Encodable { let autoSeed: Bool }
        return try await client.post("study/flashcards/generate", body: Body(autoSeed: true))
    }

    struct AutoSeedResponse: Decodable {
        var generated: Int?
        var totalCards: Int?
    }

    func reviewFlashcard(cardId: String, rating: Int, responseTimeMs: Int64) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/review",
            body: FlashcardReviewRequest(rating: rating, responseTimeMs: responseTimeMs)
        )
    }

    func suspendFlashcard(cardId: String) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/suspend",
            body: EmptyBody()
        )
    }

    func buryFlashcard(cardId: String) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/bury",
            body: EmptyBody()
        )
    }

    /// GET /api/study/flashcards/preview â€” due/learning/new + projectedSessionTime
    /// pro Flashcard Builder. Spec: openapi.yaml linha 5132. Added 2026-04-29.
    func previewFlashcards(lens: String? = nil, groupSlug: String? = nil, mode: String = "due") async throws -> FlashcardsPreviewResp {
        var items: [URLQueryItem] = [URLQueryItem(name: "mode", value: mode)]
        if let lens, !lens.isEmpty { items.append(URLQueryItem(name: "lens", value: lens)) }
        if let groupSlug, !groupSlug.isEmpty { items.append(URLQueryItem(name: "groupSlug", value: groupSlug)) }
        return try await client.get("study/flashcards/preview", queryItems: items)
    }

    /// POST /api/study/flashcards/session â€” cria fila SRS (FSRS scheduling) pro
    /// Flashcard Builder. Retorna sessionId (uuid client-side) + cardIds ordenados.
    /// Spec: openapi.yaml linha 5169. Added 2026-04-29.
    func createFlashcardSession(body: FlashcardSessionBody) async throws -> FlashcardSessionResp {
        try await client.post("study/flashcards/session", body: body)
    }

    /// POST /api/study/flashcards/from-question — converte questão errada do
    /// QBank em flashcard determinístico no deck "Questões erradas" (dedup
    /// server-side por sourceQuestionId → 200 existing=true; 422 = questão
    /// discursiva). O encoder manda question_id (snake_case) e o backend
    /// aceita os dois. Issue #188 (I2).
    func createFlashcardFromQuestion(questionId: Int) async throws -> FlashcardFromQuestionResp {
        struct Body: Encodable { let questionId: Int }
        return try await client.post("study/flashcards/from-question", body: Body(questionId: questionId))
    }

    // MARK: - Grades

    func getGrades(subjectId: String? = nil, limit: Int = 20) async throws -> [GradeEntry] {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("grades", queryItems: items)
    }

    // MARK: - AI Coach

    func getConversations() async throws -> [ConversationEntry] {
        try await client.get("ai/coach/conversations")
    }

    func getConversationMessages(conversationId: String) async throws -> ConversationMessagesResponse {
        try await client.get("ai/coach/conversations/\(conversationId)")
    }

    func sendFeedback(conversationId: String, messageId: String, feedback: String) async throws {
        let _: EmptyResponse = try await client.post("ai/coach/feedback", body: FeedbackRequest(conversationId: conversationId, messageId: messageId, feedback: feedback))
    }

    // MARK: - OSCE

    func startOsceCase(specialty: String) async throws -> OsceStartResponse {
        try await client.post("ai/osce", body: OsceStartRequest(specialty: specialty))
    }

    func getOsceSpecialties() async throws -> [String] {
        try await client.get("ai/osce/specialties")
    }

    // MARK: - Study Overview (hero stats + subjects for StudySuite screens)

    func getStudyOverview() async throws -> StudyOverviewResponse {
        try await client.get("study/overview")
    }

    // MARK: - TranscriÃ§Ã£o

    func getTranscricoes() async throws -> [TranscricaoEntry] {
        try await client.get("study/transcricao")
    }

    // MARK: - Studio (Transcription Detail + Outputs)

    func getStudioSourceDetail(id: String) async throws -> StudioSourceDetail {
        try await client.get("studio/sources/\(id)")
    }

    /// Aguarda o pipeline assíncrono de uma fonte chegar a `ready` ou `failed`.
    /// Retorna o último estado no timeout para a UI exibir uma mensagem própria.
    func waitForStudioSourceTerminal(id: String, timeout: TimeInterval = 180) async throws -> StudioSourceDetail {
        let deadline = Date().addingTimeInterval(timeout)
        var detail = try await getStudioSourceDetail(id: id)
        while detail.status != "ready", detail.status != "failed", Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            detail = try await getStudioSourceDetail(id: id)
        }
        return detail
    }

    private struct RenameStudioSourceBody: Encodable { let title: String }

    func renameStudioSource(id: String, title: String) async throws {
        try await client.patch("studio/sources/\(id)", body: RenameStudioSourceBody(title: title))
    }

    /// PATCH /api/studio/sources/:id â€” update folder/favorite/disciplineSlug.
    /// `clearDiscipline`/`clearFolder = true` envia null no JSON pra remover.
    func updateStudioSource(
        id: String,
        disciplineSlug: String? = nil,
        clearDiscipline: Bool = false,
        folderId: String? = nil,
        clearFolder: Bool = false,
        favorite: Bool? = nil
    ) async throws {
        struct Body: Encodable {
            let disciplineSlug: String?
            let folderId: String?
            let favorite: Bool?
            var hasClearDiscipline: Bool
            var hasClearFolder: Bool
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CK.self)
                if hasClearDiscipline {
                    try c.encodeNil(forKey: .disciplineSlug)
                } else if let s = disciplineSlug {
                    try c.encode(s, forKey: .disciplineSlug)
                }
                if hasClearFolder {
                    try c.encodeNil(forKey: .folderId)
                } else if let s = folderId {
                    try c.encode(s, forKey: .folderId)
                }
                if let f = favorite { try c.encode(f, forKey: .favorite) }
            }
            enum CK: String, CodingKey { case disciplineSlug, folderId, favorite }
        }
        let body = Body(
            disciplineSlug: disciplineSlug,
            folderId: folderId,
            favorite: favorite,
            hasClearDiscipline: clearDiscipline,
            hasClearFolder: clearFolder
        )
        try await client.patch("studio/sources/\(id)", body: body)
    }

    // MARK: - Studio Folders (user-created folders)

    struct StudioFolder: Decodable, Identifiable {
        let id: String
        let name: String
        let color: String?
        let icon: String?
    }

    private struct StudioFoldersResponse: Decodable { let folders: [StudioFolder] }
    private struct StudioFolderResponse: Decodable { let folder: StudioFolder }

    func listStudioFolders() async throws -> [StudioFolder] {
        let resp: StudioFoldersResponse = try await client.get("studio/folders")
        return resp.folders
    }

    func createStudioFolder(name: String, color: String? = nil, icon: String? = nil) async throws -> StudioFolder {
        struct Body: Encodable { let name: String; let color: String?; let icon: String? }
        let resp: StudioFolderResponse = try await client.post(
            "studio/folders",
            body: Body(name: name, color: color, icon: icon)
        )
        return resp.folder
    }

    func deleteStudioFolder(id: String) async throws {
        try await client.delete("studio/folders/\(id)")
    }

    func deleteStudioSource(id: String) async throws {
        try await client.delete("studio/sources/\(id)")
    }

    func getStudioOutputs(sourceId: String) async throws -> StudioOutputsResponse {
        try await client.get("studio/outputs", queryItems: [
            URLQueryItem(name: "sourceId", value: sourceId),
        ])
    }

    /// Onda 1 vita-study-mcp: busca um output pelo ID (free-form ou source-based).
    /// Usado quando coach SSE retorna toolArtifact com outputId â€” iOS abre tela nativa.
    func getStudioOutputById(_ id: String) async throws -> StudioOutput {
        try await client.get("studio/outputs/\(id)")
    }

    private struct GenerateBody: Encodable {
        let sourceIds: [String]
        let type: String
    }

    struct StudyPackGenerateRequest: Encodable {
        let sourceIds: [String]
        let title: String?
        let mode: String
        let difficulty: String
        let questionCount: Int
        let flashcardCount: Int
        let includeQuestions: Bool
        let includeFlashcards: Bool
    }

    struct StudyPackGenerateResponse: Decodable {
        struct Counts: Decodable {
            let questions: Int
            let flashcards: Int
        }

        let id: String
        let title: String
        let qbankSessionId: String?
        let flashcardDeckId: String?
        let counts: Counts
    }

    struct DocumentStudySourceResponse: Decodable {
        let documentId: String
        let studioSourceId: String
        let status: String
        let title: String
        let totalChunks: Int?
        let errorMessage: String?
    }

    struct DocumentStudySourceRequest: Encodable {
        let extractedText: String?
    }

    // MARK: - Studio: upload + add-to-deck (PDF/slides -> flashcards, Rafael 2026-07-10)

    struct StudioUploadResponse: Decodable {
        let sourceId: String
        let fileName: String?
    }

    /// POST /api/studio/upload (multipart "file"). Pipeline processa async —
    /// poll getStudioSourceDetail ate status == "ready".
    func uploadStudioSource(fileData: Data, fileName: String, mimeType: String) async throws -> StudioUploadResponse {
        try await client.uploadFileMultipart("studio/upload", fileData: fileData, fileName: fileName, mimeType: mimeType)
    }

    /// Sobe um PDF direto pra disciplina (POST /api/documents/upload, multipart
    /// file+subjectId). Aparece na aba Arquivos. Rafael 2026-07-13.
    func uploadDocument(fileData: Data, fileName: String, subjectId: String) async throws -> VitaDocument {
        try await client.uploadExamMultipart("documents/upload", fileData: fileData, fileName: fileName, mimeType: "application/pdf", subjectId: subjectId)
    }

    // CRUD de documento (VitaDocument) — endpoints ja existem no backend.
    // Renomeia so o title de exibicao (PATCH /api/documents {id,title}).
    func renameDocument(id: String, title: String) async throws {
        struct Body: Encodable { let id: String; let title: String }
        try await client.patch("documents", body: Body(id: id, title: title))
    }
    func deleteDocument(id: String) async throws {
        try await client.delete("documents", queryItems: [URLQueryItem(name: "id", value: id)])
    }
    func toggleDocumentFavorite(id: String) async throws {
        let _: EmptyResponse = try await client.post("documents/\(id)/favorite")
    }

    struct AddToDeckResponse: Decodable {
        let deckId: String
        let addedCount: Int
    }

    /// POST /api/studio/outputs/add-to-deck — cria deck (nome do arquivo) com os cards gerados.
    func addStudioFlashcardsToDeck(cards: [StudioFlashcard], deckTitle: String?) async throws -> AddToDeckResponse {
        struct CardBody: Encodable { let front: String; let back: String }
        struct Body: Encodable {
            let deckId: String?
            let deckTitle: String?
            let flashcards: [CardBody]
        }
        return try await client.post("studio/outputs/add-to-deck", body: Body(
            deckId: nil,
            deckTitle: deckTitle,
            flashcards: cards.map { CardBody(front: $0.front, back: $0.back) }
        ))
    }

    func generateStudioOutput(sourceId: String, outputType: String) async throws -> StudioOutput {
        // Backend expects sourceIds array and "type" field at POST /api/studio/generate
        let backendType = Self.mapOutputType(outputType)
        let result: StudioOutput = try await client.post("studio/generate", body: GenerateBody(
            sourceIds: [sourceId],
            type: backendType
        ))
        return result
    }

    func generateStudyPack(
        sourceIds: [String],
        title: String? = nil,
        mode: String = "practice",
        difficulty: String = "mixed",
        questionCount: Int = 10,
        flashcardCount: Int = 15,
        includeQuestions: Bool = true,
        includeFlashcards: Bool = true
    ) async throws -> StudyPackGenerateResponse {
        try await client.post(
            "study/packs/generate",
            body: StudyPackGenerateRequest(
                sourceIds: sourceIds,
                title: title,
                mode: mode,
                difficulty: difficulty,
                questionCount: questionCount,
                flashcardCount: flashcardCount,
                includeQuestions: includeQuestions,
                includeFlashcards: includeFlashcards
            ),
            timeoutInterval: 180
        )
    }

    func ensureDocumentStudySource(
        documentId: String,
        extractedText: String? = nil
    ) async throws -> DocumentStudySourceResponse {
        try await client.post(
            "documents/\(documentId)/study-source",
            body: DocumentStudySourceRequest(extractedText: extractedText),
            timeoutInterval: 180
        )
    }

    /// Map iOS output type names to backend enum values
    private static func mapOutputType(_ type: String) -> String {
        switch type {
        case "questions": return "quiz"
        case "concepts": return "summary" // concepts extracted as summary variant
        default: return type // summary, flashcards, mindmap pass through
        }
    }

    // MARK: - MindMaps

    func getMindMaps(limit: Int = 50) async throws -> [RemoteMindMap] {
        try await client.get("study/mindmaps", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Notes

    func getNotes(subjectId: String? = nil, limit: Int = 50) async throws -> [RemoteNote] {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("notes", queryItems: items)
    }

    func createNote(title: String, content: String, subjectId: String? = nil) async throws -> RemoteNote {
        try await client.post("notes", body: CreateNoteRequest(title: title, content: content, subjectId: subjectId))
    }

    func updateNote(id: String, title: String? = nil, content: String? = nil, subjectId: String? = nil) async throws -> RemoteNote {
        try await client.patch("notes", body: UpdateNoteRequest(id: id, title: title, content: content, subjectId: subjectId))
    }

    func deleteNote(id: String) async throws {
        try await client.delete("notes", queryItems: [URLQueryItem(name: "id", value: id)])
    }

    // MARK: - Simulado

    func listSimulados() async throws -> SimuladoListResponse {
        try await client.get("simulados")
    }

    /// GET /api/simulados/{id} — 1 attempt com suas questoes. Evita baixar a
    /// lista INTEIRA so pra achar um (N+1 que travava a abertura da prova).
    /// #189 Rafael 2026-07-12.
    func getSimulado(id: String) async throws -> SimuladoAttemptEntry {
        try await client.get("simulados/\(id)")
    }

    /// BFF aggregator per-screen pra Simulado Home.
    /// 1 RTT em vez de listSimulados + getSimuladoDiagnostics separado.
    /// PadrÃ£o 2026 (memory: feedback_aggregator_per_screen_2026.md).
    /// COMMENTED: SimuladoScreenResponse type missing â€” outro agente reativa.
    // func getSimuladoScreen() async throws -> SimuladoScreenResponse {
    //     try await client.get("simulados/screen")
    // }

    func answerSimuladoQuestion(attemptId: String, body: AnswerSimuladoRequest) async throws -> AnswerSimuladoResponse {
        try await client.post("simulados/\(attemptId)/answer", body: body)
    }

    func finishSimulado(attemptId: String, timeTakenMs: Int64) async throws -> FinishSimuladoResponse {
        struct FinishBody: Encodable { let timeTakenMs: Int64 }
        return try await client.post("simulados/\(attemptId)/finish", body: FinishBody(timeTakenMs: timeTakenMs))
    }

    func explainQuestion(attemptId: String, questionId: String) async throws -> ExplainResponse {
        struct ExplainRequest: Encodable { let questionId: String }
        return try await client.post(
            "simulados/\(attemptId)/explain",
            body: ExplainRequest(questionId: questionId)
        )
    }

    func deleteSimulado(attemptId: String) async throws {
        try await client.delete("simulados/\(attemptId)")
    }

    func archiveSimulado(attemptId: String) async throws {
        struct ArchiveBody: Encodable { let status: String }
        let _: EmptyResponse = try await client.patch(
            "simulados/\(attemptId)",
            body: ArchiveBody(status: "archived")
        )
    }

    func getSimuladoDiagnostics(subject: String = "all", period: String = "30d") async throws -> SimuladoDiagnosticsResponse {
        try await client.get("simulados/diagnostics", queryItems: [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "period", value: period),
        ])
    }

    /// POST /api/simulados/preview â€” count + estimatedMinutes pro Simulado Builder.
    /// Espelha previewQBankPool mas com questionCount + timed + timeLimitMinutes
    /// pra tela de Simulado calcular tempo correto. Spec: openapi.yaml linha 6639.
    /// Added 2026-04-29.
    func previewSimuladoPool(body: SimuladoPreviewBody) async throws -> SimuladoPreviewResp {
        try await client.post("simulados/preview", body: body)
    }

    // MARK: - QBank

    /// Fetches QBank progress. When `disciplineSlugs` is non-empty, the response is
    /// scoped to the enrolled subset (Hero "X/Y questÃµes das suas matÃ©rias") instead of
    /// the global catalog.
    func getQBankProgress(disciplineSlugs: [String] = []) async throws -> QBankProgressResponse {
        if disciplineSlugs.isEmpty {
            return try await client.get("qbank/progress")
        }
        let items = disciplineSlugs.map { URLQueryItem(name: "disciplineSlugs[]", value: $0) }
        return try await client.get("qbank/progress", queryItems: items)
    }

    func getQBankFilters(lens: String? = nil, stage: String? = nil) async throws -> QBankFiltersResponse {
        var items: [URLQueryItem] = []
        if let lens, !lens.isEmpty {
            items.append(URLQueryItem(name: "lens", value: lens))
        }
        if let stage, !stage.isEmpty {
            items.append(URLQueryItem(name: "stage", value: stage))
        }
        if items.isEmpty {
            return try await client.get("qbank/filters")
        }
        return try await client.get("qbank/filters", queryItems: items)
    }

    /// POST /api/qbank/preview â€” count dinÃ¢mico ANTES de criar sessÃ£o.
    /// Usado pelo builder das telas Estudos com debounce 300ms client-side.
    func previewQBankPool(body: QBankPreviewBody) async throws -> QBankPreviewResp {
        try await client.postRaw("qbank/preview", body: Self.encodeCamelCase(body))
    }

    func createQBankSession(request: QBankCreateSessionRequest) async throws -> QBankSession {
        try await client.postRaw("qbank/sessions", body: Self.encodeCamelCase(request))
    }

    func getQBankQuestion(id: Int) async throws -> QBankQuestionDetail {
        try await client.get("qbank/questions/\(id)")
    }

    func answerQBankQuestion(id: Int, request: QBankAnswerRequest) async throws -> QBankAnswerResponse {
        try await client.postRaw("qbank/questions/\(id)/answer", body: Self.encodeCamelCase(request))
    }

    func getQBankSessions(limit: Int = 5) async throws -> QBankSessionsResponse {
        try await client.get("qbank/sessions", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func getQBankSessionDetail(id: String) async throws -> QBankSession {
        try await client.get("qbank/sessions/\(id)")
    }

    func finishQBankSession(id: String, correctCount: Int, totalAnswered: Int) async throws -> QBankFinishSessionResponse {
        let request = QBankFinishSessionRequest(
            correctCount: correctCount,
            totalAnswered: totalAnswered
        )
        return try await client.postRaw("qbank/sessions/\(id)/finish", body: Self.encodeCamelCase(request))
    }

    func getQBankQuestions(
        page: Int = 1,
        limit: Int = 1,
        institutionIds: [Int] = [],
        years: [Int] = [],
        difficulties: [String] = [],
        topicIds: [Int] = [],
        status: String? = nil,
        onlyResidence: Bool = false
    ) async throws -> QBankQuestionsResponse {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        // Backend expects array-style repeated params (name[]=a&name[]=b), not CSV.
        for id in institutionIds {
            items.append(URLQueryItem(name: "institutionIds[]", value: String(id)))
        }
        for year in years {
            items.append(URLQueryItem(name: "years[]", value: String(year)))
        }
        for d in difficulties {
            items.append(URLQueryItem(name: "difficulties[]", value: d))
        }
        for id in topicIds {
            items.append(URLQueryItem(name: "topicIds[]", value: String(id)))
        }
        if let status {
            items.append(URLQueryItem(name: "status", value: status))
        }
        if onlyResidence {
            items.append(URLQueryItem(name: "onlyResidence", value: "true"))
        }
        return try await client.get("qbank/questions", queryItems: items)
    }

    // MARK: - Canvas connector sync

    func getPortalStatus() async throws -> PortalStatusResponse {
        try await client.get("portal/status")
    }

    /// User-triggered Canvas re-sync (pull-to-refresh, "Sincronizar agora").
    /// Backend re-reads Canvas through the stored PAT, ingests the canonical
    /// academic model, and advances lastSyncAt/lastPingAt on success. Empty
    /// body re-syncs all active Canvas connections; pass connectionIds to scope it.
    @discardableResult
    func triggerPortalSyncNow(connectionIds: [String]? = nil) async throws -> EmptyResponse {
        struct Body: Encodable { let connectionIds: [String]? }
        return try await client.post("portal/sync-now", body: Body(connectionIds: connectionIds))
    }

    // MARK: - Push Notifications

    func registerPushToken(token: String) async throws {
        let _: EmptyResponse = try await client.post("push/register", body: PushTokenRequest(token: token, platform: "ios"))
    }

    func unregisterPushToken(token: String) async throws {
        try await client.delete("push/unregister")
    }

    // MARK: - Onboarding

    func postOnboarding(_ body: OnboardingPostRequest) async throws {
        let _: EmptyResponse = try await client.post("onboarding", body: body)
    }

    /// Onda 5b â€” onboarding v2 (Rafael 2026-04-27).
    /// Backend deriva journeyType + journeyConfig + contentOrganizationMode.
    func postOnboardingV2(_ body: OnboardingV2Request) async throws -> OnboardingV2Response {
        try await client.post("onboarding/v2", body: body)
    }

    /// Onda 5b Slice 4 â€” lista canonica CNRM/MEC de especialidades medicas.
    /// 22 acesso direto + 41 com pre-requisito. Cacheable (1h SWR 24h backend-side).
    func getMedicalSpecialties() async throws -> MedicalSpecialtiesResponse {
        try await client.get("medical-specialties")
    }

    func requestUniversity(name: String, city: String, state: String) async throws {
        let body = UniversityRequestBody(name: name, city: city, state: state)
        let _: EmptyResponse = try await client.post("universities/request", body: body)
    }

    // MARK: - Study Plan

    func getStudyPlan() async throws -> StudyPlanResponse {
        try await client.get("estudos/plan")
    }

    // MARK: - Trabalhos (assignments)

    func getTrabalhos() async throws -> TrabalhosResponse {
        try await client.get("study/trabalhos")
    }

    // MARK: - Documents (PDFs synced from portal + manual uploads)

    func getDocuments(subjectId: String? = nil) async throws -> [VitaDocument] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("documents", queryItems: items.isEmpty ? nil : items)
    }

    func dismissTrabalho(id: String) async throws {
        let _: EmptyResponse = try await client.patch("study/trabalhos/\(id)/dismiss")
    }

    // MARK: - Trabalho Generate & Submit

    struct TrabalhoGenerateRequest: Encodable {
        var prompt: String?
        var existingContent: String?
    }

    struct TrabalhoGenerateResponse: Decodable {
        let content: String
        let wordCount: Int
    }

    func generateTrabalho(id: String, prompt: String?, existingContent: String?) async throws -> TrabalhoGenerateResponse {
        return try await client.post(
            "study/trabalhos/\(id)/generate",
            body: TrabalhoGenerateRequest(prompt: prompt, existingContent: existingContent)
        )
    }

    struct TrabalhoSubmitRequest: Encodable {
        var content: String?
        var contentHtml: String?
    }

    struct TrabalhoSubmitResponse: Decodable {
        let success: Bool
        let canvasSubmissionId: Int?
        let submittedAt: String?
    }

    func submitTrabalho(id: String, content: String) async throws -> TrabalhoSubmitResponse {
        return try await client.post(
            "study/trabalhos/\(id)/submit",
            body: TrabalhoSubmitRequest(content: content)
        )
    }

    // â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
    // â”‚  NO BACKEND YET â€” endpoints below have NO route.ts on server   â”‚
    // â”‚  Features calling these get 404 â†’ catch â†’ empty/error state    â”‚
    // â”‚  DO NOT add new functions here. Build the backend route first.  â”‚
    // â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜

    // MARK: - Canvas PAT connector

    func getCanvasStatus() async throws -> CanvasStatusResponse {
        try await client.get("portal/status")
    }

    // Pivot 2026-05-07: webview/scrape extinto. Conectar Canvas via
    // Personal Access Token student-side. Backend valida token + persiste
    // em portal_connections.sessionCookie (encrypted) com portalType='canvas_api'.
    // Spec: agent-brain/decisions/2026-05-07_vita-pivot-llm-extract-to-api-token-and-manual.md

    /// POST /api/connectors/canvas/token â€” valida + persiste Personal Access Token.
    func connectCanvas(accessToken: String, instanceUrl: String) async throws -> CanvasConnectResponse {
        struct Body: Encodable {
            let token: String
            let baseUrl: String
        }
        struct Response: Decodable {
            let connectionId: String
            let canvasUser: CanvasUserPayload?
            let instanceUrl: String?
        }
        struct CanvasUserPayload: Decodable {
            let id: Int
            let name: String
            let email: String?
        }
        do {
            let res: Response = try await client.post(
                "connectors/canvas/token",
                body: Body(token: accessToken, baseUrl: instanceUrl)
            )
            return CanvasConnectResponse(success: true, connectionId: res.connectionId, updated: false, error: nil)
        } catch let APIError.serverError(code) {
            return CanvasConnectResponse(success: false, error: "Falha ao conectar Canvas (HTTP \(code))")
        }
    }

    /// POST /api/connectors/moodle/token â€” valida + persiste Moodle Web Service Token.
    func connectMoodle(accessToken: String, instanceUrl: String) async throws -> CanvasConnectResponse {
        struct Body: Encodable {
            let token: String
            let baseUrl: String
        }
        struct Response: Decodable {
            let connectionId: String
        }
        do {
            let res: Response = try await client.post(
                "connectors/moodle/token",
                body: Body(token: accessToken, baseUrl: instanceUrl)
            )
            return CanvasConnectResponse(success: true, connectionId: res.connectionId, updated: false, error: nil)
        } catch let APIError.serverError(code) {
            return CanvasConnectResponse(success: false, error: "Falha ao conectar Moodle (HTTP \(code))")
        }
    }

    /// POST /api/connectors/canvas/sync â€” puxa cursos+assignments via API oficial.
    func syncCanvas(connectionId: String) async throws -> CanvasSyncResponse {
        struct Body: Encodable { let connectionId: String }
        struct Response: Decodable {
            let ok: Bool
            let subjectsCreated: Int
            let subjectsUpdated: Int
            let evaluationsCreated: Int
            let evaluationsUpdated: Int
        }
        let res: Response = try await client.post(
            "connectors/canvas/sync",
            body: Body(connectionId: connectionId)
        )
        return CanvasSyncResponse(
            courses: res.subjectsCreated + res.subjectsUpdated,
            files: 0,
            assignments: res.evaluationsCreated + res.evaluationsUpdated,
            calendarEvents: 0,
            pdfExtracted: 0,
            studyEvents: 0,
            errors: res.ok ? [] : ["sync_failed"]
        )
    }

    /// Compat with callers that sync the active Canvas connection without
    /// already knowing its id.
    func syncCanvas() async throws -> CanvasSyncResponse {
        struct Body: Encodable {}
        struct Response: Decodable {
            let ok: Bool
            let subjectsCreated: Int
            let subjectsUpdated: Int
            let evaluationsCreated: Int
            let evaluationsUpdated: Int
            let files: Int?
            let calendarEvents: Int?
        }
        let res: Response = try await client.post("connectors/canvas/sync", body: Body())
        return CanvasSyncResponse(
            courses: res.subjectsCreated + res.subjectsUpdated,
            files: res.files ?? 0,
            assignments: res.evaluationsCreated + res.evaluationsUpdated,
            calendarEvents: res.calendarEvents ?? 0,
            pdfExtracted: 0,
            studyEvents: 0,
            errors: res.ok ? [] : ["sync_failed"]
        )
    }

    func disconnectCanvas() async throws {
        // TODO: rota /api/connectors/canvas/disconnect (criar Fase 2.1)
        try await client.delete("portal/disconnect?portalType=canvas")
    }

    func getCourses() async throws -> CoursesResponse {
        return CoursesResponse()
    }

    func getFiles(courseId: String? = nil) async throws -> FilesResponse {
        return FilesResponse()
    }

    func getAssignments(courseId: String? = nil) async throws -> AssignmentsResponse {
        return AssignmentsResponse()
    }

    func downloadFileData(fileId: String) async throws -> Data {
        throw APIError.serverError(404)
    }

    // MARK: - Subjects (NO BACKEND: subjects, subjects/manual)

    func getSubjects(status: String? = nil) async throws -> SubjectsResponse {
        var items: [URLQueryItem] = []
        if let status { items.append(.init(name: "status", value: status)) }
        return try await client.get("subjects", queryItems: items.isEmpty ? nil : items)
    }

    func getSubjectsOverview() async throws -> SubjectsOverviewResponse {
        return try await client.get("subjects/overview")
    }

    func createManualSubject(name: String, difficulty: String? = nil) async throws -> AcademicSubject {
        struct Body: Encodable { let name: String; let difficulty: String? }
        return try await client.post("subjects/manual", body: Body(name: name, difficulty: difficulty))
    }

    func updateSubjectDifficulty(id: String, difficulty: String?) async throws -> AcademicSubject {
        struct Body: Encodable { let difficulty: String? }
        return try await client.patch("subjects/\(id)", body: Body(difficulty: difficulty))
    }

    /// Set or clear the user-ownable display name for a subject. Empty/nil
    /// resets to the portal-canonical name (UI falls back to canonicalName ?? name).
    /// See vitaai-web#170 phase A.
    func renameSubject(id: String, displayName: String?) async throws -> AcademicSubject {
        struct Body: Encodable { let displayName: String? }
        return try await client.patch("subjects/\(id)", body: Body(displayName: displayName))
    }

    /// Renomeia o professor da disciplina (PATCH subjects/{id} {professor}).
    /// Vazio/nil limpa. Rafael 2026-07-13.
    func renameProfessor(id: String, professor: String?) async throws -> AcademicSubject {
        struct Body: Encodable { let professor: String? }
        return try await client.patch("subjects/\(id)", body: Body(professor: professor))
    }

    /// Remover (soft-delete) uma disciplina do aluno. O backend seta deletedAt
    /// e a disciplina some do GET /api/subjects. DELETE /api/subjects/{id}.
    func deleteSubject(id: String) async throws {
        try await client.delete("subjects/\(id)")
    }

    // MARK: - Grades

    func getGradesCurrent() async throws -> GradesCurrentResponse {
        try await client.get("grades/current")
    }

    func getAgenda(from: String? = nil, to: String? = nil) async throws -> AgendaResponse {
        var path = "agenda"
        var params: [String] = []
        if let from { params.append("from=\(from)") }
        if let to { params.append("to=\(to)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await client.get(path)
    }

    // MARK: - Google Calendar (NO BACKEND: google/calendar/*)

    func getGoogleCalendarStatus() async throws -> GoogleCalendarStatusResponse {
        try await client.get("google/calendar/status")
    }

    func syncGoogleCalendar() async throws -> GoogleCalendarSyncResponse {
        try await client.post("google/calendar/sync")
    }

    func disconnectGoogleCalendar() async throws {
        try await client.delete("google/calendar/connect")
    }

    // MARK: - Google Drive (NO BACKEND: google/drive/*)

    func getGoogleDriveStatus() async throws -> GoogleDriveStatusResponse {
        try await client.get("google/drive/status")
    }

    func syncGoogleDrive() async throws -> GoogleDriveSyncResponse {
        try await client.post("google/drive/sync")
    }

    func disconnectGoogleDrive() async throws {
        try await client.delete("google/drive/connect")
    }

    // MARK: - Billing (NO BACKEND: billing/status, billing/checkout, billing/verify/apple)

    func getBillingStatus() async throws -> BillingStatus {
        try await client.get("billing/status")
    }

    func getCheckoutUrl(plan: String = "pro") async throws -> CheckoutResponse {
        try await client.post("billing/checkout", body: CheckoutRequest(plan: plan))
    }

    func verifyAppleReceipt(transactionId: String, productId: String) async throws -> VerifyAppleReceiptResponse {
        try await client.post(
            "billing/verify/apple",
            body: VerifyAppleReceiptRequest(
                transactionId: transactionId,
                productId: productId,
                bundleId: "com.bymav.vitaai"
            )
        )
    }

    // MARK: - Crowd / Provas (NO BACKEND: crowd/*)

    func getCrowdProfessors() async throws -> [CrowdProfessor] {
        try await client.get("crowd/professors")
    }

    func getCrowdExams() async throws -> [CrowdExamEntry] {
        try await client.get("crowd/exams")
    }

    func getCrowdExamDetail(_ examId: String) async throws -> CrowdExamDetail {
        try await client.get("crowd/exams/\(examId)")
    }

    func getCrowdUploads() async throws -> [CrowdUploadRecord] {
        try await client.get("crowd/upload")
    }

    func uploadExamImages(_ images: [(Data, String, String)]) async throws -> CrowdUploadResponse {
        try await client.uploadMultipart("crowd/upload", images: images)
    }

    func getExams(upcoming: Bool = false) async throws -> ExamsResponse {
        var items: [URLQueryItem] = []
        if upcoming { items.append(.init(name: "upcoming", value: "true")) }
        return try await client.get("exams", queryItems: items.isEmpty ? nil : items)
    }

    // MARK: - Professor Intelligence

    func getProfessorProfile(subjectId: String) async throws -> ProfessorProfileResponse {
        try await client.get("subjects/\(subjectId)/professor-profile")
    }

    func analyzeExam(fileData: Data, fileName: String, mimeType: String, subjectId: String) async throws -> ExamAnalyzeResponse {
        try await client.uploadExamMultipart(
            "exams/analyze",
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            subjectId: subjectId
        )
    }

    func getMockupFlashcardsRecommended() async throws -> [FlashcardRecommended] {
        try await client.get("study/flashcards/recommended")
    }

    func generateSimulado(_ body: GenerateSimuladoRequest) async throws -> GenerateSimuladoResponse {
        try await client.post("simulados/generate", body: body)
    }

    func fetchAppConfig() async throws -> AppConfigResponse {
        try await client.get("config/app")
    }

    func getGamificationStats() async throws -> GamificationStatsResponse {
        try await client.get("activity/stats")
    }

    func getActivityFeed(limit: Int = 50, offset: Int = 0) async throws -> [ActivityFeedItem] {
        try await client.get("activity", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
    }

    func getNotificationPreferences() async throws -> NotificationPreferencesResponse {
        try await client.get("notifications/preferences")
    }

    // MARK: - Unified Integrations

    func getIntegrations() async throws -> IntegrationsResponse {
        try await client.get("integrations")
    }

    func startIntegrationOAuth(_ provider: String) async throws -> IntegrationOAuthResponse {
        try await client.get("integrations/\(provider)")
    }

    func disconnectIntegration(_ provider: String) async throws {
        try await client.delete("integrations/\(provider)")
    }


    // MARK: - WhatsApp

    func getWhatsAppStatus() async throws -> WhatsAppStatusResponse {
        try await client.get("whatsapp/status")
    }

    func linkWhatsApp(phone: String) async throws {
        let _: EmptyResponse = try await client.post("whatsapp/link", body: WhatsAppLinkRequest(phone: phone))
    }

    func verifyWhatsApp(code: String) async throws -> WhatsAppVerifyResponse {
        try await client.post("whatsapp/verify", body: WhatsAppVerifyRequest(code: code))
    }

    func unlinkWhatsApp() async throws {
        let _: EmptyResponse = try await client.post("whatsapp/unlink", body: EmptyBody())
    }

    func syncPushPreferences(_ prefs: PushPreferencesRequest) async throws {
        let _: EmptyResponse = try await client.post("push/preferences", body: prefs)
    }

    // MARK: - Account Deletion (LGPD / App Store Â§5.1.1(v))

    func deleteUserData() async throws -> DeleteUserDataResponse {
        try await client.request(
            "DELETE",
            path: "user/delete-data",
            body: DeleteUserDataRequest(confirmation: "DELETE")
        )
    }
}

// MARK: - Request Types

struct OnboardingPostRequest: Encodable {
    let moment: String
    let studyGoal: String
    var year: Int?
    var selectedSubjects: [String]?
    var subjectDifficulties: [String: String]?
}

// MARK: - Onboarding v2 (Onda 5b â€” Rafael 2026-04-27)
// SOT do payload: vitaai-web/src/lib/validators.ts onboardingV2Schema.

struct OnboardingV2Request: Encodable {
    /// FACULDADE | ENAMED | RESIDENCIA | REVALIDA
    let goal: String
    /// yes | graduated | skip â€” obrigatorio se goal != REVALIDA
    var inFaculdade: String?
    /// 1..12 â€” obrigatorio se inFaculdade=yes
    var semester: Int?
    var university: String?
    var universityId: String?
    var universityLms: String?
    var selectedSubjects: [String]?
    var studyGoal: String?
    /// slug de medical_specialties â€” so se goal=RESIDENCIA
    var targetSpecialty: String?
    var targetInstitutions: [String]?
    /// PRIMEIRA | SEGUNDA â€” so se goal=REVALIDA
    var currentStage: String?
    var focusAreas: [String]?
}

struct OnboardingV2Response: Decodable {
    let ok: Bool
    let profile: OnboardingV2Profile?
    let derived: OnboardingV2Derived?
}

struct OnboardingV2Profile: Decodable {
    let id: String?
    let journeyType: String?
    let moment: String?
    let semester: Int?
    let onboardingCompleted: Bool?
}

struct OnboardingV2Derived: Decodable {
    let journeyType: String?
    let contentOrganizationMode: String?
    let moment: String?
}

// MARK: - Medical Specialties (Onda 5b Slice 4)
// Tabela canonica CNRM/MEC. SOT: vita-web migration 0080_medical_specialties.sql.

struct MedicalSpecialty: Identifiable, Decodable, Hashable {
    let slug: String
    let name: String
    let type: String  // "direct_access" | "with_prerequisite"
    let prerequisiteSlug: String?
    let displayOrder: Int
    let cnrmCode: String?

    var id: String { slug }
}

struct MedicalSpecialtiesResponse: Decodable {
    let directAccess: [MedicalSpecialty]
    let withPrerequisite: [MedicalSpecialty]
    let total: Int
}

struct UniversityRequestBody: Encodable {
    let name: String
    let city: String
    let state: String
}

struct WhatsAppLinkRequest: Encodable {
    let phone: String
}

struct WhatsAppVerifyRequest: Encodable {
    let code: String
}

struct WhatsAppStatusResponse: Decodable {
    let phone: String?
    let verified: Bool
}

struct WhatsAppVerifyResponse: Decodable {
    let ok: Bool
    let verified: Bool
}

struct EmptyBody: Encodable {}

// MARK: - Account Deletion types

private struct DeleteUserDataRequest: Encodable {
    let confirmation: String
}

struct DeleteUserDataResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
}
