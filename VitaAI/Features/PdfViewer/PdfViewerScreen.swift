import SwiftUI
import PDFKit
import PencilKit

// MARK: - PdfViewerScreen

/// Full-screen PDF viewer with GoodNotes-level annotation support.
/// Uses PDFKit page rendering + PencilKit overlay for native Apple Pencil ink.
/// Shapes and text use SwiftUI overlays on top.
struct PdfViewerScreen: View {
    let url: URL
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel = PdfViewerViewModel()
    @State private var selectedPage: Int = 0
    @State private var showExportSheet: Bool = false
    @State private var exportedURL: URL? = nil

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .tint(VitaColors.accent)
            } else if let document = viewModel.document, viewModel.pageCount > 0 {
                mainContent(document: document)
            } else {
                errorView
            }
        }
        .task { await viewModel.load(url: url, tokenStore: container.tokenStore) }
        .onDisappear { viewModel.forceSave() }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showExportSheet) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            PdfTopBar(
                fileName: viewModel.fileName,
                currentPage: viewModel.currentPage + 1,
                pageCount: viewModel.pageCount,
                isSaving: viewModel.isSaving,
                showThumbnailToggle: viewModel.pageCount > 1,
                onBack: {
                    viewModel.forceSave()
                    onBack()
                },
                onToggleThumbnails: viewModel.toggleThumbnails,
                onExport: {
                    Task { await exportPDF(document: document) }
                }
            )

            // Annotation toolbar right below top bar
            AnnotationToolbar(
                isDrawMode: viewModel.isDrawMode,
                selectedTool: viewModel.selectedTool,
                selectedColor: viewModel.selectedColor,
                strokeWidth: viewModel.strokeWidth,
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                onToggleDrawMode: viewModel.toggleDrawMode,
                onSelectTool: viewModel.selectTool,
                onSelectColor: viewModel.setColor,
                onStrokeWidthChange: viewModel.setStrokeWidth,
                onUndo: viewModel.undo,
                onRedo: viewModel.redo,
                onShapeMode: viewModel.selectTool
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            ZStack(alignment: .leading) {
                TabView(selection: $selectedPage) {
                    ForEach(0..<viewModel.pageCount, id: \.self) { pageIndex in
                        PdfPageView(
                            document: document,
                            pageIndex: pageIndex,
                            viewModel: viewModel,
                            isCurrentPage: pageIndex == viewModel.currentPage
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedPage) { newPage in
                    viewModel.setCurrentPage(newPage)
                }

                PageThumbnailSidebar(
                    document: document,
                    pageCount: viewModel.pageCount,
                    currentPage: viewModel.currentPage,
                    isVisible: viewModel.showThumbnails,
                    onPageSelected: { page in
                        selectedPage = page
                    }
                )
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Não foi possível abrir o PDF")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Button("Voltar", action: onBack)
                .foregroundStyle(VitaColors.accent)
        }
    }

    // MARK: - Export

    private func exportPDF(document: PDFDocument) async {
        // TODO: Flatten PencilKit drawings + shapes + text into exported PDF
        // For now, export PencilKit drawings per page
        guard let url = try? await PdfPencilKitExporter.export(
            document: document,
            pageCount: viewModel.pageCount,
            getDrawing: { viewModel.drawing(for: $0) },
            getShapes: { viewModel.shapes(for: $0) },
            getTexts: { viewModel.texts(for: $0) }
        ) else { return }
        self.exportedURL = url
        showExportSheet = true
    }
}

// MARK: - PDF Page View (PencilKit overlay)

private struct PdfPageView: View {
    let document: PDFDocument
    let pageIndex: Int
    @Bindable var viewModel: PdfViewerViewModel
    let isCurrentPage: Bool

    @State private var pageImage: UIImage? = nil
    @State private var canvasKey: UUID = UUID()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = pageImage {
                    ZStack {
                        // PDF page as background
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()

                        // PencilKit canvas overlay (only on current page for performance)
                        if isCurrentPage {
                            PdfPencilKitCanvas(
                                viewModel: viewModel,
                                pageIndex: pageIndex
                            )
                            .id(canvasKey)
                            .allowsHitTesting(viewModel.isDrawMode && viewModel.selectedTool.isInkTool || viewModel.isDrawMode && viewModel.selectedTool == .eraser)
                        }

                        // Shape overlay
                        ShapeOverlay(
                            shapes: isCurrentPage ? viewModel.shapeAnnotations : viewModel.shapes(for: pageIndex),
                            selectedTool: viewModel.selectedTool,
                            selectedColor: viewModel.selectedColor,
                            strokeWidth: viewModel.strokeWidth,
                            isActive: viewModel.isDrawMode && isCurrentPage && viewModel.selectedTool.isShapeTool,
                            onAddShape: { viewModel.addShapeAnnotation($0) }
                        )

                        // Text annotation overlay
                        TextAnnotationOverlay(
                            annotations: isCurrentPage ? viewModel.textAnnotations : viewModel.texts(for: pageIndex),
                            selectedColor: viewModel.selectedColor,
                            isActive: viewModel.isDrawMode && isCurrentPage && viewModel.selectedTool == .text,
                            onAddText: { viewModel.addTextAnnotation($0) },
                            onUpdateText: { viewModel.updateTextAnnotation($0) },
                            onRemoveText: { viewModel.removeTextAnnotation(id: $0) }
                        )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                } else {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: pageIndex) {
            guard pageImage == nil else { return }
            pageImage = await renderPage()
        }
    }

    private func renderPage() async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let page = document.page(at: pageIndex) else { return nil }
            let targetWidth: CGFloat = UIScreen.main.bounds.width * UIScreen.main.scale
            let pageRect = page.bounds(for: .cropBox)
            let scl = targetWidth / pageRect.width
            let renderSize = CGSize(width: targetWidth, height: pageRect.height * scl)

            let renderer = UIGraphicsImageRenderer(size: renderSize)
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderSize))

                let cgCtx = ctx.cgContext
                // PDF coordinate system is bottom-left origin; flip to UIKit top-left
                cgCtx.translateBy(x: 0, y: renderSize.height)
                cgCtx.scaleBy(x: scl, y: -scl)
                page.draw(with: .cropBox, to: cgCtx)
            }
        }.value
    }
}

