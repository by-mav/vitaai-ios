import SwiftUI
import UIKit

// Decodifica entidades HTML (&nbsp; &amp; …) e remove tags — usado no texto puro
// do card e no reveal do cloze (contextos SÓ-texto; não passar HTML com <img> aqui).
func flashcardDecodeText(_ raw: String) -> String {
    var r = raw
    // <br> = quebra de linha explícita.
    r = r.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
    // Item de lista vira "• " numa linha nova (ANTES de remover as tags de bloco).
    r = r.replacingOccurrences(of: "<li[^>]*>", with: "\n• ", options: .regularExpression)
    // 🚨 Tags de BLOCO (div/p/ul/ol/li/tr/table/h1-6) = quebra de linha. Sem isto, a
    // remoção genérica de tags GRUDAVA palavras de linhas/itens diferentes
    // ("<li>sangramento</li><li>osteoporose</li>" → "sangramentoosteoporose").
    // O conteúdo da fonte é bem-formado; era a nossa extração que destruía (Rafael 2026-07-17).
    r = r.replacingOccurrences(
        of: "</?(div|p|ul|ol|li|tr|table|h[1-6])[^>]*>",
        with: "\n", options: .regularExpression
    )
    // Sobrou alguma tag inline (span/b/i…) → remove sem separador.
    r = r.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    // "§" usado como marcador de lista no deck de origem é lixo — vira "• " duplo
    // ("• § Prednisona"). Remove o § quando ele age de marcador (após o nosso •
    // ou início de linha). Rafael 2026-07-17.
    r = r.replacingOccurrences(of: "•\\s*§\\s*", with: "• ", options: .regularExpression)
        .replacingOccurrences(of: "(^|\\n)\\s*§\\s+", with: "$1• ", options: .regularExpression)
    r = r.replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&quot;", with: "\"")
    // Colapsa espaços em volta das quebras e limita linhas em branco consecutivas.
    r = r.replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
        .replacingOccurrences(of: "\\n[ \\t]+", with: "\n", options: .regularExpression)
        .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    return r.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - FlashcardContentView
//
// Renders flashcard content that may contain HTML <img> tags (AnKing deck format).
// Strategy:
//   1. If no <img> tags → plain Text() (zero overhead)
//   2. If img tags present → split into segments, render text via markdown + images via AsyncImage
//
// Text segments support: **bold**, *italic*, bullet lists, numbered lists.

struct FlashcardContentView: View {
    let content: String
    let fontSize: CGFloat
    let textColor: Color
    let alignment: TextAlignment

    init(
        content: String,
        fontSize: CGFloat = 16,
        textColor: Color = VitaColors.white.opacity(0.88),
        alignment: TextAlignment = .leading
    ) {
        self.content = content
        self.fontSize = fontSize
        self.textColor = textColor
        self.alignment = alignment
    }

    /// Diretiva de alinhamento no INÍCIO do conteúdo (`{align:center|right|left}`)
    /// — aplica ao campo inteiro e some do texto renderizado. Zero efeito nos cards
    /// sem a diretiva (retorna o alignment/content originais). Rafael 2026-07-18.
    private var aligned: (align: TextAlignment, body: String) {
        let map: [(String, TextAlignment)] = [
            ("{align:center}", .center), ("{align:right}", .trailing), ("{align:left}", .leading),
        ]
        let lead = content.drop(while: { $0 == "\n" || $0 == " " })
        for (marker, a) in map where lead.hasPrefix(marker) {
            let rest = lead.dropFirst(marker.count).drop(while: { $0 == "\n" })
            return (a, String(rest))
        }
        return (alignment, content)
    }
    private var effContent: String { aligned.body }
    private var effAlign: TextAlignment { aligned.align }
    /// Mapeia o alinhamento pra os tipos de layout do SwiftUI.
    private var hAlign: HorizontalAlignment {
        switch effAlign { case .center: return .center; case .trailing: return .trailing; default: return .leading }
    }
    private var frameAlign: Alignment {
        switch effAlign { case .center: return .center; case .trailing: return .trailing; default: return .leading }
    }

    private var segments: [ContentSegment] {
        ContentSegmentParser.parse(effContent)
    }

