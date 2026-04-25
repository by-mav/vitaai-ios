import UIKit
import PDFKit

/// Goodnotes-style selection overlay for a PDFAnnotation freeText.
/// Renders a dashed gold border + 8 handles (4 corners + 4 edge midpoints),
/// converts PDF page coords to PDFView coords, and drives drag/resize via
/// UIPanGestureRecognizer + UIPinchGestureRecognizer applied to the underlying
/// annotation.bounds. Forces page redraw via remove/add annotation cycle.
///
/// Lifecycle:
///   - Coordinator instantiates one of these on tap-in-freeText (tap in text mode).
///   - Coordinator removes it on tap-outside or when document closes.
///   - PdfViewerScreen forwards onChange to viewModel.saveHighlights().
final class PdfFreeTextSelectionOverlay: UIView, UIGestureRecognizerDelegate {

    // MARK: - Public callbacks

    /// Fired when drag/resize ends — caller should persist annotation state.
    var onChange: (() -> Void)?
    /// Fired when user double-taps the overlay — caller re-enters edit mode.
    var onEditRequest: (() -> Void)?
    /// Fired when delete affordance triggered (long-press menu, future).
    var onDelete: (() -> Void)?

    // MARK: - Private state

    private weak var pdfView: PDFView?
    private weak var page: PDFPage?
    private let annotation: PDFAnnotation

    private let dashedBorder = CAShapeLayer()
    private var handles: [HandlePosition: HandleView] = [:]
    private var activeHandle: HandlePosition?

    /// Bounds at the start of the active gesture (PDF coords, page space).
    private var startBounds: CGRect = .zero
    /// Bounds at the start of pinch — used to scale uniformly.
    private var pinchStartBounds: CGRect = .zero

    /// CADisplayLink to keep overlay in sync with PDFView scroll/zoom.
    /// PDFKit doesn't expose visible-page change notifications during user pan/pinch,
    /// so we tick every frame while attached. Cheap (~50µs per call).
    private var displayLink: CADisplayLink?

    /// Pixels of padding around the annotation rect to host the handles.
    private static let handlePadding: CGFloat = 12

    // MARK: - Init

    init(annotation: PDFAnnotation, page: PDFPage, pdfView: PDFView) {
        self.annotation = annotation
        self.page = page
        self.pdfView = pdfView
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Dashed gold border layer (matches VitaColors.accent gold).
        dashedBorder.fillColor = UIColor.clear.cgColor
        dashedBorder.strokeColor = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 1.0).cgColor
        dashedBorder.lineWidth = 1.5
        dashedBorder.lineDashPattern = [4, 3]
        layer.addSublayer(dashedBorder)

        // 8 handles
        for position in HandlePosition.allCases {
            let handle = HandleView(position: position)
            addSubview(handle)
            handles[position] = handle
        }

        // Pan: drag (center hit) or resize (handle hit)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        // Pinch: uniform resize
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        // Double-tap: enter edit mode
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        updateFrame()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        displayLink?.invalidate()
        if superview != nil {
            let link = CADisplayLink(target: self, selector: #selector(tickSync))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            displayLink = nil
        }
    }

    @objc private func tickSync() {
        // Skip while user is actively dragging (we update inline) to avoid jitter
        guard activeHandle == nil else { return }
        updateFrame()
    }

    // MARK: - Frame sync

    /// Recomputes self.frame from annotation.bounds (page coords) → PDFView coords,
    /// padded for handles. Must be called whenever PDFView zoom or scroll changes.
    func updateFrame() {
        guard let pdfView, let page else { return }
        let viewRect = pdfView.convert(annotation.bounds, from: page)
        let padded = viewRect.insetBy(dx: -Self.handlePadding, dy: -Self.handlePadding)
        frame = padded
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inner = bounds.insetBy(dx: Self.handlePadding, dy: Self.handlePadding)
        dashedBorder.frame = bounds
        dashedBorder.path = UIBezierPath(rect: inner).cgPath
        for (pos, handle) in handles {
            handle.center = pos.point(in: inner)
        }
    }

    // MARK: - Hit testing

