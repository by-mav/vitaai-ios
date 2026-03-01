import Foundation

struct ProfileResponse: Codable {
    var id: String = ""
    var authId: String = ""
    var displayName: String?
    var moment: String?
    var year: Int?
    var streakDays: Int = 0
    var totalStudyHours: Double = 0.0
}