    /// Tem conteúdo "rico" (imagem OU áudio) → usa a renderização segmentada em vez
    /// do texto puro. Card só de áudio (ex.: gravado pelo usuário) também entra aqui.
    private var hasRichContent: Bool {
        segments.contains {
            switch $0 {
            case .image, .audio: return true
            case .text:          return false
            }
        }
    }

    /// Card de ausculta = imagem (posição do estetoscópio) + PLAYER de áudio. O
    /// player é o ponto do card; a foto é contexto. Com áudio, a imagem fica
    /// COMPACTA pra o player caber na tela sem depender de rolar (o card não rola
    /// bem no flip 3D). Rafael 2026-07-18.
    private var hasAudio: Bool {
        segments.contains { if case .audio = $0 { return true }; return false }
    }

    var body: some View {
        if !hasRichContent {
            // Texto puro — decodifica entidades HTML (&nbsp;) e remove tags (<div> do Anki)
            Text(flashcardDecodeText(effContent))
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(effAlign)
                .lineSpacing(4)
                // O pai trava a LARGURA (o texto quebra). Se ainda for alto demais
                // pro card, ENCOLHE em vez de vazar (Rafael 2026-07-17). Card curto
                // fica no tamanho cheio; card longo diminui a fonte pra caber.
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            // Mixed content — text + inline images
            VStack(alignment: hAlign, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    segmentView(segment)
                }
            }
            .frame(maxWidth: .infinity, alignment: frameAlign)
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: ContentSegment) -> some View {
        switch segment {
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                FlashcardTextSegment(
                    text: trimmed,
                    fontSize: fontSize,
                    textColor: textColor,
                    alignment: effAlign
                )
            }

        case .image(let url):
            FlashcardImageSegment(url: url, compact: hasAudio)

        case .audio(let url):
            FlashcardAudioSegment(url: url)
        }
    }
}

// MARK: - Text Segment (markdown-aware)

private struct FlashcardTextSegment: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let alignment: TextAlignment

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        let hasBlocks = lines.contains { isListItem($0) || heading($0) != nil }

        if hasBlocks {
            listView(lines: lines)
        } else {
            // Single paragraph — inline markdown spans
            Text(renderInline(text))
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        }
    }

    @ViewBuilder
    private func listView(lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { EmptyView() }
                else if let title = heading(trimmedLine) {
                    // Título (# ) — maior e em destaque.
                    Text(renderInline(title))
                        .font(.system(size: fontSize * 1.35, weight: .bold))  // ds-allow: título = proporção do fontSize do card
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(alignment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                }
                else if let (bullet, itemText) = unorderedItem(trimmedLine) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(bullet)
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor.opacity(0.6))
                        Text(renderInline(itemText))
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let (num, itemText) = orderedItem(trimmedLine) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(num).")
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor.opacity(0.6))
                            .frame(minWidth: 20, alignment: .trailing)
                        Text(renderInline(itemText))
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(renderInline(trimmedLine))
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(alignment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isListItem(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return unorderedItem(t) != nil || orderedItem(t) != nil
    }

    /// Título markdown `# texto` → devolve o texto sem o marcador.
    private func heading(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("# ") { return String(t.dropFirst(2)) }
        return nil
    }

    private func unorderedItem(_ line: String) -> (String, String)? {
        if line.hasPrefix("- ") { return ("-", String(line.dropFirst(2))) }
        if line.hasPrefix("* ") { return ("•", String(line.dropFirst(2))) }
        if line.hasPrefix("+ ") { return ("+", String(line.dropFirst(2))) }
        return nil
    }

    private func orderedItem(_ line: String) -> (Int, String)? {
        let pattern = /^(\d+)\.\s+(.+)/
        if let match = try? pattern.wholeMatch(in: line) {
            return (Int(match.output.1) ?? 0, String(match.output.2))
        }
        return nil
    }

    /// Converts basic markdown inline syntax to AttributedString.
    private func renderInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**"),
               let endIdx = findMarker("**", in: remaining.dropFirst(2)) {
                let inner = String(remaining.dropFirst(2).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .bold)
                s.foregroundColor = Color.white.opacity(0.95)
                result.append(s)
                remaining = remaining.dropFirst(2)[endIdx...].dropFirst(2)
                continue
            }

            // Strikethrough: ~~text~~
            if remaining.hasPrefix("~~"),
               let endIdx = findMarker("~~", in: remaining.dropFirst(2)) {
                let inner = String(remaining.dropFirst(2).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium)
                s.foregroundColor = textColor
                s.strikethroughStyle = .single
                result.append(s)
                remaining = remaining.dropFirst(2)[endIdx...].dropFirst(2)
                continue
            }

            // Underline: <u>text</u> (markdown não tem sublinhado → tag HTML)
            if remaining.hasPrefix("<u>"),
               let endIdx = findMarker("</u>", in: remaining.dropFirst(3)) {
                let inner = String(remaining.dropFirst(3).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium)
                s.foregroundColor = textColor
                s.underlineStyle = .single
                result.append(s)
                remaining = remaining.dropFirst(3)[endIdx...].dropFirst(4)
                continue
            }

            // Italic: *text* or _text_
            if remaining.hasPrefix("*"),
               !remaining.hasPrefix("**"),
               let endIdx = findChar("*", in: remaining.dropFirst(1)) {
                let inner = String(remaining.dropFirst(1).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium).italic()
                s.foregroundColor = textColor
                result.append(s)
                remaining = remaining.dropFirst(1)[endIdx...].dropFirst(1)
                continue
            }
            if remaining.hasPrefix("_"),
               let endIdx = findChar("_", in: remaining.dropFirst(1)) {
                let inner = String(remaining.dropFirst(1).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium).italic()
                s.foregroundColor = textColor
                result.append(s)
                remaining = remaining.dropFirst(1)[endIdx...].dropFirst(1)
                continue
            }

            // Plain character
            var s = AttributedString(String(remaining.removeFirst()))
            s.font = .system(size: fontSize, weight: .medium)
            s.foregroundColor = textColor
            result.append(s)
        }

        return result
    }

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

