import Foundation

// MIGRATION: No generated OpenAPI equivalents for Google Calendar/Drive models.
// These endpoints are not yet in the OpenAPI spec. Kept manual.

// MARK: - Google Calendar

struct GoogleCalendarCountsResponse: Codable {
    var events: Int = 0
}

struct GoogleCalendarStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var lastSyncAt: String?
    var googleEmail: String?
    var counts: GoogleCalendarCountsResponse?
}

struct GoogleCalendarSyncResponse: Codable {
    var synced: Int = 0
    var events: Int = 0
}

// MARK: - Google Drive

struct GoogleDriveCountsResponse: Codable {
    var files: Int = 0
}

struct GoogleDriveStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var lastSyncAt: String?
    var googleEmail: String?
    var counts: GoogleDriveCountsResponse?
}

struct GoogleDriveSyncResponse: Codable {
    var synced: Int = 0
    var files: Int = 0
}