// MARK: - PencilKit Canvas for PDF (UIViewRepresentable)

private struct PdfPencilKitCanvas: UIViewRepresentable {
    @Bindable var viewModel: PdfViewerViewModel
    let pageIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.isScrollEnabled = false
        canvas.minimumZoomScale = 1.0
        canvas.maximumZoomScale = 1.0

        // Load existing drawing
        canvas.drawing = viewModel.drawing(for: pageIndex)

        // Apply current tool
        canvas.tool = viewModel.pkTool

        // Observe undo manager
        let um = canvas.undoManager
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerChanged),
            name: .NSUndoManagerDidCloseUndoGroup, object: um
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerChanged),
            name: .NSUndoManagerDidUndoChange, object: um
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerChanged),
            name: .NSUndoManagerDidRedoChange, object: um
        )

        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = viewModel.pkTool

        // Undo/redo triggers from toolbar
        if context.coordinator.lastUndoTrigger != viewModel.undoTrigger {
            context.coordinator.lastUndoTrigger = viewModel.undoTrigger
            canvas.undoManager?.undo()
        }
        if context.coordinator.lastRedoTrigger != viewModel.redoTrigger {
            context.coordinator.lastRedoTrigger = viewModel.redoTrigger
            canvas.undoManager?.redo()
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PdfPencilKitCanvas
        weak var canvas: PKCanvasView?
        var lastUndoTrigger: Int = 0
        var lastRedoTrigger: Int = 0

        init(_ parent: PdfPencilKitCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.viewModel.updateDrawing(canvasView.drawing, for: parent.pageIndex)
            updateUndoState(canvasView)
        }

        @objc func undoManagerChanged() {
            guard let canvas else { return }
            updateUndoState(canvas)
        }

        private func updateUndoState(_ canvas: PKCanvasView) {
            parent.viewModel.canUndo = canvas.undoManager?.canUndo ?? false
            parent.viewModel.canRedo = canvas.undoManager?.canRedo ?? false
        }
    }
}

// MARK: - PencilKit PDF Exporter

enum PdfPencilKitExporter {
    static func export(
        document: PDFDocument,
        pageCount: Int,
        getDrawing: @escaping (Int) -> PKDrawing,
        getShapes: @escaping (Int) -> [ShapeAnnotation],
        getTexts: @escaping (Int) -> [TextAnnotation]
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
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

                // Layer 2: PencilKit drawing
                let drawing = getDrawing(pageIndex)
                let pkImage = drawing.image(from: CGRect(origin: .zero, size: renderSize), scale: 1.0)
                pkImage.draw(in: CGRect(origin: .zero, size: renderSize))

                // Layer 3: Shapes
                let shapes = getShapes(pageIndex)
                PdfExporter.drawShapesPublic(shapes, in: ctx, scale: scale)

                // Layer 4: Text
                let texts = getTexts(pageIndex)
                PdfExporter.drawTextsPublic(texts, in: ctx, scale: scale)
            }

            UIGraphicsEndPDFContext()
            try (data as Data).write(to: tempURL)
            return tempURL
        }.value
    }
}

// MARK: - Top Bar

private struct PdfTopBar: View {
    let fileName: String
    let currentPage: Int
    let pageCount: Int
    let isSaving: Bool
    let showThumbnailToggle: Bool
    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
            }

            Text(fileName)
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSaving {
                Text("Salvando…")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            if pageCount > 0 {
                Text("\(currentPage) / \(pageCount)")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
            }

            if showThumbnailToggle {
                Button(action: onToggleThumbnails) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(VitaColors.surfaceCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(VitaColors.surfaceBorder),
            alignment: .bottom
        )
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
