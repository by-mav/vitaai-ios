import Foundation
import Observation
import SwiftData

// MARK: - MindMapSyncManager
// Pull-only cloud sync for mind maps. The server generates mindmaps via Vita Studio;
// the iOS app only reads them. Local edits stay local.
//
// Strategy:
//   - Pull: GET /api/study/mindmaps → merge into local SwiftData (server wins)
//   - No push: mindmaps are generated server-side
//   - Conflict: server wins (updatedAt comparison)
//   - Offline: local data persists; sync on next launch
//
// Threading: @MainActor since it accesses SwiftData ModelContext.

@Observable
@available(iOS 17, *)
@MainActor
final class MindMapSyncManager {

    private let api: VitaAPI
    private let repository: MindMapRepository

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncError: String?
    private(set) var lastSyncDate: Date?

    init(api: VitaAPI, repository: MindMapRepository) {
        self.api = api
        self.repository = repository
    }

    // MARK: - Pull (server → local)

    /// Fetches mindmaps from server and merges into local SwiftData.
    /// Server wins on conflict.
    func pull() async {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let remoteMaps = try await api.getMindMaps(limit: 200)
            let localMaps = try repository.fetchAll()

            // Build lookup: remoteId → local entity
            var remoteIdToLocal: [String: MindMapEntity] = [:]
            for mm in localMaps {
                if let rid = mm.remoteId {
                    remoteIdToLocal[rid] = mm
                }
            }

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let encoder = JSONEncoder()

            for remote in remoteMaps {
                let nodesJson = buildNodesJson(from: remote, encoder: encoder)
                let remoteUpdatedMs = remote.updatedDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? now

                if let local = remoteIdToLocal[remote.id] {
                    // Existing — update if server is newer
                    if remoteUpdatedMs > local.updatedAt {
                        local.title = remote.title
                        local.nodesJson = nodesJson
                        local.updatedAt = remoteUpdatedMs
                        local.syncedAt = now
                    }
                    remoteIdToLocal.removeValue(forKey: remote.id)
                } else {
                    // New from server — insert locally
                    let createdMs = remote.createdDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? now

                    let entity = MindMapEntity(
                        id: UUID().uuidString,
                        title: remote.title,
                        nodesJson: nodesJson,
                        coverColor: Int64(bitPattern: 0xFF22D3EE), // Default cyan
                        createdAt: createdMs,
                        updatedAt: remoteUpdatedMs,
                        remoteId: remote.id,
                        syncedAt: now
                    )
                    try repository.insert(entity)
                }
            }

            // Save any updates to existing entities
            try repository.context.save()
            lastSyncDate = Date()
        } catch {
            lastSyncError = "Pull failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// Converts remote mindmap nodes payload into a local MindMapData JSON string.
    private func buildNodesJson(from remote: RemoteMindMap, encoder: JSONEncoder) -> String {
        guard let payload = remote.nodes else {
            return "{\"nodes\":[]}"
        }

        let localNodes: [MindMapNode] = payload.items.enumerated().map { index, rn in
            MindMapNode(
                id: rn.id ?? UUID().uuidString,
                text: rn.text ?? "",
                x: rn.x ?? Float(150 + index * 200),
                y: rn.y ?? Float(300),
                parentId: rn.parentId,
                color: parseColor(rn.color) ?? mindMapNodeColors[index % mindMapNodeColors.count],
                width: rn.width ?? 160,
                height: rn.height ?? 60
            )
        }

        let data = MindMapData(nodes: localNodes)
        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{\"nodes\":[]}"
    }

    /// Parses a color string (hex like "#22D3EE" or "0xFF22D3EE") to UInt64 ARGB.
    private func parseColor(_ colorString: String?) -> UInt64? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }

        var hex = colorString
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")

        // If 6-char hex, prepend FF alpha
        if hex.count == 6 {
            hex = "FF" + hex
        }

        guard let value = UInt64(hex, radix: 16) else { return nil }
        return value
    }
}

