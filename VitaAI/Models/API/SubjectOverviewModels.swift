import Foundation

// MARK: - SubjectOverview
//
// Visao consolidada por disciplina — mesma origem do MCP `academics overview`
// e do endpoint GET /api/subjects/overview (cerebro unico backend).
// Cada materia ja traz materiais/provas/trabalhos/notas numa resposta.

struct SubjectsOverviewResponse: Codable {
    let count: Int
    let subjects: [SubjectOverview]
}

struct SubjectOverview: Codable, Identifiable {
    let id: String
    let name: String
    let professor: String?
    let materials: Materials
    let exams: Exams
    let assignments: Assignments
    let grades: Grades

    struct Materials: Codable {
        let slides: Int
        let plano: Int
        let transcricoes: Int
        let total: Int
    }
    struct Exams: Codable {
        let total: Int
        let upcoming: Int
    }
    struct Assignments: Codable {
        let total: Int
        let pending: Int
    }
    struct Grades: Codable {
        let avg: Double?
        let manualCount: Int
    }
}
