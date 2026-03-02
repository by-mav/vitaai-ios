import Foundation
import SwiftData

// MARK: - NotebookRepository
// Mirrors com.bymav.medcoach.data.repository.NotebookRepository (Android).
//
// Responsibilities:
//   • CRUD for NotebookEntity and PageEntity via SwiftData ModelContext
//   • CRUD for AnnotationEntity (PDF ink annotations) via SwiftData ModelContext
//   • Delegates canvas binary storage to StrokeFileStorage (PencilKit PKDrawing)
//
// Threading: all methods are async and run on the Swift concurrency cooperative
// thread pool. The ModelContext is constructed from the container — callers must
// ensure they pass in a context appropriate for their actor isolation (i.e. the
// @MainActor context for UI code, or a background context for background saves).

final class NotebookRepository {

    // MARK: Dependencies

    private let context: ModelContext
    let strokeStorage: StrokeFileStorage

    // MARK: Init

    init(context: ModelContext, strokeStorage: StrokeFileStorage = StrokeFileStorage()) {
        self.context = context
        self.strokeStorage = strokeStorage
    }

    // MARK: - Notebook queries

    /// Returns all notebooks sorted by updatedAt descending.
    /// Mirrors NotebookDao.getAllNotebooks() Flow.
    func fetchAllNotebooks() throws -> [NotebookEntity] {
        var descriptor = FetchDescriptor<NotebookEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.pages]
        return try context.fetch(descriptor)
    }

    /// Returns a single notebook by its UUID string PK, or nil.
    /// Mirrors NotebookDao.getById().
    func fetchNotebook(id: String) throws -> NotebookEntity? {
        var descriptor = FetchDescriptor<NotebookEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Page queries

    /// Returns pages for a notebook sorted by pageIndex ascending.
    /// Mirrors PageDao.getPagesForNotebook() Flow.
    func fetchPages(notebookId: String) throws -> [PageEntity] {
        let descriptor = FetchDescriptor<PageEntity>(
            predicate: #Predicate { $0.notebookId == notebookId },
            sortBy: [SortDescriptor(\.pageIndex)]
        )
        return try context.fetch(descriptor)
    }

    /// Returns a single page by its UUID string PK, or nil.
    /// Mirrors PageDao.getById().
    func fetchPage(id: String) throws -> PageEntity? {
        var descriptor = FetchDescriptor<PageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Annotation queries

    /// Returns the annotation for a specific PDF file + page combination.
    /// Mirrors AnnotationDao.getAnnotation().
    func fetchAnnotation(pdfFileHash: String, pageNumber: Int) throws -> AnnotationEntity? {
        var descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate {
                $0.pdfFileHash == pdfFileHash && $0.pageNumber == pageNumber
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns all distinct PDF file hashes that have at least one annotation.
    /// Mirrors AnnotationDao.getAllAnnotatedFiles().
    func fetchAllAnnotatedFileHashes() throws -> [String] {
        let all = try context.fetch(FetchDescriptor<AnnotationEntity>())
        // Deduplicate while preserving insertion order.
        var seen = Set<String>()
        return all.compactMap { entity -> String? in
            guard !seen.contains(entity.pdfFileHash) else { return nil }
            seen.insert(entity.pdfFileHash)
            return entity.pdfFileHash
        }
    }

    // MARK: - Create notebook

    /// Creates a new notebook with one blank page.
    /// Mirrors NotebookRepository.createNotebook() on Android.
    @discardableResult
    func createNotebook(title: String, coverColor: Int64) throws -> NotebookEntity {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let notebookId = UUID().uuidString
        let pageId = UUID().uuidString

        let notebook = NotebookEntity(
            id: notebookId,
            title: title,
            coverColor: coverColor,
            createdAt: now,
            updatedAt: now,
            pageCount: 1
        )
        context.insert(notebook)

        let firstPage = PageEntity(
            id: pageId,
            notebook: notebook,
            pageIndex: 0,
            template: "ruled"
        )
        context.insert(firstPage)
        notebook.pages.append(firstPage)

        try context.save()
        return notebook
    }

    // MARK: - Update notebook

    /// Updates notebook title and/or coverColor and bumps updatedAt.
    /// Mirrors NotebookRepository.updateNotebook().
    func updateNotebook(id: String, title: String? = nil, coverColor: Int64? = nil) throws {
        guard let entity = try fetchNotebook(id: id) else { return }
        if let title = title { entity.title = title }
        if let coverColor = coverColor { entity.coverColor = coverColor }
        entity.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try context.save()
    }

    /// Bumps the updatedAt timestamp for a notebook (touch semantics).
    /// Mirrors the touch-updatedAt pattern in NotebookRepository.saveStrokes().
    func touchNotebook(id: String) throws {
        guard let entity = try fetchNotebook(id: id) else { return }
        entity.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try context.save()
    }

    // MARK: - Delete notebook

    /// Deletes the notebook + all its pages (CASCADE) and removes stroke files.
    /// Mirrors NotebookRepository.deleteNotebook().
    func deleteNotebook(id: String) throws {
        guard let entity = try fetchNotebook(id: id) else { return }
        context.delete(entity)
        try context.save()
        // Remove binary canvas files — best-effort, non-fatal
        try? strokeStorage.deleteNotebookStrokes(notebookId: id)
    }

    // MARK: - Add page

    /// Appends a new page to an existing notebook and updates pageCount.
    /// Mirrors NotebookRepository (add page path via PageDao).
    @discardableResult
    func addPage(notebookId: String, template: String = "ruled") throws -> PageEntity? {
        guard let notebook = try fetchNotebook(id: notebookId) else { return nil }
        let existingPages = try fetchPages(notebookId: notebookId)
        let nextIndex = existingPages.count

        let page = PageEntity(
            id: UUID().uuidString,
            notebook: notebook,
            pageIndex: nextIndex,
            template: template
        )
        context.insert(page)
        notebook.pages.append(page)
        notebook.pageCount = nextIndex + 1
        notebook.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)

        try context.save()
        return page
    }

    // MARK: - Canvas data (binary — delegated to StrokeFileStorage)

    /// Saves PencilKit PKDrawing binary data for a page.
    /// Also touches the parent notebook's updatedAt.
    func saveCanvasData(_ data: Data, notebookId: String, pageId: String) throws {
        try strokeStorage.saveCanvasData(data, notebookId: notebookId, pageId: pageId)
        try touchNotebook(id: notebookId)
    }

    func loadCanvasData(notebookId: String, pageId: String) -> Data? {
        strokeStorage.loadCanvasData(notebookId: notebookId, pageId: pageId)
    }

    // MARK: - PDF Annotations (upsert / delete)

    /// Upserts an annotation for a PDF page.
    /// Mirrors AnnotationDao.upsert() (INSERT OR REPLACE).
    func upsertAnnotation(pdfFileHash: String, pageNumber: Int, strokesJson: String) throws {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if let existing = try fetchAnnotation(pdfFileHash: pdfFileHash, pageNumber: pageNumber) {
            existing.strokesJson = strokesJson
            existing.updatedAt = now
        } else {
            let entity = AnnotationEntity(
                pdfFileHash: pdfFileHash,
                pageNumber: pageNumber,
                strokesJson: strokesJson,
                createdAt: now,
                updatedAt: now
            )
            context.insert(entity)
        }
        try context.save()
    }

    /// Deletes all annotations for a PDF file.
    /// Mirrors AnnotationDao.deleteAllForFile().
    func deleteAllAnnotations(pdfFileHash: String) throws {
        let descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate { $0.pdfFileHash == pdfFileHash }
        )
        let entities = try context.fetch(descriptor)
        entities.forEach { context.delete($0) }
        try context.save()
    }
}
