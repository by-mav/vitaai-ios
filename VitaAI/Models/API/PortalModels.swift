import Foundation

// MARK: - Portal Data (GET /api/portal/data)
// Used by FaculdadeViewModel to display academic life dashboard.

struct PortalData200Response: Decodable {
    let enrollments: [PortalEnrollment]?
    let grades: [PortalGrade]?
    let evaluations: [PortalEvaluation]?
    let schedule: [PortalScheduleItem]?
    let calendar: [PortalCalendarItem]?
}

struct PortalEnrollment: Decodable, Identifiable {
    var id: String = UUID().uuidString
    let courseName: String?
    let grade: Double?
    let attendance: Double?

    enum CodingKeys: String, CodingKey {
        case id, courseName, grade, attendance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.courseName = try? c.decode(String.self, forKey: .courseName)
        self.grade = try? c.decode(Double.self, forKey: .grade)
        self.attendance = try? c.decode(Double.self, forKey: .attendance)
    }
}

struct PortalGrade: Decodable, Identifiable {
    var id: String? = UUID().uuidString
    let subjectName: String?
    let label: String?
    let value: Double?
    // Rich grade fields (from webaluno sync)
    let grade1: String?
    let grade2: String?
    let grade3: String?
    let finalGrade: String?
    let attendance: String?
    let absences: String?
    let professor: String?
    let semester: String?
    let status: String?
}

struct PortalEvaluation: Decodable {
    let id: String?
    let title: String?
    let type: String?
    let date: String?
    let subjectName: String?
    let score: Double?
    let pointsPossible: Double?
    let grade: String?
    let status: String?
}

struct PortalScheduleItem: Decodable {
    let id: String?
    let subjectName: String?
    let professor: String?
    let room: String?
    let dayOfWeek: Int?
    let startTime: String?
    let endTime: String?
}

struct PortalCalendarItem: Decodable {
    let id: String?
    let title: String?
    let type: String?
    let startAt: String?
    let subjectName: String?
}

// MARK: - Enrollments (GET /api/enrollments)

struct GetEnrollments200Response: Decodable {
    let enrollments: [PortalEnrollment]?
}

// MARK: - Student Context (GET /api/vita/student-context)

struct GetStudentContext200Response: Decodable {
    let context: String?
}
