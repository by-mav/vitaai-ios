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

    // MARK: - Ofensiva (calendario, plantao coberto e marcos)
    case ofensiva

    // MARK: - Faculdade subpages (dashboard + push navigation)
    case faculdadeDisciplinas
    case faculdadeMaterias
    case faculdadeDocumentos
    case faculdadeProvas
    case faculdadeProfessores

    // MARK: - Material folder drill-down
    /// Lista de documentos dentro de uma pasta de materiais (Slides/Provas/etc).
    /// Aberto via DisciplineDetail ao tocar num card de pasta.
    case materialFolderDetail(folderId: String, folderName: String, folderIcon: String)
}

// MARK: - Deterministic visual-capture routing

extension Route {
    /// Stable names used by the Debug-only visual capture harness. Parameterized
    /// routes receive inert fixture identifiers so every destination can render
    /// without mutating a real user record.
    static func captureRoute(named name: String) -> Route? {
        switch name {
        case "notebook-list": return .notebookList
        case "notebook-editor": return .notebookEditor(notebookId: "00000000-0000-0000-0000-000000000001")
        case "mind-map-list": return .mindMapList
        case "mind-map-editor": return .mindMapEditor(id: "capture-fixture")
        case "pdf-viewer": return .pdfViewer(url: "about:blank", title: "Documento")
        case "deck-home": return .flashcardDeck(deckId: "capture-fixture", deckTitle: "Baralho de exemplo")
        case "community-decks": return .flashcardExplore
        case "flashcard-topics": return .flashcardTopics(deckId: "capture-fixture", deckTitle: "Baralho de exemplo")
        case "card-browser": return .cardBrowser(deckId: "capture-fixture", deckTitle: "Baralho de exemplo")
        case "flashcard-session": return .flashcardSession(deckId: "capture-fixture")
        case "flashcard-settings": return .flashcardSettings
        case "flashcard-stats": return .flashcardStats
        case "desempenho": return .desempenho
        case "simulado-builder": return .simuladoHome
        case "simulado-config": return .simuladoConfig
        case "simulado-session": return .simuladoSession(attemptId: "capture-fixture")
        case "simulado-result": return .simuladoResult(attemptId: "capture-fixture")
        case "simulado-review": return .simuladoReview(attemptId: "capture-fixture")
        case "simulado-diagnostics": return .simuladoDiagnostics
        case "canvas-connect": return .canvasConnect
        case "unsupported-connector": return .portalConnect(type: "capture-fixture")
        case "insights": return .insights
        case "trabalhos": return .trabalhos
        case "trabalho-detail": return .trabalhoDetail(id: "capture-fixture")
        case "about": return .about
        case "agenda": return .agenda
        case "appearance": return .appearance
        case "skin-appearance": return .skinAppearance(shopTier: nil)
        case "notifications": return .notifications
        case "connections": return .connections
        case "paywall": return .paywall
        case "atlas-3d": return .atlas3D
        case "osce": return .osce
        case "activity-feed": return .activityFeed
        case "leaderboard": return .leaderboard
        case "course-detail": return .courseDetail(courseId: "capture-fixture", colorIndex: 0)
        case "achievements": return .achievements
        case "ofensiva": return .ofensiva
        case "tool-manager": return .toolManager
        case "profile": return .profile
        case "configuracoes": return .configuracoes
        case "privacy-documents": return .privacyDocuments
        case "privacy-settings": return .privacySettings
        case "export-data": return .exportData
        case "feedback": return .feedback
        case "focus-session": return .focusSession
        case "referral": return .referral
        case "disciplinas-config": return .disciplinasConfig
        case "qbank": return .qbank
        case "qbank-session": return .qbankSession(sessionId: "capture-fixture")
        case "transcricao": return .transcricao
        case "flashcard-builder": return .flashcardHome()
        case "discipline-detail": return .disciplineDetail(disciplineId: "capture-fixture", disciplineName: "Disciplina de exemplo")
        case "faculdade-disciplinas": return .faculdadeDisciplinas
        case "faculdade-materias": return .faculdadeMaterias
        case "faculdade-documentos": return .faculdadeDocumentos
        case "faculdade-provas": return .faculdadeProvas
        case "faculdade-professores": return .faculdadeProfessores
        case "material-folder-detail": return .materialFolderDetail(folderId: "capture-fixture", folderName: "Materiais", folderIcon: "folder")
        default: return nil
        }
    }

    var captureName: String {
        switch self {
        case .notebookList: return "notebook-list"
        case .notebookEditor: return "notebook-editor"
        case .mindMapList: return "mind-map-list"
        case .mindMapEditor: return "mind-map-editor"
        case .pdfViewer: return "pdf-viewer"
        case .flashcardDeck: return "deck-home"
        case .flashcardExplore: return "community-decks"
        case .flashcardTopics: return "flashcard-topics"
        case .cardBrowser: return "card-browser"
        case .flashcardSession: return "flashcard-session"
        case .flashcardSettings: return "flashcard-settings"
        case .flashcardStats: return "flashcard-stats"
        case .desempenho: return "desempenho"
        case .simuladoHome: return "simulado-builder"
        case .simuladoConfig: return "simulado-config"
        case .simuladoSession: return "simulado-session"
        case .simuladoResult: return "simulado-result"
        case .simuladoReview: return "simulado-review"
        case .simuladoDiagnostics: return "simulado-diagnostics"
        case .canvasConnect: return "canvas-connect"
        case .portalConnect: return "unsupported-connector"
        case .insights: return "insights"
        case .trabalhos: return "trabalhos"
        case .trabalhoDetail: return "trabalho-detail"
        case .about: return "about"
        case .agenda: return "agenda"
        case .appearance: return "appearance"
        case .skinAppearance: return "skin-appearance"
        case .notifications: return "notifications"
        case .connections: return "connections"
        case .paywall: return "paywall"
        case .atlas3D: return "atlas-3d"
        case .osce: return "osce"
        case .activityFeed: return "activity-feed"
        case .leaderboard: return "leaderboard"
        case .courseDetail: return "course-detail"
        case .achievements: return "achievements"
        case .ofensiva: return "ofensiva"
        case .toolManager: return "tool-manager"
        case .profile: return "profile"
        case .configuracoes: return "configuracoes"
        case .privacyDocuments: return "privacy-documents"
        case .privacySettings: return "privacy-settings"
        case .exportData: return "export-data"
        case .feedback: return "feedback"
        case .focusSession: return "focus-session"
        case .referral: return "referral"
        case .disciplinasConfig: return "disciplinas-config"
        case .qbank: return "qbank"
        case .qbankSession: return "qbank-session"
        case .transcricao: return "transcricao"
        case .flashcardHome: return "flashcard-builder"
        case .disciplineDetail: return "discipline-detail"
        case .faculdadeDisciplinas: return "faculdade-disciplinas"
        case .faculdadeMaterias: return "faculdade-materias"
        case .faculdadeDocumentos: return "faculdade-documentos"
        case .faculdadeProvas: return "faculdade-provas"
        case .faculdadeProfessores: return "faculdade-professores"
        case .materialFolderDetail: return "material-folder-detail"
        default: return "unsupported"
        }
    }

    var captureAccessibilityIdentifier: String {
        "screen_ready_vita_\(captureName.replacingOccurrences(of: "-", with: "_"))"
    }
}