    /// Allow gestures inside our padded area; outside falls through.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.contains(point)
    }

    private func handle(at point: CGPoint) -> HandlePosition? {
        for (pos, handle) in handles {
            if handle.frame.insetBy(dx: -8, dy: -8).contains(point) {
                return pos
            }
        }
        return nil
    }

    // MARK: - Pan (drag + resize)

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let pdfView, let page else { return }

        switch gesture.state {
        case .began:
            let location = gesture.location(in: self)
            activeHandle = handle(at: location)  // nil = center drag
            startBounds = annotation.bounds

        case .changed:
            let translation = gesture.translation(in: pdfView)
            // Convert pixel delta to page coords. PDFView convert handles zoom.
            let zero = pdfView.convert(CGPoint.zero, to: page)
            let delta = pdfView.convert(CGPoint(x: translation.x, y: translation.y), to: page)
            let dxPage = delta.x - zero.x
            let dyPage = delta.y - zero.y
            // PDF Y axis is inverted vs UIKit — translation.y down in view means
            // bounds.minY DECREASES in PDF (page origin bottom-left).
            applyPan(dxPage: dxPage, dyPage: dyPage)
            forceRedraw()
            updateFrame()

        case .ended, .cancelled, .failed:
            activeHandle = nil
            onChange?()

        default:
            break
        }
    }

    private func applyPan(dxPage: CGFloat, dyPage: CGFloat) {
        var newBounds = startBounds
        let minSize: CGFloat = 16

        if let h = activeHandle {
            // Resize: clamp to keep min size + non-negative dimensions
            switch h {
            case .topLeft:
                newBounds.origin.x += dxPage
                newBounds.size.width -= dxPage
                newBounds.size.height += dyPage
            case .top:
                newBounds.size.height += dyPage
            case .topRight:
                newBounds.size.width += dxPage
                newBounds.size.height += dyPage
            case .right:
                newBounds.size.width += dxPage
            case .bottomRight:
                newBounds.size.width += dxPage
                newBounds.origin.y += dyPage
                newBounds.size.height -= dyPage
            case .bottom:
                newBounds.origin.y += dyPage
                newBounds.size.height -= dyPage
            case .bottomLeft:
                newBounds.origin.x += dxPage
                newBounds.size.width -= dxPage
                newBounds.origin.y += dyPage
                newBounds.size.height -= dyPage
            case .left:
                newBounds.origin.x += dxPage
                newBounds.size.width -= dxPage
            }
            // Enforce min size by holding the opposite edge
            if newBounds.width < minSize {
                newBounds.size.width = minSize
                if [.topLeft, .left, .bottomLeft].contains(h) {
                    newBounds.origin.x = startBounds.maxX - minSize
                }
            }
            if newBounds.height < minSize {
                newBounds.size.height = minSize
                if [.bottomLeft, .bottom, .bottomRight].contains(h) {
                    newBounds.origin.y = startBounds.maxY - minSize
                }
            }
        } else {
            // Drag: translate origin only
            newBounds.origin.x += dxPage
            newBounds.origin.y += dyPage
        }

        annotation.bounds = newBounds
        scaleFontIfNeeded(oldBounds: startBounds, newBounds: newBounds)
    }

    /// When user resizes via handles, scale font proportionally so text "grows"
    /// with the box (Goodnotes behavior). Skip when only dragging/translating.
    private func scaleFontIfNeeded(oldBounds: CGRect, newBounds: CGRect) {
        guard activeHandle != nil else { return }
        guard let oldFont = annotation.font else { return }
        let oldDiag = sqrt(oldBounds.width * oldBounds.width + oldBounds.height * oldBounds.height)
        let newDiag = sqrt(newBounds.width * newBounds.width + newBounds.height * newBounds.height)
        guard oldDiag > 0 else { return }
        let scale = newDiag / oldDiag
        let newSize = max(8, min(96, oldFont.pointSize * scale))
        annotation.font = oldFont.withSize(newSize)
    }

    // MARK: - Pinch (uniform resize)

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pinchStartBounds = annotation.bounds
        case .changed:
            let scale = max(0.3, min(4.0, gesture.scale))
            let cx = pinchStartBounds.midX
            let cy = pinchStartBounds.midY
            let newW = pinchStartBounds.width * scale
            let newH = pinchStartBounds.height * scale
            annotation.bounds = CGRect(
                x: cx - newW / 2,
                y: cy - newH / 2,
                width: newW,
                height: newH
            )
            if let oldFont = annotation.font {
                let newSize = max(8, min(96, oldFont.pointSize * scale / max(0.001, gesture.scale / scale)))
                _ = newSize  // pinch font scale handled below
            }
            // Scale font proportionally too
            scaleFontIfNeeded(oldBounds: pinchStartBounds, newBounds: annotation.bounds)
            forceRedraw()
            updateFrame()
        case .ended, .cancelled, .failed:
            onChange?()
        default:
            break
        }
    }

    // MARK: - Double tap

    @objc private func handleDoubleTap() {
        onEditRequest?()
    }

    // MARK: - Force PDF redraw

    /// PDFKit doesn't refresh visually when annotation.bounds mutate. The only
    /// reliable path is remove + re-add to the page. The annotation reference
    /// stays valid because we hold it strongly here.
    private func forceRedraw() {
        guard let page else { return }
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow pinch + pan to coexist (e.g. user pinches inside selection
        // while finger is also drifting).
        return true
    }
}

// MARK: - HandlePosition

enum HandlePosition: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .top:         return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .right:       return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:      return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .left:        return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

// MARK: - HandleView

/// Small white circle with gold border — the Goodnotes-style grab handle.
private final class HandleView: UIView {
    let position: HandlePosition
    private static let size: CGFloat = 14

    init(position: HandlePosition) {
        self.position = position
        super.init(frame: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        backgroundColor = .white
        layer.cornerRadius = Self.size / 2
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 1.0).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
        isUserInteractionEnabled = false  // pan handled by parent
    }

    required init?(coder: NSCoder) { fatalError() }
}
