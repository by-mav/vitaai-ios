import Foundation

// MARK: - StrokeFileStorage
// Mirrors com.bymav.medcoach.data.local.storage.StrokeFileStorage (Android).
// Binary stroke data (PencilKit PKDrawing serialisation) lives in the
// Application Support directory under notes/<notebookId>/<pageId>/canvas.pkdata.
// This deliberately matches the existing NotebookStore FileManager layout so
// that canvas files written before the SwiftData migration are not lost.
//
// Directory layout:
//   <AppSupport>/notes/<notebookId>/           — notebook directory
//   <AppSupport>/notes/<notebookId>/<pageId>/  — page directory
//   <AppSupport>/notes/<notebookId>/<pageId>/canvas.pkdata  — PencilKit binary

final class StrokeFileStorage {

    // MARK: - Root URL

    // Use Application Support (not Documents) so the OS does not expose raw
    // binary blobs to the user via Files.app — mirrors Android's Context.filesDir.
    private let rootURL: URL

    init() {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to tmp instead of crashing — extremely rare edge case
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("notes", isDirectory: true)
            rootURL = fallback
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return
        }
        rootURL = appSupport.appendingPathComponent("notes", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Canvas data (PencilKit PKDrawing binary)

    func saveCanvasData(_ data: Data, notebookId: String, pageId: String) throws {
        let dir = pageDirectory(notebookId: notebookId, pageId: pageId)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent("canvas.pkdata")
        try data.write(to: url, options: .atomic)
    }

    func loadCanvasData(notebookId: String, pageId: String) -> Data? {
        let url = pageDirectory(notebookId: notebookId, pageId: pageId)
            .appendingPathComponent("canvas.pkdata")
        return try? Data(contentsOf: url)
    }

    // MARK: - Delete entire notebook directory

    /// Removes all stroke files for a notebook.
    /// Called from NotebookRepository.deleteNotebook() — mirrors
    /// StrokeFileStorage.deleteNotebookStrokes() on Android.
    func deleteNotebookStrokes(notebookId: String) throws {
        let dir = notebookDirectory(notebookId: notebookId)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Private helpers

    private func notebookDirectory(notebookId: String) -> URL {
        rootURL.appendingPathComponent(notebookId, isDirectory: true)
    }

    private func pageDirectory(notebookId: String, pageId: String) -> URL {
        notebookDirectory(notebookId: notebookId)
            .appendingPathComponent(pageId, isDirectory: true)
    }
}
