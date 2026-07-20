import Foundation

enum Route: Hashable {
    case login
    case onboarding
    case home
    case estudos
    case faculdade
    case progresso
    case trabalhos
    case trabalhoDetail(id: String)
    case agenda
    case insights
    case profile
    case portalConnect(type: String, defaultUrl: String? = nil)

    case canvasConnect
    case vitaChat(prompt: String? = nil)
    case notebookList
    case notebookEditor(notebookId: String)
    case mindMapList
    case mindMapEditor(id: String)
    case flashcardHome(subjectId: String? = nil)
    /// Tela CENTRAL do baralho (Rafael 2026-07-19) — todo deck abre aqui, nunca direto nos cards.
    /// Tela central do baralho. `librarySlug` = disciplina da Biblioteca (curada)
    /// — habilita download offline e lê os cards do pack/bundle em vez do servidor.
    case flashcardDeck(deckId: String, deckTitle: String? = nil, librarySlug: String? = nil, libraryTotalCards: Int = 0)
    /// Explorar decks pré-fabricados/comunidade (gaveta do "+").
    case flashcardExplore
    case flashcardTopics(deckId: String, deckTitle: String)
    case cardBrowser(deckId: String, deckTitle: String, subjectId: String? = nil, disciplineSlug: String? = nil)
    case flashcardSession(deckId: String, tagFilter: String? = nil, sessionId: String? = nil)
    case flashcardSettings
    case flashcardStats
    case desempenho
    case pdfViewer(url: String, title: String? = nil, documentId: String? = nil, studioSourceId: String? = nil)

    // MARK: - Atlas 3D
    case atlas3D

    // MARK: - OSCE
    case osce

    // MARK: - Simulado
    case simuladoHome
    case simuladoConfig
    case simuladoSession(attemptId: String)
    case simuladoResult(attemptId: String)
    case simuladoReview(attemptId: String)
    case simuladoDiagnostics

    // MARK: - Settings sub-screens
    case about
    case appearance
    case skinAppearance(shopTier: Int?)   // guarda-roupa. nil = completo (Vita); 0-4 = loja da fase (prédio)
    case notifications
    case connections
    case configuracoes
    case disciplinasConfig
    case privacyDocuments
    case privacySettings
    case exportData
    case feedback
    case focusSession
    case referral

    // MARK: - Activity / Gamification
    case activityFeed
    case leaderboard

    // MARK: - Billing
    case paywall

    // MARK: - Course Detail
    case courseDetail(courseId: String, colorIndex: Int)

    // MARK: - QBank (Question Bank)
    case qbank
    case qbankSession(sessionId: String, mode: String? = nil)

    // MARK: - Tool Manager
    case toolManager

    // MARK: - Discipline Detail
    case disciplineDetail(disciplineId: String, disciplineName: String)

    // MARK: - Transcrição (audio recording + AI transcription)
    case transcricao

    // MARK: - Achievements (full badges page — BYM-1135)
    case achievements

    // MARK: - Faculdade subpages (dashboard + push navigation)
    case faculdadeDisciplinas
    case faculdadeMaterias
    case faculdadeDocumentos
    case faculdadeProfessores

    // MARK: - Material folder drill-down
    /// Lista de documentos dentro de uma pasta de materiais (Slides/Provas/etc).
    /// Aberto via DisciplineDetail ao tocar num card de pasta.
    case materialFolderDetail(folderId: String, folderName: String, folderIcon: String)
}
