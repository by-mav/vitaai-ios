import Foundation

// MARK: - CourseGrade (Canvas course with average grade + completion progress)

struct CourseGrade: Identifiable {
    let id: String          // courseId
    let courseName: String
    let grade: Double       // average grade 0–10
    let assignments: Int    // total assignments
    let completed: Int      // submitted/completed
}

// MARK: - StudyStats (aggregate study metrics)

struct StudyStats {
    var totalHoursThisWeek: Double
    var averageGrade: Double
    var completedAssignments: Int
    var pendingAssignments: Int
    var streak: Int
}

enum EventType: String, Codable {
    case assignment = "ASSIGNMENT"
    case exam = "EXAM"
    case classEvent = "CLASS"
    case study = "STUDY"
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let type: EventType
    var courseName: String = ""
    var courseId: String = ""
}

enum ActivityType: String {
    case assignmentSubmitted = "ASSIGNMENT_SUBMITTED"
    case gradeReceived = "GRADE_RECEIVED"
    case materialRead = "MATERIAL_READ"
    case studySession = "STUDY_SESSION"
}

struct RecentActivity: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let type: ActivityType
    let timestamp: String
}
