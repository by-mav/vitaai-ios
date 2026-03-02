import Foundation

// MARK: - EstudosTab

enum EstudosTab: Int, CaseIterable {
    case disciplinas = 0
    case notebooks   = 1
    case flashcards  = 2
    case pdfs        = 3

    var title: String {
        switch self {
        case .disciplinas: return "Disciplinas"
        case .notebooks:   return "Notebooks"
        case .flashcards:  return "Flashcards"
        case .pdfs:        return "PDFs"
        }
    }
}

// MARK: - FlashcardDeckDisplayEntry
// Mirrors Android FlashcardDeck: id, name, cardCount, masteredCount, courseName

struct FlashcardDeckDisplayEntry: Identifiable {
    var id: String
    var name: String
    var cardCount: Int
    var masteredCount: Int
    var courseName: String

    var progress: Double {
        guard cardCount > 0 else { return 0 }
        return Double(masteredCount) / Double(cardCount)
    }
}

// MARK: - EstudosViewModel

@MainActor
@Observable
final class EstudosViewModel {
    private let api: VitaAPI

    // Tabs
    var selectedTab: EstudosTab = .disciplinas

    // Canvas connection state
    var canvasConnected: Bool = true

    // Disciplinas
    var courses: [Course] = []

    // Flashcards tab — display entries (include progress)
    var flashcardDisplayDecks: [FlashcardDeckDisplayEntry] = []

    // PDFs
    var files: [CanvasFile] = []
    var downloadingFileId: String? = nil
    var downloadedFilePaths: [String: URL] = [:] // fileId -> local URL

    // Stats (retained from iOS-specific view)
    var flashcardsDue: Int = 0
    var streakDays: Int = 0
    var avgAccuracy: Double = 0

    // Simulados (iOS-specific)
    var simulados: [SimuladoEntry] = []

    // Documents (iOS-specific — PDF read progress)
    var documents: [DocumentEntry] = []

    // Notes (iOS-specific)
    var notes: [NoteEntry] = []

    // State
    var isLoading = true
    var error: String? = nil

    // Selected course filter for PDFs tab
    var selectedCourseId: String? = nil

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil
        loadMock()
        isLoading = false

