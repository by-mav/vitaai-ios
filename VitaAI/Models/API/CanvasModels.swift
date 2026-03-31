import Foundation

struct CanvasStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var instanceUrl: String?
    var lastSyncAt: String?
    var courses: Int = 0
    var files: Int = 0
    var assignments: Int = 0
}

struct CanvasConnectRequest: Codable {
    var accessToken: String
    var instanceUrl: String = "https://ulbra.instructure.com"
}

struct CanvasConnectResponse: Codable {
    var success: Bool = false
    var connectionId: String?
    var updated: Bool = false
    var error: String?
}

struct CanvasSyncResponse: Codable {
    var courses: Int = 0
    var files: Int = 0
    var assignments: Int = 0
    var calendarEvents: Int = 0
    var pdfExtracted: Int = 0
    var studyEvents: Int = 0
    var errors: [String] = []
}

struct CoursesResponse: Codable {
    var connected: Bool = false
    var courses: [Course] = []
}

struct Course: Codable, Identifiable {
    var id: String
    var name: String
    var code: String = ""
    var term: String = ""
    var filesCount: Int = 0
    var assignmentsCount: Int = 0
    var pdfsCount: Int = 0
}

struct FilesResponse: Codable {
    var files: [CanvasFile] = []
}

struct CanvasFile: Codable, Identifiable {
    var id: String
    var displayName: String
    var contentType: String?
    var size: Int64 = 0
    var hasText: Bool = false
    var totalPages: Int?
    var courseName: String?
    var courseId: String?
    var moduleName: String?
    var modulePosition: Int?
    var itemPosition: Int?
    var updatedAt: String?
}

struct AssignmentsResponse: Codable {
    var assignments: [Assignment] = []
}

struct Assignment: Codable, Identifiable {
    var id: String
    var name: String
    var description: String?
    var dueAt: String?
    var pointsPossible: Double?
    var courseName: String = ""
    var courseId: String = ""
}

// MARK: - Sync Progress (from /api/portal/sync-progress)

struct SyncProgressResponse: Codable {
    var syncId: String?
    var phase: String = "connecting"
    var percent: Double = 0
    var label: String = ""
    var grades: Int = 0
    var schedule: Int = 0

    var isDone: Bool { phase == "done" || percent >= 100 }
    var isError: Bool { phase == "error" }
}

// MARK: - Vita Crawl (universal portal extraction via Vita LLM)

struct VitaCrawlRequest: Codable {
    var cookies: String
    var instanceUrl: String
}

struct VitaCrawlResponse: Codable {
    var syncId: String?
    var status: String?
    var error: String?
}

// MARK: - Sync Progress Items (granular progress from Vita crawl)

struct SyncProgressItem: Codable, Identifiable {
    var id: String { "\(type)-\(name)" }
    var type: String = ""
    var name: String = ""
    var status: String = "pending"
    var detail: String?
}