// MARK: - Image Segment

private struct FlashcardImageSegment: View {
    let url: String
    /// Card com áudio: encolhe a foto pra o player caber sem rolar.
    var compact: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Teto de altura da imagem. Com scaledToFit, subir o teto faz a imagem crescer
    // até encostar na largura do card → aproveita melhor o espaço (Rafael 2026-07-17).
    // O card de estudo tem ~324pt úteis de altura; 300pt no iPhone preenche bem sem estourar.
    // iPhone: 300pt. iPad (regular): 440pt. Compacto (card de áudio): 130pt.
    private var maxImageHeight: CGFloat {
        if compact { return 130 }
        return horizontalSizeClass == .regular ? 440 : 300
    }

    // Resolve a imagem local:
    // • `userdoc:<rel>` = imagem INSERIDA pelo usuário (Documents/<rel>).
    // • ref relativa (ex "medicina/foo.webp") = mídia EMBUTIDA (FlashcardMedia).
    // • http(s) = rede (via AsyncImage no else).
    private var bundledImage: UIImage? {
        if url.hasPrefix("userdoc:") {
            let rel = String(url.dropFirst("userdoc:".count))
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return UIImage(contentsOfFile: docs.appendingPathComponent(rel).path)
        }
        guard !url.hasPrefix("http"), let base = Bundle.main.resourceURL else { return nil }
        let path = base.appendingPathComponent("FlashcardMedia").appendingPathComponent(url).path
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        if let img = bundledImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: maxImageHeight)
                .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))
                .pinchToZoom()
        } else if let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    // Placeholder shimmer
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                        .fill(Color.white.opacity(0.06))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay(
                            ProgressView()
                                .tint(Color(red: 148/255, green: 75/255, blue: 220/255))
                        )

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: maxImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))
                        .pinchToZoom()

                case .failure:
                    // Broken image indicator
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                        .fill(Color.white.opacity(0.04))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .foregroundStyle(Color.white.opacity(0.25))
                                Text("Imagem indisponível")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                        )

                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Pinch to zoom
