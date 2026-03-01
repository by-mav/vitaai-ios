import Foundation

@MainActor
@Observable
final class EstudosViewModel {
    private let api: VitaAPI

    // Stats
    var flashcardsDue: Int = 0
    var streakDays: Int = 0
    var avgAccuracy: Double = 0

    // Sections
    var flashcardDecks: [FlashcardDeckEntry] = []
    var simulados: [SimuladoEntry] = []
    var documents: [DocumentEntry] = []
    var notes: [NoteEntry] = []

    var isLoading = true

    init(api: VitaAPI) {
        self.api = api
    }

    func load() async {
        isLoading = true
        loadMock()
        isLoading = false

        // Try real API and overlay live data
        do {
            async let progressTask = api.getProgress()
            async let decksTask = api.getFlashcardDecks(dueOnly: true)
            let (progress, decks) = try await (progressTask, decksTask)
            flashcardsDue = progress.flashcardsDue
            streakDays = progress.streakDays
            avgAccuracy = progress.avgAccuracy
            if !decks.isEmpty {
                flashcardDecks = decks
            }
        } catch {
            // Keep mock data on API failure — intentional silent fallback
            print("[EstudosViewModel] API fallback: \(error)")
        }
    }

    // MARK: - Mock Seed

    private func loadMock() {
        flashcardsDue = 12
        streakDays = 5
        avgAccuracy = 72

        flashcardDecks = [
            FlashcardDeckEntry(
                id: "1",
                title: "Cardiologia",
                subjectId: "cm-cardio",
                updatedAt: nil,
                cards: (0..<5).map {
                    FlashcardEntry(
                        id: "\($0)",
                        front: "",
                        back: "",
                        nextReviewAt: nil,
                        easeFactor: 2.5,
                        interval: 0,
                        repetitions: 0
                    )
                }
            ),
            FlashcardDeckEntry(
                id: "2",
                title: "Pneumologia",
                subjectId: "cm-pneumo",
                updatedAt: nil,
                cards: (0..<3).map {
                    FlashcardEntry(
                        id: "p\($0)",
                        front: "",
                        back: "",
                        nextReviewAt: nil,
                        easeFactor: 2.5,
                        interval: 0,
                        repetitions: 0
                    )
                }
            ),
            FlashcardDeckEntry(
                id: "3",
                title: "Neurologia",
                subjectId: "cm-neuro",
                updatedAt: nil,
                cards: (0..<8).map {
                    FlashcardEntry(
                        id: "n\($0)",
                        front: "",
                        back: "",
                        nextReviewAt: nil,
                        easeFactor: 2.5,
                        interval: 0,
                        repetitions: 0
                    )
                }
            )
        ]

        simulados = [
            SimuladoEntry(
                id: "s1",
                title: "Simulado Cardio 01",
                totalQ: 40,
                correctQ: 29,
                finishedAt: "2025-01-10"
            ),
            SimuladoEntry(
                id: "s2",
                title: "Clínica Médica Geral",
                totalQ: 60,
                correctQ: 38,
                finishedAt: "2025-01-08"
            ),
            SimuladoEntry(
                id: "s3",
                title: "Pneumologia Avançada",
                totalQ: 30,
                correctQ: 12,
                finishedAt: "2025-01-05"
            )
        ]

        documents = [
            DocumentEntry(
                id: "d1",
                title: "Harrison - Cap. 12",
                fileName: "harrison-12.pdf",
                readProgress: 65,
                totalPages: 28,
                currentPage: 18
            ),
            DocumentEntry(
                id: "d2",
                title: "Sabiston Cirurgia",
                fileName: "sabiston.pdf",
                readProgress: 20,
                totalPages: 50,
                currentPage: 10
            ),
            DocumentEntry(
                id: "d3",
                title: "Guyton - Fisiologia",
                fileName: "guyton.pdf",
                readProgress: 88,
                totalPages: 35,
                currentPage: 31
            )
        ]

        notes = [
            NoteEntry(
                id: "n1",
                title: "Notas Cardio",
                content: "Mecanismo de compensação cardíaca: hipertrofia concêntrica vs excêntrica. Frank-Starling...",
                updatedAt: "2025-01-10"
            ),
            NoteEntry(
                id: "n2",
                title: "Resumo Pneumo",
                content: "DPOC: obstrução crônica ao fluxo aéreo, não totalmente reversível. VEF1/CVF < 0.7...",
                updatedAt: "2025-01-09"
            ),
            NoteEntry(
                id: "n3",
                title: "Síndromes Neurológicas",
                content: "Síndrome do neurônio motor superior: espasticidade, hiperreflexia, Babinski positivo...",
                updatedAt: "2025-01-07"
            )
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
