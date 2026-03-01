import Foundation

struct OnboardingData: Codable {
    var nickname: String
    var universityName: String
    var universityState: String
    var semester: Int
    var subjects: [String]
    var goals: [String]
    var dailyStudyMinutes: Int
}

struct University: Identifiable {
    let id = UUID()
    let name: String
    let shortName: String
    let city: String
    let state: String
}
