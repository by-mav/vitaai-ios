import Foundation

// MIGRATION: No generated OpenAPI equivalents for Crowd models.
// These endpoints are not yet in the OpenAPI spec. Kept manual.

// MARK: - Crowd Models
// Mirrors Android: data/model/CrowdModels.kt

// --- GET /api/crowd/professors ---

struct CrowdProfessor: Codable, Identifiable {
    var id: String = ""
    var nameDisplay: String = ""
    var institution: String = ""
    var disciplines: [String] = []
    var examCount: Int = 0
    var questionCount: Int = 0
}

// --- GET /api/crowd/exams ---

struct CrowdExamEntry: Codable, Identifiable {
    var id: String = ""
    var discipline: String = ""
    var examType: String = ""
    var semester: String? = nil
    var institution: String = ""
    var questionCount: Int = 0
    var createdAt: String = ""
    var professorName: String = ""
    var professorId: String = ""
}

// --- GET /api/crowd/exams/:id ---

struct CrowdExamDetail: Codable, Identifiable {
    var id: String = ""
    var discipline: String = ""
    var examType: String = ""
    var semester: String? = nil
    var institution: String = ""
    var questionCount: Int = 0
    var createdAt: String = ""
    var professorName: String = ""
    var professorId: String = ""
    var questions: [CrowdQuestion] = []
}

struct CrowdQuestion: Codable, Identifiable {
    var id: String = ""
    var questionIndex: Int = 0
    var statement: String = ""
    var options: [String]? = nil
    var answer: String? = nil
    var topic: String? = nil
    var difficulty: String? = nil
}

// --- GET /api/crowd/upload (history) ---

struct CrowdUploadRecord: Codable, Identifiable {
    var id: String = ""
    var status: String = ""
    var examId: String? = nil
    var ocrCostUsd: Double? = nil
    var createdAt: String = ""
    var completedAt: String? = nil
    var errorMessage: String? = nil
}

// --- POST /api/crowd/upload (response) ---

struct CrowdUploadResponse: Codable {
    var uploadId: String = ""
    var status: String = ""
    var fileCount: Int = 0
    var message: String = ""
}
