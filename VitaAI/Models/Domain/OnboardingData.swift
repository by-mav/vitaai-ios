import Foundation
import SwiftUI

struct OnboardingData: Codable {
    var nickname: String
    var universityName: String
    var universityState: String
    var semester: Int
    var subjects: [String]
    var subjectDifficulties: [String: String]
    var goals: [String]
    var dailyStudyMinutes: Int

    init(nickname: String = "", universityName: String = "", universityState: String = "", semester: Int = 1, subjects: [String] = [], subjectDifficulties: [String: String] = [:], goals: [String] = [], dailyStudyMinutes: Int = 60) {
        self.nickname = nickname
        self.universityName = universityName
        self.universityState = universityState
        self.semester = semester
        self.subjects = subjects
        self.subjectDifficulties = subjectDifficulties
        self.goals = goals
        self.dailyStudyMinutes = dailyStudyMinutes
    }
}

struct University: Identifiable, Decodable {
    let id: String
    let name: String
    let shortName: String
    let city: String
    let state: String
    let enamScore: Double?
    let portals: [UniversityPortal]?

    var allDetectedPortals: [UniversityPortal] { portals ?? [] }
    var academicPortals: [UniversityPortal] { allDetectedPortals.filter { $0.portalType == "canvas" || $0.portalType == "webaluno" } }
    var primaryPortal: UniversityPortal? { allDetectedPortals.first }
    var lmsPortals: [UniversityPortal] { allDetectedPortals.filter { $0.portalType != "canvas" && $0.portalType != "webaluno" } }

    var displayName: String { shortName.isEmpty ? name : shortName }
    var letter: String { String(shortName.prefix(1)).uppercased() }
    var color: String { "#C8A750" }

    static func displayName(for portalType: String) -> String {
        switch portalType {
        case "canvas": return "Canvas LMS"
        case "webaluno": return "WebAluno"
        case "google_calendar": return "Google Calendar"
        case "google_drive": return "Google Drive"
        default: return portalType.capitalized
        }
    }
    static func letter(for portalType: String) -> String {
        switch portalType {
        case "canvas": return "C"
        case "webaluno": return "W"
        case "google_calendar": return "G"
        case "google_drive": return "D"
        default: return String(portalType.prefix(1)).uppercased()
        }
    }
    static func color(for portalType: String) -> Color {
        switch portalType {
        case "canvas": return Color(red: 0.89, green: 0.12, blue: 0.15)
        case "webaluno": return Color(red: 0.20, green: 0.60, blue: 0.86)
        default: return Color(red: 0.78, green: 0.66, blue: 0.32)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, shortName, city, state, enamScore, portals
    }
}

struct UniversitiesResponse: Decodable {
    let universities: [University]
}

struct UniversityPortal: Identifiable, Decodable {
    let id: String
    let portalType: String
    let portalName: String
    let instanceUrl: String?

    var displayName: String { portalName }
    var isPrimary: Bool { portalType == "canvas" || portalType == "webaluno" }
}