//
// Permite ampliar a imagem com dois dedos DIRETO nela (Rafael 2026-07-17), arrastar
// pra mover quando ampliada, e double-tap pra voltar ao normal. Os gestos são
// simultâneos e a pinça é de 2 dedos → o tap de 1 dedo (virar o card) continua vivo.
private struct PinchToZoom: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnification.simultaneously(with: pan))
            .onTapGesture(count: 2) { reset() }
            // Enquanto ampliada, sobe na pilha pra a imagem aparecer por cima do resto.
            .zIndex(scale > 1 ? 10 : 0)
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = min(max(lastScale * value, 1), 4) }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { reset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }   // só move quando ampliada
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func reset() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
        }
    }
}

private extension View {
    func pinchToZoom() -> some View { modifier(PinchToZoom()) }
}

// MARK: - Content Segment Parser

private enum ContentSegment {
    case text(String)
    case image(url: String)
    case audio(url: String)
}

private enum ContentSegmentParser {
    // <img src="..." ...>  (self-closing / também)
    private static let imgPattern = /<img[^>]*\bsrc=["']([^"']+)["'][^>]*\/?>/
    // <audio ... src="..." ...></audio>  (consome o fechamento pra a tag não vazar)
    private static let audioPattern = /<audio[^>]*\bsrc=["']([^"']+)["'][^>]*>(?:\s*<\/audio>)?/

    static func parse(_ input: String) -> [ContentSegment] {
        // Quick bail-out — nada de mídia
        guard input.contains("<img") || input.contains("<audio") else {
            return [.text(input)]
        }

        // Coleta TODAS as mídias (img + audio) com posição, pra intercalar o texto
        // na ordem certa mesmo quando as duas aparecem no mesmo card (ausculta:
        // foto + player).
        struct Media { let range: Range<String.Index>; let segment: ContentSegment }
        var media: [Media] = []
        for m in input.matches(of: imgPattern) {
            media.append(Media(range: m.range, segment: .image(url: String(m.output.1))))
        }
        for m in input.matches(of: audioPattern) {
            media.append(Media(range: m.range, segment: .audio(url: String(m.output.1))))
        }
        media.sort { $0.range.lowerBound < $1.range.lowerBound }

        var segments: [ContentSegment] = []
        var cursor = input.startIndex
        for item in media {
            if cursor < item.range.lowerBound {
                let stripped = stripOtherHTML(String(input[cursor..<item.range.lowerBound]))
                if !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(stripped))
                }
            }
            segments.append(item.segment)
            cursor = item.range.upperBound
        }

        // Texto após a última mídia
        if cursor < input.endIndex {
            let stripped = stripOtherHTML(String(input[cursor...]))
            if !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(stripped))
            }
        }

        return segments.isEmpty ? [.text(input)] : segments
    }

    /// Strips non-img HTML tags from a text chunk (e.g. <br>, <div>, <b>, etc.)
    /// Converts <br> → newline, <b>/<strong> → ** markdown, <i>/<em> → * markdown.
    private static func stripOtherHTML(_ text: String) -> String {
        var result = text

        // <br> and <br/> → newline
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)

        // <b>text</b> and <strong>text</strong> → **text**
        result = result.replacingOccurrences(of: "<(b|strong)>", with: "**", options: .regularExpression)
        result = result.replacingOccurrences(of: "</(b|strong)>", with: "**", options: .regularExpression)

        // <i>text</i> and <em>text</em> → *text*
        result = result.replacingOccurrences(of: "<(i|em)>", with: "*", options: .regularExpression)
        result = result.replacingOccurrences(of: "</(i|em)>", with: "*", options: .regularExpression)

        // <ul>/<ol>/<li> → newline + bullet
        result = result.replacingOccurrences(of: "<li>", with: "\n- ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</li>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</?[uo]l>", with: "", options: .regularExpression)

        // Preserva <u>/</u> (sublinhado do editor rico) do strip catch-all abaixo.
        result = result.replacingOccurrences(of: "<u>", with: "\u{FFF9}")
        result = result.replacingOccurrences(of: "</u>", with: "\u{FFFA}")
        // Strip remaining HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{FFF9}", with: "<u>")
        result = result.replacingOccurrences(of: "\u{FFFA}", with: "</u>")

        // Decode basic HTML entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")

        return result
    }
}
