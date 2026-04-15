import SwiftUI
import PDFKit
import PencilKit
import UIKit

/// Exports an annotated PDF by flattening PKDrawing annotations onto each page.
enum PdfExporter {

    /// Returns a shareable URL for the exported annotated PDF.
    static func export(
        document: PDFDocument,
        pageCount: Int,
        getDrawing: @escaping @Sendable (Int) -> PKDrawing?
    ) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("annotated_\(UUID().uuidString).pdf")

            let data = NSMutableData()
            UIGraphicsBeginPDFContextToData(data, .zero, nil)

            for pageIndex in 0..<pageCount {
                guard let pdfPage = document.page(at: pageIndex) else { continue }

                let renderWidth: CGFloat = 1080
                let pageRect = pdfPage.bounds(for: .cropBox)
                let scale = renderWidth / pageRect.width
                let renderSize = CGSize(width: renderWidth, height: pageRect.height * scale)

                UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: renderSize), nil)
                guard let ctx = UIGraphicsGetCurrentContext() else { continue }

                // Layer 1: PDF page
                ctx.saveGState()
                ctx.scaleBy(x: scale, y: scale)
                pdfPage.draw(with: .cropBox, to: ctx)
                ctx.restoreGState()

                // Layer 2: PencilKit drawing flattened as image
                if let drawing = getDrawing(pageIndex) {
                    let drawingRect = CGRect(origin: .zero, size: renderSize)
                    let pkImage = drawing.image(from: drawingRect, scale: 1.0)
                    pkImage.draw(in: drawingRect)
                }
            }

            UIGraphicsEndPDFContext()
            try (data as Data).write(to: tempURL)
            return tempURL
        }.value
    }
}
