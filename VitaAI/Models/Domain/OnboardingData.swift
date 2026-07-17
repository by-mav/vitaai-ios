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
    let countryCode: String
    let countryName: String
    let enameConcept: Int?
    let portals: [UniversityPortal]?

    init(
        id: String,
        name: String,
        shortName: String = "",
        city: String = "",
        state: String = "",
        countryCode: String = "BR",
        countryName: String = "Brazil",
        enameConcept: Int? = nil,
        portals: [UniversityPortal]? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.city = city
        self.state = state
        self.countryCode = countryCode
        self.countryName = countryName
        self.enameConcept = enameConcept
        self.portals = portals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName) ?? ""
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode) ?? "BR"
        countryName = try container.decodeIfPresent(String.self, forKey: .countryName) ?? "Brazil"
        enameConcept = try container.decodeIfPresent(Int.self, forKey: .enameConcept)
        portals = try container.decodeIfPresent([UniversityPortal].self, forKey: .portals)
    }

    var allDetectedPortals: [UniversityPortal] { portals ?? [] }
    var academicPortals: [UniversityPortal] { allDetectedPortals.filter { $0.portalType == "canvas" } }
    var primaryPortal: UniversityPortal? { allDetectedPortals.first }
    var lmsPortals: [UniversityPortal] { allDetectedPortals.filter { $0.portalType != "canvas" } }

    var displayName: String { shortName.isEmpty ? name : shortName }
    var letter: String { String(shortName.prefix(1)).uppercased() }
    var color: String { "#C8A750" }
    var localizedCountryName: String {
        Locale.autoupdatingCurrent.localizedString(forRegionCode: countryCode) ?? countryName
    }

    static func displayName(for portalType: String) -> String {
        switch portalType {
        case "canvas": return "Canvas LMS"
        case "google_calendar": return "Google Calendar"
        case "google_drive": return "Google Drive"
        default: return portalType.capitalized
        }
    }
    static func letter(for portalType: String) -> String {
        switch portalType {
        case "canvas": return "C"
        case "google_calendar": return "G"
        case "google_drive": return "D"
        default: return String(portalType.prefix(1)).uppercased()
        }
    }
    static func color(for portalType: String) -> Color {
        switch portalType {
        case "canvas": return Color(red: 0.89, green: 0.12, blue: 0.15)
        default: return Color(red: 0.78, green: 0.66, blue: 0.32)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, shortName, city, state, countryCode, countryName, enameConcept, portals
    }
}

struct UniversitiesResponse: Decodable {
    let universities: [University]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        universities = try container.decode([University].self, forKey: .universities)
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? universities.count
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? universities.count
        offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case universities, total, limit, offset, hasMore
    }
}

struct UniversityCountry: Identifiable, Decodable, Hashable {
    let code: String
    let name: String
    let schoolCount: Int

    var id: String { code }
    var localizedName: String {
        Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? name
    }
}

struct UniversityCountriesResponse: Decodable {
    let countries: [UniversityCountry]
    let total: Int
}

struct UniversityPortal: Identifiable, Decodable {
    let id: String
    let portalType: String
    let portalName: String
    let instanceUrl: String?

    var displayName: String { portalName }
    var isPrimary: Bool { portalType == "canvas" }
}
