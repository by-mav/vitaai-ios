import Foundation
import SwiftData

// MARK: - AnnotationEntity (SwiftData)
// Mirrors com.bymav.medcoach.data.local.entity.AnnotationEntity (Android Room).
// Table: pdf_annotations — composite index on (pdfFileHash, pageNumber).
// strokesJson stores serialised stroke data for PDF page ink annotations.

@Model
final class AnnotationEntity {
    // Auto-generated integer primary key (mirrors Room autoGenerate = true).
    // SwiftData uses a synthesised PersistentIdentifier, so we keep a manual
    // auto-increment surrogate only for cross-platform parity logging; it is
    // NOT used as a lookup key — we always query by (pdfFileHash, pageNumber).
    var pdfFileHash: String
    var pageNumber: Int
    var strokesJson: String       // JSON-encoded array of serialised strokes
    var createdAt: Int64          // millis since epoch
    var updatedAt: Int64          // millis since epoch

    init(
        pdfFileHash: String,
        pageNumber: Int,
        strokesJson: String,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.pdfFileHash = pdfFileHash
        self.pageNumber = pageNumber
        self.strokesJson = strokesJson
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
