import Foundation
import SwiftData

// MARK: - PageEntity (SwiftData)
// Mirrors com.bymav.medcoach.data.local.entity.PageEntity (Android Room).
// Table: pages — foreign key notebookId with CASCADE on delete.
// thumbnailPath is nullable, matching the Android entity.

@Model
final class PageEntity {
    @Attribute(.unique) var id: String
    // Relationship back-reference (many-to-one).
    // Stored as a proper SwiftData relationship rather than a bare String FK,
    // which gives us automatic cascade semantics via NotebookEntity.pages.
    var notebook: NotebookEntity?
    var notebookId: String        // kept for quick queries without join
    var pageIndex: Int
    var template: String          // PaperTemplate.rawValue e.g. "blank", "ruled"
    var thumbnailPath: String?    // file-system path to a cached JPEG thumbnail

    init(
        id: String,
        notebook: NotebookEntity,
        pageIndex: Int,
        template: String = "ruled",
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.notebook = notebook
        self.notebookId = notebook.id
        self.pageIndex = pageIndex
        self.template = template
        self.thumbnailPath = thumbnailPath
    }
}
