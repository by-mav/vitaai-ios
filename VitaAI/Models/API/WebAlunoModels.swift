import Foundation

struct WebalunoStatusResponse: Codable {
    var connected: Bool = false
    var connection: WebalunoConnectionInfo?
    var counts: WebalunoCounts?
}

struct WebalunoConnectionInfo: Codable {
    var instanceUrl: String?
    var status: String?
    var lastSyncAt: String?
}

struct WebalunoCounts: Codable {
    var grades: Int = 0
    var schedule: Int = 0
    var semesters: Int = 0
    var completed: Int = 0
}

struct WebalunoConnectRequest: Codable {
    var cpf: String?
    var password: String?
    var sessionCookie: String?
    var instanceUrl: String = "https://ac3949.mannesoftprime.com.br"
}

struct WebalunoConnectResponse: Codable {
    var success: Bool = false
    var grades: Int = 0
    var schedule: Int = 0
    var syncErrors: [String]?
    var error: String?
}

struct WebalunoSyncResponse: Codable {
    var success: Bool = false
    var grades: Int = 0
    var schedule: Int = 0
    var error: String?
}

struct WebalunoGradesResponse: Codable {
    var grades: [WebalunoGrade] = []
    var summary: WebalunoGradesSummary?
    var lastSyncAt: String?
}

struct WebalunoGrade: Codable, Identifiable {
    var id: String = ""
    var subjectName: String = ""
    var subjectCode: String?
    var grade1: Double?
    var grade2: Double?
    var grade3: Double?
    var finalGrade: Double?
    var status: String?
    var attendance: Double?
    var semester: String?
}

struct WebalunoGradesSummary: Codable {
    var total: Int = 0
    var completed: Int = 0
    var inProgress: Int = 0
    var averageGrade: Double?
    var semesters: Int = 0
}

struct WebalunoScheduleResponse: Codable {
    var schedule: [WebalunoScheduleBlock] = []
    var summary: WebalunoScheduleSummary?
    var lastSyncAt: String?
}

struct WebalunoScheduleBlock: Codable {
    var subjectName: String = ""
    var dayOfWeek: Int = 0
    var startTime: String = ""
    var endTime: String = ""
    var room: String?
    var professor: String?
    var slots: Int = 1
}

struct WebalunoScheduleSummary: Codable {
    var totalClasses: Int = 0
    var subjects: Int = 0
    var daysWithClasses: Int = 0
}
