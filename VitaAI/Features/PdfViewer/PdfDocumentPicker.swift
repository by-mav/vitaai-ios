import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper around UIDocumentPickerViewController. Used by the PDF
/// workspace's "+ tab" button to let the user open another file as a tab.
///
/// Accepts PDF + Office formats — the backend converts non-PDF to PDF on
/// /api/documents/:id/file (LibreOffice headless, R2 cached). For locally
/// picked files (not from /api/documents/:id), we serve them directly from
/// the security-scoped URL Apple gives us; non-PDF local picks would still
/// fail to render in PDFKit. For now: limit picker to PDFs only to keep UX
/// honest. Office files arrive via the in-app Materiais/Documentos lists,
/// which point at our backend convertor.
struct PdfTabDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
