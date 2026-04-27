import Foundation

// MARK: - VitaNotification Model

struct VitaNotification: Identifiable, Decodable {
    let id: String
    let type: String
    let title: String
    let description: String
    let time: String?
    let read: Bool
    var createdAt: String? = nil
    var route: String? = nil
    var group: String? = nil
    var priority: String? = nil

    // Portal source — added 2026-04-27. NULL = notif interna Vita.
    // Populated when notification originates from a connected portal
    // (canvas, mannesoft, sigaa, etc). Used by PortalIcon to render
    // dynamic icon — no hardcoded portal-specific logic in client.
    var source: String? = nil
    var subjectId: String? = nil
    var metadata: NotificationMetadata? = nil

    var icon: String {
        switch type {
        case "gradePosted": return "\u{1F4CA}"
        case "examAlert", "exam": return "\u{1F4DD}"
        case "assignment": return "\u{1F4CB}"
        case "seminar": return "\u{1F399}\u{FE0F}"
        case "attendanceAlert": return "\u{26A0}\u{FE0F}"
        case "newMaterial": return "\u{1F4DA}"
        case "badge": return "\u{1F3C6}"
        case "streak": return "\u{1F525}"
        case "flashcard", "flashcardDue": return "\u{1F0CF}"
        case "reminder", "studyPlan": return "\u{23F0}"
        case "deadline": return "\u{23F3}"
        case "vitaInsight": return "\u{1F4A1}"
        case "transcriptionReady": return "\u{1F3A7}"
        case "transcriptionFailed", "uploadFailed": return "\u{26A0}\u{FE0F}"
        case "portalCookieExpired": return "\u{1F510}"
        case "quotaWarning": return "\u{1F4E6}"
        default: return "\u{1F514}"
        }
    }

    /// SF Symbol matching `type` — used by VitaNotifPopout pra render gold-tinted
    /// icons em vez de emoji (alinha com paleta monocromática gold do app).
    var sfSymbol: String {
        switch type {
        case "gradePosted": return "chart.bar.fill"
        case "examAlert", "exam": return "doc.text.fill"
        case "assignment": return "list.clipboard.fill"
        case "seminar": return "mic.fill"
        case "attendanceAlert": return "exclamationmark.triangle.fill"
        case "newMaterial": return "books.vertical.fill"
        case "badge": return "trophy.fill"
        case "streak": return "flame.fill"
        case "flashcard", "flashcardDue": return "rectangle.stack.fill"
        case "reminder", "studyPlan": return "alarm.fill"
        case "deadline": return "hourglass"
        case "vitaInsight": return "lightbulb.fill"
        case "transcriptionReady": return "waveform.circle.fill"
        case "transcriptionFailed", "uploadFailed": return "exclamationmark.circle.fill"
        case "portalCookieExpired": return "lock.rotation"
        case "quotaWarning": return "externaldrive.badge.exclamationmark"
        case "portal_announcement": return "megaphone.fill"
        case "portal_file_added": return "doc.fill"
        case "portal_assignment_added": return "list.clipboard.fill"
        case "portal_grade_posted": return "chart.bar.fill"
        case "portal_update": return "arrow.triangle.2.circlepath"
        case "portal_summary": return "tray.full.fill"
        default: return "bell.fill"
        }
    }

    var relativeTime: String {
        guard let createdAt, let date = Self.parseDate(createdAt) else {
            return time ?? ""
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Agora" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h" }
        let days = hours / 24
        return "\(days) d"
    }

    private static func parseDate(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }
}

// MARK: - NotificationMetadata
// Backend self-contained payload (added 2026-04-27): icon URL + brand resolved
// from portal_types at create-time, plus extra deep-link context. Client never
// makes a separate lookup — render uses what's here.
struct NotificationMetadata: Decodable {
    var iconUrl: String?
    var brandColor: String?
    var portalDisplayName: String?
    var externalId: String?
    var canvasCourseId: String?
    var courseName: String?
    var dueAt: String?

    private enum CodingKeys: String, CodingKey {
        case iconUrl, brandColor, portalDisplayName, externalId
        case canvasCourseId, courseName, dueAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        iconUrl = try c.decodeIfPresent(String.self, forKey: .iconUrl)
        brandColor = try c.decodeIfPresent(String.self, forKey: .brandColor)
        portalDisplayName = try c.decodeIfPresent(String.self, forKey: .portalDisplayName)
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        // canvasCourseId may arrive as Int or String — accept both
        if let i = try? c.decode(Int.self, forKey: .canvasCourseId) {
            canvasCourseId = String(i)
        } else {
            canvasCourseId = try c.decodeIfPresent(String.self, forKey: .canvasCourseId)
        }
        courseName = try c.decodeIfPresent(String.self, forKey: .courseName)
        dueAt = try c.decodeIfPresent(String.self, forKey: .dueAt)
    }
}
