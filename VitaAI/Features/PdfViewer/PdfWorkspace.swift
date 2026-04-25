import Foundation
import SwiftUI

/// One open PDF in the workspace (= one tab).
struct OpenPdfDocument: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    var title: String

    init(id: UUID = UUID(), url: URL, title: String? = nil) {
        self.id = id
        self.url = url
        self.title = (title?.isEmpty == false ? title! : url.lastPathComponent)
    }
}

/// Persisted multi-document state for the PDF viewer (Goodnotes-style tabs).
/// Lives in UserDefaults so a user's open tabs survive app relaunch.
@Observable
final class PdfWorkspaceState {
    private static let storageKey = "pdf_workspace_state.v1"
    private static let maxTabs = 12  // Hard cap pra evitar abuso de memória

    var openDocs: [OpenPdfDocument] = []
    var activeId: UUID?

    init() {
        load()
    }

    var activeDoc: OpenPdfDocument? {
        guard let activeId else { return openDocs.first }
        return openDocs.first(where: { $0.id == activeId }) ?? openDocs.first
    }

    /// Open a URL as a tab. If a tab with the same URL exists, just activates it.
    /// Returns the (existing or new) tab id so the caller can optionally focus it.
    @discardableResult
    func open(url: URL, title: String? = nil) -> UUID {
        if let existing = openDocs.first(where: { $0.url == url }) {
            activeId = existing.id
            persist()
            return existing.id
        }
        let doc = OpenPdfDocument(url: url, title: title)
        if openDocs.count >= Self.maxTabs {
            // Drop the oldest non-active tab
            if let oldestId = openDocs.first(where: { $0.id != activeId })?.id {
                openDocs.removeAll(where: { $0.id == oldestId })
            }
        }
        openDocs.append(doc)
        activeId = doc.id
        persist()
        return doc.id
    }

    /// Close a tab. If it was the active one, picks the previous (or next) tab.
    /// Returns true if any tab remains open.
    @discardableResult
    func close(id: UUID) -> Bool {
        guard let idx = openDocs.firstIndex(where: { $0.id == id }) else { return !openDocs.isEmpty }
        let wasActive = (id == activeId)
        openDocs.remove(at: idx)
        if wasActive {
            // Prefer the tab that took its slot (idx after remove) → else previous
            if idx < openDocs.count {
                activeId = openDocs[idx].id
            } else if idx > 0 {
                activeId = openDocs[idx - 1].id
            } else {
                activeId = nil
            }
        }
        persist()
        return !openDocs.isEmpty
    }

    func setActive(_ id: UUID) {
        guard openDocs.contains(where: { $0.id == id }) else { return }
        activeId = id
        persist()
    }

    func closeOthers(keep id: UUID) {
        openDocs.removeAll(where: { $0.id != id })
        activeId = id
        persist()
    }

    func closeAll() {
        openDocs.removeAll()
        activeId = nil
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        struct Snapshot: Codable {
            let openDocs: [OpenPdfDocument]
            let activeId: UUID?
        }
        guard let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        // Filter out tabs whose URL no longer points to a fetchable resource isn't
        // strictly necessary — server resolves /api/documents/:id/file dynamically.
        openDocs = snap.openDocs
        activeId = snap.activeId ?? snap.openDocs.last?.id
    }

    private func persist() {
        struct Snapshot: Codable {
            let openDocs: [OpenPdfDocument]
            let activeId: UUID?
        }
        let snap = Snapshot(openDocs: openDocs, activeId: activeId)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