        do {
            async let progressTask  = api.getProgress()
            async let coursesTask   = api.getCourses()
            async let filesTask     = api.getFiles(courseId: selectedCourseId)
            async let decksTask     = api.getFlashcardDecks(dueOnly: false)

            let (progressResp, coursesResp, filesResp, rawDecks) =
                try await (progressTask, coursesTask, filesTask, decksTask)

            flashcardsDue = progressResp.flashcardsDue
            streakDays    = progressResp.streakDays
            avgAccuracy   = progressResp.avgAccuracy

            canvasConnected = coursesResp.connected

            if !coursesResp.courses.isEmpty {
                courses = coursesResp.courses
            }

            if !filesResp.files.isEmpty {
                files = filesResp.files
            }

            if !rawDecks.isEmpty {
                flashcardDisplayDecks = rawDecks.map { deck in
                    FlashcardDeckDisplayEntry(
                        id: deck.id,
                        name: deck.title,
                        cardCount: deck.cards.count,
                        masteredCount: deck.cards.filter { $0.repetitions > 0 }.count,
                        courseName: courses.first(where: { $0.id == deck.subjectId })?.name ?? ""
                    )
                }
            }
        } catch {
            // Keep mock data on failure
            print("[EstudosViewModel] API fallback: \(error)")
            self.error = error.localizedDescription
        }
    }

    func selectTab(_ tab: EstudosTab) {
        selectedTab = tab
    }

    func selectCourse(_ courseId: String?) {
        selectedCourseId = courseId
        selectedTab = .pdfs
        Task { await reloadFiles() }
    }

    func clearCourseFilter() {
        selectedCourseId = nil
        Task { await reloadFiles() }
    }

    private func reloadFiles() async {
        isLoading = true
        do {
            let resp = try await api.getFiles(courseId: selectedCourseId)
            files = resp.files
        } catch {
            print("[EstudosViewModel] Files reload failed: \(error)")
        }
        isLoading = false
    }

    // MARK: - PDF Download

    func downloadFile(fileId: String, fileName: String) async -> URL? {
        guard downloadingFileId == nil else { return nil }
        downloadingFileId = fileId
        defer { downloadingFileId = nil }

        // Return cached path if already downloaded
        if let cached = downloadedFilePaths[fileId] {
            return cached
        }

        do {
            let data = try await api.downloadFileData(fileId: fileId)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdfs", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(fileName)
            try data.write(to: dest)
            downloadedFilePaths[fileId] = dest
            return dest
        } catch {
            print("[EstudosViewModel] Download failed: \(error)")
            return nil
        }
    }

    // MARK: - Mock Seed

    private func loadMock() {
        flashcardsDue = 12
        streakDays    = 5
        avgAccuracy   = 72

        courses = [
            Course(id: "c1", name: "Cardiologia Clínica",       code: "CM-101", filesCount: 12, assignmentsCount: 3),
            Course(id: "c2", name: "Pneumologia e Terapia Int.", code: "CM-102", filesCount: 8,  assignmentsCount: 2),
            Course(id: "c3", name: "Neurologia",                 code: "CM-103", filesCount: 15, assignmentsCount: 4),
            Course(id: "c4", name: "Farmacologia I",             code: "CM-104", filesCount: 10, assignmentsCount: 1),
        ]

        flashcardDisplayDecks = [
            FlashcardDeckDisplayEntry(id: "1", name: "Cardiologia",  cardCount: 30, masteredCount: 21, courseName: "Cardiologia Clínica"),
            FlashcardDeckDisplayEntry(id: "2", name: "Pneumologia",  cardCount: 20, masteredCount:  8, courseName: "Pneumologia"),
            FlashcardDeckDisplayEntry(id: "3", name: "Neurologia",   cardCount: 25, masteredCount: 25, courseName: "Neurologia"),
        ]

        files = [
            CanvasFile(id: "f1", displayName: "Harrison Cap. 12.pdf",     contentType: "application/pdf", courseName: "Cardiologia Clínica",       moduleName: "Módulo 1"),
            CanvasFile(id: "f2", displayName: "Diretriz ICC 2024.pdf",     contentType: "application/pdf", courseName: "Cardiologia Clínica",       moduleName: "Módulo 1"),
            CanvasFile(id: "f3", displayName: "Pneumo Avançada.pdf",       contentType: "application/pdf", courseName: "Pneumologia e Terapia Int.", moduleName: "Módulo 2"),
            CanvasFile(id: "f4", displayName: "Guyton Fisiologia.pdf",     contentType: "application/pdf", courseName: "Neurologia",                moduleName: nil),
            CanvasFile(id: "f5", displayName: "Síndromes Neurológicas.pdf",contentType: "application/pdf", courseName: "Neurologia",                moduleName: "Módulo 3"),
        ]

        simulados = [
            SimuladoEntry(id: "s1", title: "Simulado Cardio 01",    totalQ: 40, correctQ: 29, finishedAt: "2025-01-10"),
            SimuladoEntry(id: "s2", title: "Clínica Médica Geral",  totalQ: 60, correctQ: 38, finishedAt: "2025-01-08"),
            SimuladoEntry(id: "s3", title: "Pneumologia Avançada",  totalQ: 30, correctQ: 12, finishedAt: "2025-01-05"),
        ]

        documents = [
            DocumentEntry(id: "d1", title: "Harrison - Cap. 12",  fileName: "harrison-12.pdf",   readProgress: 65, totalPages: 28, currentPage: 18),
            DocumentEntry(id: "d2", title: "Sabiston Cirurgia",    fileName: "sabiston.pdf",       readProgress: 20, totalPages: 50, currentPage: 10),
            DocumentEntry(id: "d3", title: "Guyton - Fisiologia",  fileName: "guyton.pdf",         readProgress: 88, totalPages: 35, currentPage: 31),
        ]

        notes = [
            NoteEntry(id: "n1", title: "Notas Cardio",           content: "Mecanismo de compensação cardíaca: hipertrofia concêntrica vs excêntrica...", updatedAt: "2025-01-10"),
            NoteEntry(id: "n2", title: "Resumo Pneumo",          content: "DPOC: obstrução crônica ao fluxo aéreo, não totalmente reversível...",         updatedAt: "2025-01-09"),
            NoteEntry(id: "n3", title: "Síndromes Neurológicas", content: "Síndrome do neurônio motor superior: espasticidade, hiperreflexia...",          updatedAt: "2025-01-07"),
        ]
    }
}

// MARK: - Local Models (Estudos-specific)

struct SimuladoEntry: Identifiable {
    var id: String
    var title: String
    var totalQ: Int
    var correctQ: Int
    var finishedAt: String?

    var scorePercent: Int {
        guard totalQ > 0 else { return 0 }
        return Int((Double(correctQ) / Double(totalQ)) * 100)
    }
}

struct DocumentEntry: Identifiable {
    var id: String
    var title: String
    var fileName: String
    var readProgress: Int
    var totalPages: Int
    var currentPage: Int
}

struct NoteEntry: Identifiable {
    var id: String
    var title: String
    var content: String
    var updatedAt: String
}
