import Foundation
import SwiftData
import SwiftUI

// MARK: - NotebookStore
// Backed by SwiftData (NotebookRepository) instead of raw FileManager JSON.
// Public API is identical to the previous FileManager implementation so that
// NotebookListViewModel, EditorViewModel and all Views remain unchanged.
//
// Mapping: iOS domain model ↔ SwiftData entity
//   Notebook      ↔ NotebookEntity   (metadata)
//   NotebookPage  ↔ PageEntity       (metadata)
//   PKDrawing     →  StrokeFileStorage (binary canvas, unchanged)
//
// Threading: @Observable + @MainActor — all mutations happen on main actor.
// The repository is called with try; errors are silently swallowed for
// non-critical paths (mirrors Android's catch {} pattern in Room flows),
// but critical errors are propagated via the error property.

@Observable
@MainActor
final class NotebookStore {

    // MARK: - Published state

    private(set) var notebooks: [Notebook] = []
    private(set) var isLoading: Bool = false
    /// Non-nil when a repository operation fails — consumers may observe this.
    private(set) var lastError: String?

    // MARK: - Dependency

    private let repository: NotebookRepository

    // MARK: - Init

    init(repository: NotebookRepository) {
        self.repository = repository
    }

    // MARK: - Notebook CRUD

    /// Loads all notebooks from SwiftData, sorted by updatedAt desc.
    /// Mirrors the old FileManager JSON decode + sort.
    func loadNotebooks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let entities = try repository.fetchAllNotebooks()
            notebooks = entities.map { Notebook(from: $0) }
        } catch {
            lastError = error.localizedDescription
            notebooks = []
        }
    }

    /// Creates a new notebook with one first page.
    @discardableResult
    func createNotebook(title: String, coverColor: UInt64) async -> Notebook {
        do {
            let entity = try repository.createNotebook(
                title: title,
                coverColor: Int64(bitPattern: coverColor)
            )
            let nb = Notebook(from: entity)
            // Prepend to in-memory list to reflect updatedAt-desc ordering
            notebooks.insert(nb, at: 0)
            return nb
        } catch {
            lastError = error.localizedDescription
            // Return a transient notebook so callers don't crash; it won't be persisted
            return Notebook(title: title, coverColor: coverColor)
        }
    }

    /// Deletes a notebook and all its pages and canvas files.
    func deleteNotebook(id: UUID) async {
        notebooks.removeAll { $0.id == id }
        do {
            try repository.deleteNotebook(id: id.uuidString)
        } catch {
            lastError = error.localizedDescription
            // Reload to restore consistent state after failure
            await loadNotebooks()
        }
    }

    /// Bumps updatedAt on a notebook (e.g. after saving canvas data).
    func touchNotebook(id: UUID) async {
        do {
            try repository.touchNotebook(id: id.uuidString)
            // Reflect the updated timestamp in the in-memory list
            if let entity = try repository.fetchNotebook(id: id.uuidString),
               let idx = notebooks.firstIndex(where: { $0.id == id }) {
                notebooks[idx].updatedAt = Date(millisSince1970: entity.updatedAt)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Page operations

    /// Loads pages for a notebook from SwiftData, sorted by pageIndex.
    /// If none exist yet (e.g. migrated data gap), creates the first page.
    func loadPages(for notebookId: UUID) async -> [NotebookPage] {
        do {
            let entities = try repository.fetchPages(notebookId: notebookId.uuidString)
            if !entities.isEmpty {
                return entities.map { NotebookPage(from: $0) }
            }
            // No pages found — create the first page (graceful migration path)
            if let pageEntity = try repository.addPage(
                notebookId: notebookId.uuidString,
                template: "ruled"
            ) {
                return [NotebookPage(from: pageEntity)]
            }
            return []
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    /// Adds a new page to a notebook and returns it.
    func addPage(to notebookId: UUID, template: PaperTemplate = .ruled) async -> NotebookPage {
        do {
            if let entity = try repository.addPage(
                notebookId: notebookId.uuidString,
                template: template.rawValue
            ) {
                // Refresh in-memory pageCount
                if let idx = notebooks.firstIndex(where: { $0.id == notebookId }),
                   let nb = try repository.fetchNotebook(id: notebookId.uuidString) {
                    notebooks[idx].pageCount = nb.pageCount
                    notebooks[idx].updatedAt = Date(millisSince1970: nb.updatedAt)
                }
                return NotebookPage(from: entity)
            }
        } catch {
            lastError = error.localizedDescription
        }
        // Fallback — should not happen in practice
        return NotebookPage(notebookId: notebookId, pageIndex: 0, template: template)
    }

    // MARK: - PencilKit canvas data (binary — delegated to StrokeFileStorage)

    /// Saves PencilKit PKDrawing bytes to disk and bumps notebook updatedAt.
    func saveCanvasData(_ data: Data, notebookId: UUID, pageId: UUID) async {
        do {
            try repository.saveCanvasData(
                data,
                notebookId: notebookId.uuidString,
                pageId: pageId.uuidString
            )
            // Refresh in-memory updatedAt
            if let entity = try repository.fetchNotebook(id: notebookId.uuidString),
               let idx = notebooks.firstIndex(where: { $0.id == notebookId }) {
                notebooks[idx].updatedAt = Date(millisSince1970: entity.updatedAt)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Loads PencilKit PKDrawing bytes from disk (synchronous — already cached).
    func loadCanvasData(notebookId: UUID, pageId: UUID) -> Data? {
        repository.loadCanvasData(
            notebookId: notebookId.uuidString,
            pageId: pageId.uuidString
        )
    }
}

// MARK: - Date helper

private extension Date {
    /// Constructs a Date from milliseconds-since-epoch (Android System.currentTimeMillis()).
    init(millisSince1970: Int64) {
        self.init(timeIntervalSince1970: Double(millisSince1970) / 1000.0)
    }
}

// MARK: - Notebook domain ↔ NotebookEntity mapping

extension Notebook {
    /// Constructs a domain Notebook from a SwiftData NotebookEntity.
    init(from entity: NotebookEntity) {
        self.init(
            id: UUID(uuidString: entity.id) ?? UUID(),
            title: entity.title,
            coverColor: UInt64(bitPattern: entity.coverColor),
            createdAt: Date(timeIntervalSince1970: Double(entity.createdAt) / 1000.0),
            updatedAt: Date(timeIntervalSince1970: Double(entity.updatedAt) / 1000.0),
            pageCount: entity.pageCount
        )
    }
}

// MARK: - NotebookPage domain ↔ PageEntity mapping

extension NotebookPage {
    /// Constructs a domain NotebookPage from a SwiftData PageEntity.
    init(from entity: PageEntity) {
        let notebookUUID = UUID(uuidString: entity.notebookId) ?? UUID()
        self.init(
            id: UUID(uuidString: entity.id) ?? UUID(),
            notebookId: notebookUUID,
            pageIndex: entity.pageIndex,
            template: PaperTemplate(rawValue: entity.template) ?? .blank
        )
    }
}
