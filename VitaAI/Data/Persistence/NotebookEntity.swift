import Foundation
import SwiftData

// MARK: - NotebookEntity (SwiftData)
// Mirrors com.bymav.medcoach.data.local.entity.NotebookEntity (Android Room).
// Table: notebooks — fields: id, title, coverColor, createdAt, updatedAt, pageCount

@Model
final class NotebookEntity {
    // @Attribute(.unique) on a String PK mirrors Room's @PrimaryKey
    @Attribute(.unique) var id: String
    var title: String
    // Stored as Int64 to match Android's Long ARGB packing (0xFFRRGGBB)
    var coverColor: Int64
    // Milliseconds since epoch, matching Android System.currentTimeMillis()
    var createdAt: Int64
    var updatedAt: Int64
    var pageCount: Int

    // Inverse relationship — SwiftData cascades deletes automatically when
    // cascade rule is set on the pages side.
    @Relationship(deleteRule: .cascade, inverse: \PageEntity.notebook)
    var pages: [PageEntity] = []

    init(
        id: String,
        title: String,
        coverColor: Int64,
        createdAt: Int64,
        updatedAt: Int64,
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.coverColor = coverColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
    }
}
