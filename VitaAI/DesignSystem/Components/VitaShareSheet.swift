import SwiftUI
import UIKit

// MARK: - VitaShareSheet — ponte ÚNICA pro share nativo (UIActivityViewController)
//
// Componente canônico: antes existiam 3 cópias privadas iguais (PdfViewer,
// Transcrição, e a tela do baralho ia virar a quarta). Uma só — muda aqui,
// muda em todo lugar (canon: componente canônico, nunca bespoke repetido).
//
// É UIKit de propósito: o share dialog do sistema não pode ser embrulhado em
// VitaSheet (quebra a apresentação nativa) — por isso os call sites levam o
// comentário `vita-modals-ignore`.
struct VitaShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
