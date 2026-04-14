import SwiftUI
import PDFKit
import PencilKit

@MainActor
@Observable
final class PdfViewerViewModel {

    // MARK: - Document state
    var document: PDFDocument?
    var pageCount: Int = 0
    var currentPage: Int = 0
    var fileName: String = ""
    var isLoading: Bool = true
    var isSaving: Bool = false

    // MARK: - Annotation mode
    var isDrawMode: Bool = false
    var selectedTool: AnnotationTool = .pen
    var selectedColor: Color = VitaColors.accent
    var strokeWidth: CGFloat = 4

    // MARK: - PencilKit drawings per page
    private var pageDrawings: [Int: PKDrawing] = [:]

    // MARK: - Shape/text annotations per page (non-PencilKit)
    private var pageTextAnnotations: [Int: [TextAnnotation]] = [:]
    private var pageShapeAnnotations: [Int: [ShapeAnnotation]] = [:]

    // MARK: - Current page hot cache
    var textAnnotations: [TextAnnotation] = []
    var shapeAnnotations: [ShapeAnnotation] = []

    // MARK: - Undo/Redo (delegated to PKCanvasView's UndoManager)
    var canUndo: Bool = false
    var canRedo: Bool = false
    var undoTrigger: Int = 0
    var redoTrigger: Int = 0

    // MARK: - UI state
    var showThumbnails: Bool = false

    private var fileHash: String = ""
    private var saveTask: Task<Void, Never>?

    // MARK: - Load

    func load(url: URL, tokenStore: TokenStore? = nil) async {
        print("[PdfViewer] load called, url=%@, hasTokenStore=%@", url.absoluteString, tokenStore != nil ? "YES" : "NO")
        fileName = url.deletingPathExtension().lastPathComponent
        fileHash = computeHash(url.absoluteString)

        // If URL points to our API, fetch with auth header
        if let tokenStore, url.absoluteString.contains("/api/documents/") {
            do {
                let token = await tokenStore.token
                var request = URLRequest(url: url)
                if let token {
                    request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse {
                    print("[PdfViewer] HTTP %d, bytes: %d, contentType: %@", httpResp.statusCode, data.count, httpResp.mimeType ?? "nil")
                    if httpResp.statusCode == 200 {
                        let pdf = PDFDocument(data: data)
                        print("[PdfViewer] PDFDocument created: %@, pages: %d", pdf != nil ? "YES" : "NO", pdf?.pageCount ?? 0)
                        document = pdf
                    }
                }
            } catch {
                print("[PdfViewer] Auth fetch failed: %@", error.localizedDescription)
            }
        } else {
            document = PDFDocument(url: url)
        }

        pageCount = document?.pageCount ?? 0
        isLoading = false
        loadAnnotations(for: 0)
    }

    // MARK: - Page Navigation

    func setCurrentPage(_ page: Int) {
        guard page != currentPage else { return }
        saveCurrentPage()
        currentPage = page
        loadAnnotations(for: page)
    }

    // MARK: - Draw Mode

    func toggleDrawMode() { isDrawMode.toggle() }

    func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
        isDrawMode = true
    }

    func setColor(_ color: Color) { selectedColor = color }
    func setStrokeWidth(_ width: CGFloat) { strokeWidth = width }

    // MARK: - PencilKit Drawing

    func drawing(for page: Int) -> PKDrawing {
        pageDrawings[page] ?? PKDrawing()
    }

    func updateDrawing(_ drawing: PKDrawing, for page: Int) {
        pageDrawings[page] = drawing
        scheduleSave()
    }

    // MARK: - PencilKit tool

