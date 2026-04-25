import PDFKit
import UIKit

// MARK: - PdfMaskAnnotation
//
// Helper para criar/identificar "masks" no PDF — retângulos pretos opacos que
// o aluno usa pra cobrir áreas (doses farmacológicas, labels de anatomia,
// definições) em modo Marcador. Em Study Mode, masks ficam visíveis pretas e
// tap revela conteúdo (modelo Flexcil "Memorize com masking pen").
//
// Implementação: usa `PDFAnnotation` tipo `.square` com fill preto sólido +
// flag custom no `userName` (PDFKit annotation key `name`) para distinguir
// das squares "normais" que o usuário poderia colocar no futuro.

enum PdfMaskAnnotation {
    /// Tag escrita no campo `name` da annotation pra distinguir de outras squares.
    static let kind: String = "vita-mask"

    /// Cria uma square preta opaca já marcada como mask. Caller adiciona à página
    /// e dispara `viewModel.saveHighlights()` pra persistir no disco.
    /// `id` é embutido no campo `contents` pra trackear attempts no UserDefaults/backend.
    static func makeAnnotation(bounds: CGRect, id: String = UUID().uuidString) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        annotation.color = .black
        annotation.interiorColor = .black
        // PDFKit não expõe direto userName via init; setValue por key é a forma canônica.
        annotation.setValue(kind, forAnnotationKey: .name)
        annotation.contents = id
        // Border zero — fill preto liso, sem moldura.
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        return annotation
    }

    /// Verifica se uma annotation é uma mask criada pelo VitaAI.
    /// Usa key `name` (.name) que armazena o tag `vita-mask`.
    static func isMask(_ annotation: PDFAnnotation) -> Bool {
        guard annotation.type == "Square" else { return false }
        if let name = annotation.value(forAnnotationKey: .name) as? String {
            return name == kind
        }
        // Fallback: PDFKit às vezes devolve via .userName quando relê do disco
        if annotation.userName == kind { return true }
        return false
    }

    /// Lê o id estável da mask (gravado em `contents` no makeAnnotation).
    /// Se vier vazio (mask antiga ou edit manual), gera um determinístico
    /// baseado em pageIndex+bounds pra estabilidade entre sessões.
    static func id(for annotation: PDFAnnotation, pageIndex: Int) -> String {
        if let stored = annotation.contents, !stored.isEmpty {
            return stored
        }
        let b = annotation.bounds
        return "p\(pageIndex)-x\(Int(b.minX))-y\(Int(b.minY))-w\(Int(b.width))-h\(Int(b.height))"
    }

    /// Aplica visual de Study Mode na mask:
    /// - true (Study ON): fill preto sólido (alpha 1) — cobre conteúdo
    /// - false (Study OFF): fill semi-transparente (alpha 0.2) — usuário vê
    ///   onde estão pra ajustar/apagar mas não cobre completamente.
    /// PDFKit não anima fill diretamente — mudar `interiorColor` e re-add força redraw.
    static func setVisible(_ annotation: PDFAnnotation, fullyOpaque: Bool, on page: PDFPage) {
        let alpha: CGFloat = fullyOpaque ? 1.0 : 0.2
        annotation.interiorColor = UIColor.black.withAlphaComponent(alpha)
        annotation.color = UIColor.black.withAlphaComponent(alpha)
        // Force redraw cycle (PDFKit limitation — mudança de cor não dispara repaint sozinha)
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
    }

    /// Esconde mask completamente (alpha 0) — usado quando user revela em Study Mode.
    static func hide(_ annotation: PDFAnnotation, on page: PDFPage) {
        annotation.interiorColor = UIColor.black.withAlphaComponent(0)
        annotation.color = UIColor.black.withAlphaComponent(0)
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
    }
}
