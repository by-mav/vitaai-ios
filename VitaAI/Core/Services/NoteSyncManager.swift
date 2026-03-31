import Foundation
import Observation
import SwiftData

// MARK: - NoteSyncManager
// Local-first cloud sync for notebooks. Pulls remote notes on init, pushes on save.
//
// Strategy:
//   - Pull: fetch GET /api/notes → merge into local SwiftData (server wins on conflict)
//   - Push: after local create/update, POST/PATCH to server
//   - Conflict resolution: if both local and remote changed, server wins (updatedAt comparison)
//   - Offline: all operations work locally; sync retries on next app launch
//
// Threading: @MainActor since it accesses SwiftData ModelContext via NotebookRepository.

@Observable
@available(iOS 17, *)
@MainActor
final class NoteSyncManager {

    private let api: VitaAPI
    private let repository: NotebookRepository

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncError: String?
    private(set) var lastSyncDate: Date?

    init(api: VitaAPI, repository: NotebookRepository) {
        self.api = api
        self.repository = repository
    }

    // MARK: - Pull (server → local)

    /// Fetches all notes from the server and merges them into local SwiftData.
    /// Server wins on conflict (if remote updatedAt > local updatedAt).
    func pull() async {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let remoteNotes = try await api.getNotes(limit: 200)
            let localNotebooks = try repository.fetchAllNotebooks()

            // Build lookup: remoteId → local entity
            var remoteIdToLocal: [String: NotebookEntity] = [:]
            for nb in localNotebooks {
                if let rid = nb.remoteId {
                    remoteIdToLocal[rid] = nb
                }
            }

            let now = Int64(Date().timeIntervalSince1970 * 1000)

            for remote in remoteNotes {
                if let local = remoteIdToLocal[remote.id] {
                    // Existing local entity — check if server is newer
                    let remoteUpdatedMs = remote.updatedDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0
                    if remoteUpdatedMs > local.updatedAt {
                        // Server wins — update local
                        local.title = remote.title
                        local.textContent = remote.content
                        local.updatedAt = remoteUpdatedMs
                        local.syncedAt = now
                    }
                    // Remove from lookup so we know which locals have no remote match
                    remoteIdToLocal.removeValue(forKey: remote.id)
                } else {
                    // New remote note — create local entity
                    let createdMs = remote.createdDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? now
                    let updatedMs = remote.updatedDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? now

                    let entity = NotebookEntity(
                        id: UUID().uuidString,
                        title: remote.title,
                        coverColor: Int64(bitPattern: 0xFF3B82F6), // Default blue
                        createdAt: createdMs,
                        updatedAt: updatedMs,
                        pageCount: 1,
                        remoteId: remote.id,
                        syncedAt: now,
                        textContent: remote.content
                    )
                    repository.context.insert(entity)

                    // Create a default first page
                    let page = PageEntity(
                        id: UUID().uuidString,
                        notebook: entity,
                        pageIndex: 0,
                        template: "ruled"
                    )
                    repository.context.insert(page)
                    entity.pages.append(page)
                }
            }

            try repository.context.save()
            lastSyncDate = Date()
        } catch {
            lastSyncError = "Pull failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Push (local → server)

    /// Pushes all unsynced local notebooks to the server.
    /// - Notebooks with no remoteId → POST (create)
    /// - Notebooks with remoteId but updatedAt > syncedAt → PATCH (update)
    func push() async {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let localNotebooks = try repository.fetchAllNotebooks()
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            for nb in localNotebooks {
                if nb.remoteId == nil {
                    // Never synced — create on server
                    do {
                        let remote = try await api.createNote(
                            title: nb.title,
                            content: nb.textContent ?? ""
                        )
                        nb.remoteId = remote.id
                        nb.syncedAt = now
                    } catch {
                        // Non-fatal: will retry next sync
                        continue
                    }
                } else if let syncedAt = nb.syncedAt, nb.updatedAt > syncedAt {
                    // Changed since last sync — update on server
                    do {
                        _ = try await api.updateNote(
                            id: nb.remoteId!,
                            title: nb.title,
                            content: nb.textContent
                        )
                        nb.syncedAt = now
                    } catch {
                        continue
                    }
                }
            }

            try repository.context.save()
            lastSyncDate = Date()
        } catch {
            lastSyncError = "Push failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Full Sync (pull then push)

    /// Performs a full bidirectional sync: pull first (server wins), then push unsynced.
    func sync() async {
        await pull()
        await push()
    }

    // MARK: - Push Single Notebook

    /// Pushes a single notebook to the server after a local save.
    /// Called by NotebookStore after create/update operations.
    func pushNotebook(id: String) async {
        do {
            guard let nb = try repository.fetchNotebook(id: id) else { return }
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            if nb.remoteId == nil {
                let remote = try await api.createNote(
                    title: nb.title,
                    content: nb.textContent ?? ""
                )
                nb.remoteId = remote.id
                nb.syncedAt = now
                try repository.context.save()
            } else if nb.syncedAt == nil || nb.updatedAt > nb.syncedAt! {
                _ = try await api.updateNote(
                    id: nb.remoteId!,
                    title: nb.title,
                    content: nb.textContent
                )
                nb.syncedAt = now
                try repository.context.save()
            }
        } catch {
            // Silent failure — will retry on next sync
        }
    }

    // MARK: - Delete Remote

    /// Deletes a note from the server (soft delete).
    func deleteRemoteNote(remoteId: String) async {
        do {
            try await api.deleteNote(id: remoteId)
        } catch {
            // Silent — server will eventually clean up
        }
    }
}

