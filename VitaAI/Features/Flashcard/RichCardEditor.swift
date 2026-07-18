import SwiftUI
import UIKit
import PhotosUI

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
        // Formata o conteúdo inicial (card já existente) ao vivo.
        context.coordinator.applyLiveFormatting(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Só re-seta quando o texto CRU muda por fora (ex.: carregar outro card).
        // Nesse caso reformata; edições do próprio usuário já mantêm o texto igual
        // (o binding recebe o markup puro), então isto NÃO apaga a formatação viva.
        if tv.text != text {
            tv.text = text
            context.coordinator.applyLiveFormatting(tv)
        }
        context.coordinator.placeholder?.isHidden = !tv.text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate, PHPickerViewControllerDelegate {
        let parent: RichCardEditor
        weak var textView: UITextView?
        weak var placeholder: UILabel?

        init(_ parent: RichCardEditor) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            placeholder?.isHidden = !tv.text.isEmpty
            // Não reformatar DURANTE composição de IME (marked text) — acento/ditado
            // ficam "pendentes" e re-setar o attributedText mataria a composição e
            // pularia o cursor. Reformata assim que a composição fechar.
            if tv.markedTextRange == nil {
                applyLiveFormatting(tv)
            }
        }

        /// Barra ROLÁVEL (igual a referência): todos os botões cabem e o aluno
        /// rola horizontal se a tela for estreita — o UIToolbar cortava as pontas.
        /// Ordem = referência: imagem·AA·B·I·U·S·lista·numerada + fechar. Rafael 2026-07-18.
        func makeToolbar() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 48))
            container.autoresizingMask = [.flexibleWidth]

            let scroll = UIScrollView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false
            scroll.alwaysBounceHorizontal = true
            container.addSubview(scroll)

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)

            func button(_ symbol: String, _ action: Selector) -> UIButton {
                let b = UIButton(type: .system)
                b.setImage(UIImage(systemName: symbol), for: .normal)
                b.tintColor = UIColor(VitaColors.accent)
                b.addTarget(self, action: action, for: .touchUpInside)
                b.widthAnchor.constraint(equalToConstant: 42).isActive = true
                return b
            }
            let buttons: [(String, Selector)] = [
                ("photo", #selector(tapImage)),
                ("mic", #selector(tapMic)),
                ("textformat.size", #selector(tapHeading)),
                ("bold", #selector(tapBold)),
                ("italic", #selector(tapItalic)),
                ("underline", #selector(tapUnderline)),
                ("strikethrough", #selector(tapStrike)),
                ("list.bullet", #selector(tapBullet)),
                ("list.number", #selector(tapNumbered)),
                ("text.aligncenter", #selector(tapAlign)),
                ("keyboard.chevron.compact.down", #selector(tapDone)),
            ]
            buttons.forEach { stack.addArrangedSubview(button($0.0, $0.1)) }

            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                scroll.topAnchor.constraint(equalTo: container.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            ])
            return container
        }

        @objc private func tapImage() {
            parent.onImage?()   // hook opcional (legado)
            guard let tv = textView else { return }
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            Self.topPresenter(from: tv)?.present(picker, animated: true)
        }
        @objc private func tapDone() { textView?.resignFirstResponder() }

        /// Mic da barra → abre o sheet de gravação → "Anexar" insere a tag
        /// `<audio src="userdoc:…">` no cursor (igual a imagem). Rafael 2026-07-18.
        @objc private func tapMic() {
            guard let tv = textView, let presenter = Self.topPresenter(from: tv) else { return }
            var host: UIViewController?
            let sheet = AudioRecordSheet(
                onAttach: { [weak self] ref in
                    host?.dismiss(animated: true)
                    self?.insertAudio(ref)
                },
                onCancel: { host?.dismiss(animated: true) }
            )
            let h = UIHostingController(rootView: sheet)
            host = h
            if let sc = h.sheetPresentationController {
                sc.detents = [.medium()]
                sc.prefersGrabberVisible = true
            }
            presenter.present(h, animated: true)
        }

        private func insertAudio(_ ref: String) {
            guard let tv = textView, let range = tv.selectedTextRange else { return }
            tv.replace(range, withText: "<audio src=\"\(ref)\"></audio>")
            sync(tv)
        }

        /// VC mais acima pra apresentar o picker (o editor vive dentro de um sheet).
        private static func topPresenter(from view: UIView) -> UIViewController? {
            var top = view.window?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }

        /// Salva a imagem escolhida em `Documents/flashcard-images/` e insere a tag
        /// `<img src="userdoc:…">` no cursor (o renderer do card já a mostra).
        private func insertImage(_ image: UIImage) {
            let dir = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("flashcard-images", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "\(UUID().uuidString).jpg"
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: dir.appendingPathComponent(name), options: .atomic)

            guard let tv = textView, let range = tv.selectedTextRange else { return }
            tv.replace(range, withText: "<img src=\"userdoc:flashcard-images/\(name)\">")
            sync(tv)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let self, let image = obj as? UIImage else { return }
                DispatchQueue.main.async { self.insertImage(image) }
            }
        }
        @objc private func tapBold() { wrap("**", placeholder: "negrito") }
        @objc private func tapItalic() { wrap("*", placeholder: "itálico") }
        @objc private func tapStrike() { wrap("~~", placeholder: "tachado") }
        @objc private func tapUnderline() { wrapPair("<u>", "</u>", placeholder: "sublinhado") }
        @objc private func tapBullet() { linePrefix("- ") }
        @objc private func tapNumbered() { linePrefix("1. ") }
        @objc private func tapHeading() { linePrefix("# ") }   // título maior

        /// Alinhamento do CAMPO inteiro via diretiva no início: cicla
        /// esquerda → centro → direita → esquerda. O renderer lê e some com ela.
        @objc private func tapAlign() {
            guard let tv = textView else { return }
            var t = tv.text ?? ""
            let center = "{align:center}\n", right = "{align:right}\n"
            if t.hasPrefix(center) { t = right + String(t.dropFirst(center.count)) }
            else if t.hasPrefix(right) { t = String(t.dropFirst(right.count)) }
            else { t = center + t }
            tv.text = t
            sync(tv)
        }

        /// Envolve a seleção nos marcadores; sem seleção, insere um exemplo com o
        /// cursor dentro pro aluno digitar por cima.
        private func wrap(_ marker: String, placeholder ph: String) {
            wrapPair(marker, marker, placeholder: ph)
        }

        /// Igual `wrap`, mas com marcador de abertura/fechamento diferentes
        /// (ex.: sublinhado `<u>…</u>`).
        private func wrapPair(_ open: String, _ close: String, placeholder ph: String) {
            guard let tv = textView, let range = tv.selectedTextRange else { return }
            let selected = tv.text(in: range) ?? ""
            let inner = selected.isEmpty ? ph : selected
            tv.replace(range, withText: open + inner + close)
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
            applyLiveFormatting(tv)
        }

        // MARK: - WYSIWYG (formatação ao vivo)
        //
        // Mostra o texto JÁ FORMATADO no editor (negrito em negrito, marcador
        // apagado) enquanto o binding `parent.text` continua sendo o MARKUP puro —
        // o FlashcardContentView renderiza pelo markup, então a fonte da verdade não
        // muda. Aqui só ESTILIZAMOS o display: reconstruímos o `attributedText`
        // preservando cada caractere (inclusive os marcadores, que ficam
        // `textTertiary`), logo `tv.text` == markup e o cursor (NSRange UTF-16)
        // continua válido.

        /// Reconstrói o `attributedText` estilizado, preservando cursor e seleção.
        func applyLiveFormatting(_ tv: UITextView) {
            let selected = tv.selectedRange
            tv.attributedText = buildFormatted(tv.text)
            tv.selectedRange = selected
            // Cursor volta ao estilo BASE — senão o próximo char herda o marcador
            // apagado / negrito e o caret "pula" de tamanho.
            let para = NSMutableParagraphStyle()
            para.alignment = parent.centered ? .center : .natural
            tv.typingAttributes = [
                .font: UIFont.systemFont(ofSize: parent.fontSize, weight: parent.centered ? .medium : .regular),
                .foregroundColor: UIColor(VitaColors.textPrimary),
                .paragraphStyle: para,
            ]
        }

        /// Markup → NSAttributedString estilizado (mesmo caractere-a-caractere).
        private func buildFormatted(_ raw: String) -> NSAttributedString {
            let out = NSMutableAttributedString()
            let baseWeight: UIFont.Weight = parent.centered ? .medium : .regular
            let baseFont = UIFont.systemFont(ofSize: parent.fontSize, weight: baseWeight)
            let faded = UIColor(VitaColors.textTertiary)
            let primary = UIColor(VitaColors.textPrimary)

            // Preserva linhas em branco (o `\n` reconstrói o texto exato).
            let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() {
                if i == 0, line == "{align:center}" || line == "{align:right}" || line == "{align:left}" {
                    // Diretiva de alinhamento do campo — o card a esconde; aqui só apaga.
                    out.append(NSAttributedString(string: String(line),
                                                  attributes: [.font: baseFont, .foregroundColor: faded]))
                } else if line.hasPrefix("# ") {
                    // Título: `# ` apagado, resto maior + negrito.
                    out.append(NSAttributedString(string: "# ",
                                                  attributes: [.font: baseFont, .foregroundColor: faded]))
                    appendInline(out, line.dropFirst(2), size: parent.fontSize * 1.35, weight: .bold)
                } else {
                    appendInline(out, line[line.startIndex...], size: parent.fontSize, weight: baseWeight)
                }
                if i < lines.count - 1 {
                    out.append(NSAttributedString(string: "\n",
                                                  attributes: [.font: baseFont, .foregroundColor: primary]))
                }
            }

            let para = NSMutableParagraphStyle()
            para.alignment = parent.centered ? .center : .natural
            out.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: out.length))
            return out
        }

        /// Tokeniza uma linha em runs formatados — ESPELHA o `renderInline` do
        /// FlashcardContentView (mesma ordem/prioridade), mas mantém os marcadores
        /// no output (apagados) pra o texto puro ficar idêntico ao markup.
        private func appendInline(_ out: NSMutableAttributedString,
                                  _ text: Substring,
                                  size: CGFloat,
                                  weight: UIFont.Weight) {
            let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
            let primary = UIColor(VitaColors.textPrimary)
            let faded = UIColor(VitaColors.textTertiary)

            func marker(_ s: String) -> NSAttributedString {
                NSAttributedString(string: s, attributes: [.font: baseFont, .foregroundColor: faded])
            }
            func styled(_ s: String, _ attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
                NSAttributedString(string: s, attributes: attrs)
            }

            var rem = text[text.startIndex...]
            while !rem.isEmpty {
                // Negrito: **x**
                if rem.hasPrefix("**"), let end = findMarker("**", in: rem.dropFirst(2)) {
                    let inner = String(rem.dropFirst(2).prefix(upTo: end))
                    out.append(marker("**"))
                    out.append(styled(inner, [
                        .font: UIFont.systemFont(ofSize: size, weight: .bold),
                        .foregroundColor: primary,
                    ]))
                    out.append(marker("**"))
                    rem = rem.dropFirst(2)[end...].dropFirst(2)
                    continue
                }
                // Tachado: ~~x~~
                if rem.hasPrefix("~~"), let end = findMarker("~~", in: rem.dropFirst(2)) {
                    let inner = String(rem.dropFirst(2).prefix(upTo: end))
                    out.append(marker("~~"))
                    out.append(styled(inner, [
                        .font: baseFont, .foregroundColor: primary,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    ]))
                    out.append(marker("~~"))
                    rem = rem.dropFirst(2)[end...].dropFirst(2)
                    continue
                }
                // Sublinhado: <u>x</u>
                if rem.hasPrefix("<u>"), let end = findMarker("</u>", in: rem.dropFirst(3)) {
                    let inner = String(rem.dropFirst(3).prefix(upTo: end))
                    out.append(marker("<u>"))
                    out.append(styled(inner, [
                        .font: baseFont, .foregroundColor: primary,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                    ]))
                    out.append(marker("</u>"))
                    rem = rem.dropFirst(3)[end...].dropFirst(4)
                    continue
                }
                // Itálico: *x*  (não confundir com **)
                if rem.hasPrefix("*"), !rem.hasPrefix("**"), let end = findChar("*", in: rem.dropFirst(1)) {
                    let inner = String(rem.dropFirst(1).prefix(upTo: end))
                    out.append(marker("*"))
                    out.append(styled(inner, [.font: italicFont(size: size, weight: weight), .foregroundColor: primary]))
                    out.append(marker("*"))
                    rem = rem.dropFirst(1)[end...].dropFirst(1)
                    continue
                }
                // Itálico: _x_
                if rem.hasPrefix("_"), let end = findChar("_", in: rem.dropFirst(1)) {
                    let inner = String(rem.dropFirst(1).prefix(upTo: end))
                    out.append(marker("_"))
                    out.append(styled(inner, [.font: italicFont(size: size, weight: weight), .foregroundColor: primary]))
                    out.append(marker("_"))
                    rem = rem.dropFirst(1)[end...].dropFirst(1)
                    continue
                }
                // Caractere normal
                out.append(styled(String(rem.removeFirst()), [.font: baseFont, .foregroundColor: primary]))
            }
        }

        /// Fonte itálica do sistema no tamanho/peso pedidos (fallback = sem itálico).
        private func italicFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let f = UIFont.systemFont(ofSize: size, weight: weight)
            if let d = f.fontDescriptor.withSymbolicTraits(.traitItalic) {
                return UIFont(descriptor: d, size: size)
            }
            return f
        }

        /// Primeira ocorrência do marcador multi-char (ex.: `**`, `</u>`).
        private func findMarker(_ marker: String, in sub: Substring) -> Substring.Index? {
            var idx = sub.startIndex
            while idx < sub.endIndex {
                if sub[idx...].hasPrefix(marker) { return idx }
                idx = sub.index(after: idx)
            }
            return nil
        }

        private func findChar(_ ch: Character, in sub: Substring) -> Substring.Index? {
            sub.firstIndex(of: ch)
        }
    }
}
