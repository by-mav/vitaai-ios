import Foundation

// MARK: - Notes Cloud Sync DTOs
// Matches the backend schema: vita.notes table
// Endpoints: GET /api/notes, POST /api/notes, PATCH /api/notes, DELETE /api/notes?id=

/// Server-side note returned by GET /api/notes and POST /api/notes.
/// CodingKeys explicitly map camelCase JSON keys because HTTPClient's decoder
/// uses convertFromSnakeCase which would expect snake_case.
struct RemoteNote: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let subjectId: String?
    let createdAt: String      // ISO 8601 from server
    let updatedAt: String      // ISO 8601 from server
    let deletedAt: String?



    /// Parses the ISO 8601 updatedAt string into a Date.
    var updatedDate: Date? {
        RemoteNote.iso8601Formatter.date(from: updatedAt)
    }

    var createdDate: Date? {
        RemoteNote.iso8601Formatter.date(from: createdAt)
    }

    /// Shared formatter that handles fractional seconds from the server.
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Body for POST /api/notes (create).
struct CreateNoteRequest: Encodable {
    let title: String
    let content: String
    let subjectId: String?
}

/// Body for PATCH /api/notes (update). Includes `id` at top level per backend route.
struct UpdateNoteRequest: Encodable {
    let id: String
    let title: String?
    let content: String?
    let subjectId: String?
}

// MARK: - MindMap Cloud Sync DTOs
// Matches the backend: GET /api/study/mindmaps
// Data comes from studio_outputs table with type='mindmap'.

/// Server-side mindmap entry returned by GET /api/study/mindmaps.
struct RemoteMindMap: Codable, Identifiable {
    let id: String
    let title: String
    let sourceIds: [String]?
    let nodes: MindMapNodesPayload?
    let createdAt: String      // ISO 8601
    let updatedAt: String      // ISO 8601

    var updatedDate: Date? {
        RemoteMindMap.iso8601Formatter.date(from: updatedAt)
    }

    var createdDate: Date? {
        RemoteMindMap.iso8601Formatter.date(from: createdAt)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// The `nodes` field in the mindmap response can be either an array of node objects
/// or a wrapper with a `nodes` key. We handle both.
struct MindMapNodesPayload: Codable {
    let items: [RemoteMindMapNode]

    init(from decoder: Decoder) throws {
        // Try decoding as array directly
        if let array = try? [RemoteMindMapNode](from: decoder) {
            self.items = array
            return
        }
        // Try decoding as { nodes: [...] }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = (try? container.decode([RemoteMindMapNode].self, forKey: .nodes)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
    }

    private enum CodingKeys: String, CodingKey {
        case nodes
    }
}

/// A single node in a remote mindmap. Subset of fields — we map to local MindMapNode.
struct RemoteMindMapNode: Codable {
    let id: String?
    let text: String?
    let x: Float?
    let y: Float?
    let parentId: String?
    let color: String?      // Could be hex string or number
    let width: Float?
    let height: Float?
}
