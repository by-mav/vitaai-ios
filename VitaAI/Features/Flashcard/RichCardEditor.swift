import SwiftUI
import UIKit

// MARK: - RichCardEditor
//
// Editor de texto de card com barra de formatação. Os botões inserem a MESMA
// marcação que o FlashcardContentView renderiza (**negrito**, *itálico*, "- "
// lista, "1. " numerada) — assim o que o aluno escreve mantém a estrutura e a
// tipografia do card exibido. UITextView-backed pra ter acesso à SELEÇÃO
// (envolver a palavra marcada), o que o TextEditor do SwiftUI não expõe.

struct RichCardEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 110
    var fontSize: CGFloat = 15
    var centered: Bool = false
    /// Botão extra de imagem na barra (o CardEditor injeta a ação de foto).
    var onImage: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = .systemFont(ofSize: fontSize, weight: centered ? .medium : .regular)
        tv.textColor = UIColor(VitaColors.textPrimary)
        tv.tintColor = UIColor(VitaColors.accent)
        tv.textAlignment = centered ? .center : .natural
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        tv.isScrollEnabled = true
        tv.text = text
        tv.inputAccessoryView = context.coordinator.makeToolbar()

        // placeholder overlay
        let ph = UILabel()
        ph.text = placeholder
        ph.font = .systemFont(ofSize: fontSize)
        ph.textColor = UIColor(VitaColors.textTertiary)
        ph.numberOfLines = 0
        ph.textAlignment = centered ? .center : .natural
        ph.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 12),
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 12),
            ph.trailingAnchor.constraint(equalTo: tv.trailingAnchor, constant: -12),
        ])
        context.coordinator.textView = tv
        context.coordinator.placeholder = ph
        ph.isHidden = !text.isEmpty
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        context.coordinator.placeholder?.isHidden = !tv.text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichCardEditor
        weak var textView: UITextView?
        weak var placeholder: UILabel?

        init(_ parent: RichCardEditor) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            placeholder?.isHidden = !tv.text.isEmpty
        }

        func makeToolbar() -> UIToolbar {
            let bar = UIToolbar()
            bar.sizeToFit()
            bar.tintColor = UIColor(VitaColors.accent)
            func item(_ symbol: String, _ action: Selector) -> UIBarButtonItem {
                UIBarButtonItem(image: UIImage(systemName: symbol), style: .plain, target: self, action: action)
            }
            let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let done = UIBarButtonItem(title: "Concluir", style: .done, target: self, action: #selector(tapDone))
            var items: [UIBarButtonItem] = [
                item("bold", #selector(tapBold)),
                item("italic", #selector(tapItalic)),
                item("list.bullet", #selector(tapBullet)),
                item("list.number", #selector(tapNumbered)),
            ]
            if parent.onImage != nil {
                items.append(item("photo.on.rectangle", #selector(tapImage)))
            }
            items.append(contentsOf: [flex, done])
            bar.items = items
            return bar
        }

        @objc private func tapImage() { parent.onImage?() }
        @objc private func tapDone() { textView?.resignFirstResponder() }
        @objc private func tapBold() { wrap("**", placeholder: "negrito") }
        @objc private func tapItalic() { wrap("*", placeholder: "itálico") }
        @objc private func tapBullet() { linePrefix("- ") }
        @objc private func tapNumbered() { linePrefix("1. ") }

        /// Envolve a seleção nos marcadores; sem seleção, insere um exemplo com o
        /// cursor dentro pro aluno digitar por cima.
        private func wrap(_ marker: String, placeholder ph: String) {
            guard let tv = textView, let range = tv.selectedTextRange else { return }
            let selected = tv.text(in: range) ?? ""
            let inner = selected.isEmpty ? ph : selected
            tv.replace(range, withText: marker + inner + marker)
            sync(tv)
        }

        /// Prefixa a linha atual (lista). Se já tem o prefixo, remove (toggle).
        private func linePrefix(_ prefix: String) {
            guard let tv = textView, let sel = tv.selectedTextRange else { return }
            let ns = tv.text as NSString
            let caret = tv.offset(from: tv.beginningOfDocument, to: sel.start)
            // início da linha atual: varre pra trás até o \n (código 10) anterior
            var start = caret
            while start > 0 && ns.character(at: start - 1) != 10 { start -= 1 }
            let existing = ns.substring(from: start)
            if existing.hasPrefix(prefix) {
                if let r = tv.textRange(from: pos(tv, start), to: pos(tv, start + prefix.count)) {
                    tv.replace(r, withText: "")
                }
            } else if let r = tv.textRange(from: pos(tv, start), to: pos(tv, start)) {
                tv.replace(r, withText: prefix)
            }
            sync(tv)
        }

        private func pos(_ tv: UITextView, _ offset: Int) -> UITextPosition {
            tv.position(from: tv.beginningOfDocument, offset: offset) ?? tv.beginningOfDocument
        }

        private func sync(_ tv: UITextView) {
            parent.text = tv.text
            placeholder?.isHidden = !tv.text.isEmpty
        }
    }
}