    var pkTool: PKTool {
        let uiColor = UIColor(selectedColor)
        switch selectedTool {
        case .pen:
            return PKInkingTool(.pen, color: uiColor, width: strokeWidth)
        case .highlighter:
            return PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.35), width: strokeWidth * 3)
        case .eraser:
            return PKEraserTool(.vector)
        default:
            return PKInkingTool(.pen, color: uiColor, width: strokeWidth)
        }
    }

    // MARK: - Undo/Redo

    func undo() { undoTrigger += 1 }
    func redo() { redoTrigger += 1 }

    // MARK: - Text Annotations

    func addTextAnnotation(_ ann: TextAnnotation) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        list.append(ann)
        pageTextAnnotations[page] = list
        textAnnotations = list
        scheduleSave()
    }

    func updateTextAnnotation(_ ann: TextAnnotation) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        if let idx = list.firstIndex(where: { $0.id == ann.id }) {
            list[idx] = ann
            pageTextAnnotations[page] = list
            textAnnotations = list
            scheduleSave()
        }
    }

    func removeTextAnnotation(id: UUID) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        list.removeAll { $0.id == id }
        pageTextAnnotations[page] = list
        textAnnotations = list
        scheduleSave()
    }

    // MARK: - Shape Annotations

    func addShapeAnnotation(_ ann: ShapeAnnotation) {
        let page = currentPage
        var list = pageShapeAnnotations[page, default: []]
        list.append(ann)
        pageShapeAnnotations[page] = list
        shapeAnnotations = list
        scheduleSave()
    }

    // MARK: - Thumbnails

    func toggleThumbnails() { showThumbnails.toggle() }

    // MARK: - Accessors for all pages (export)

    func texts(for page: Int) -> [TextAnnotation] { pageTextAnnotations[page, default: []] }
    func shapes(for page: Int) -> [ShapeAnnotation] { pageShapeAnnotations[page, default: []] }

    // MARK: - Force Save (on dismiss)

    func forceSave() {
        saveTask?.cancel()
        saveCurrentPage()
        for page in 0..<pageCount {
            performSave(page: page)
        }
    }

    // MARK: - Private

    private func saveCurrentPage() {
        // Text/shape state is already in pageTextAnnotations/pageShapeAnnotations
        // PKDrawing is updated via updateDrawing() from the canvas delegate
    }

    private func scheduleSave() {
        saveTask?.cancel()
        isSaving = true
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            performSave(page: currentPage)
            isSaving = false
        }
    }

    private func loadAnnotations(for page: Int) {
        guard !fileHash.isEmpty else { return }
        let key = annotationKey(page: page)

        // Load PencilKit drawing
        if let drawingData = UserDefaults.standard.data(forKey: key + "_pk"),
           let drawing = try? PKDrawing(data: drawingData) {
            pageDrawings[page] = drawing
        }

        // Load text/shape annotations
        if let data = UserDefaults.standard.data(forKey: key + "_meta"),
           let meta = try? JSONDecoder().decode(PageMetaAnnotations.self, from: data) {
            pageTextAnnotations[page] = meta.textAnnotations
            pageShapeAnnotations[page] = meta.shapeAnnotations
        }

        if page == currentPage {
            textAnnotations = pageTextAnnotations[page, default: []]
            shapeAnnotations = pageShapeAnnotations[page, default: []]
        }
    }

    private func performSave(page: Int) {
        guard !fileHash.isEmpty else { return }
        let key = annotationKey(page: page)

        // Save PencilKit drawing
        if let drawing = pageDrawings[page] {
            UserDefaults.standard.set(drawing.dataRepresentation(), forKey: key + "_pk")
        }

        // Save text/shape annotations
        let meta = PageMetaAnnotations(
            textAnnotations: pageTextAnnotations[page, default: []],
            shapeAnnotations: pageShapeAnnotations[page, default: []]
        )
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(data, forKey: key + "_meta")
        }
    }

    private func annotationKey(page: Int) -> String { "vita_pdf_ann_\(fileHash)_p\(page)" }

    private func computeHash(_ input: String) -> String {
        var hash: UInt64 = 5381
        for scalar in input.unicodeScalars {
            hash = (hash &<< 5) &+ hash &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Meta annotations (text + shapes, non-PencilKit)

private struct PageMetaAnnotations: Codable {
    var textAnnotations: [TextAnnotation]
    var shapeAnnotations: [ShapeAnnotation]
}
