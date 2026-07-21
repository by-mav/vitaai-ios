import Foundation
import SwiftSoup

/// O card do Anki É uma página web: o Anki joga o HTML num navegador e pronto.
/// Antes a gente desmontava esse HTML com regex — o que na prática era uma LISTA
/// de tags que alguém lembrou de tratar. 13 das 25 tags do baralho do Rafael não
/// estavam em lista nenhuma, e o texto saía grudado ("edemadiurético"). Pior:
/// existiam DUAS listas diferentes (uma pra card com imagem, outra sem), então o
/// mesmo card mudava de cara só por ter foto.
///
/// Aqui a gente LÊ a árvore de verdade. Tag nova nunca mais vira bug novo.
enum ContentSegment {
    case text(String)
    case image(url: String)
    case audio(url: String)
}

enum FlashcardHTMLReader {

    static func read(_ html: String) -> [ContentSegment] {
        // parseBodyFragment: o campo do Anki é pedaço de corpo, não documento.
        guard let doc = try? SwiftSoup.parseBodyFragment(html), let body = doc.body() else {
            // Falhar aqui não pode virar card em branco: mostra o texto sem tag.
            return [.text(semTags(html))]
        }
        var segmentos: [ContentSegment] = []
        var buffer = ""
        percorre(body, &segmentos, &buffer)
        descarrega(&segmentos, &buffer)
        return segmentos
    }

    // MARK: - Travessia

    private static func percorre(_ no: Node, _ segs: inout [ContentSegment], _ buf: inout String) {
        for filho in no.getChildNodes() {
            if let texto = filho as? TextNode {
                // SwiftSoup já devolve &nbsp; &gt; &amp; decodificados.
                buf += texto.text()
                continue
            }
            guard let el = filho as? Element else { continue }

            switch el.tagName().lowercased() {
            case "img":
                // A mídia interrompe o texto: fecha o parágrafo corrente e emite.
                if let src = try? el.attr("src"), !src.isEmpty {
                    descarrega(&segs, &buf)
                    segs.append(.image(url: src))
                }

            case "audio":
                if let src = try? el.attr("src"), !src.isEmpty {
                    descarrega(&segs, &buf)
                    segs.append(.audio(url: src))
                } else if let fonte = try? el.select("source").first(),
                          let src = try? fonte.attr("src"), !src.isEmpty {
                    descarrega(&segs, &buf)
                    segs.append(.audio(url: src))
                }

            case "br":
                buf += "\n"

            case "hr":
                quebra(&buf); buf += "———\n"

            // Itens de lista: marcador visível, senão viram um parágrafo só.
            case "li":
                quebra(&buf); buf += "• "
                percorre(el, &segs, &buf)
                quebra(&buf)

            // Célula de tabela: o separador é o que impedia "edema" e "diurético"
            // de virarem "edemadiurético" — nenhuma das duas listas tratava td/th.
            case "td", "th":
                if !buf.isEmpty, !buf.hasSuffix("\n"), !buf.hasSuffix(" · ") { buf += " · " }
                percorre(el, &segs, &buf)

            case "tr":
                quebra(&buf); percorre(el, &segs, &buf); quebra(&buf)

            case "div", "p", "table", "tbody", "thead", "tfoot", "ul", "ol",
                 "blockquote", "section", "h1", "h2", "h3", "h4", "h5", "h6":
                quebra(&buf); percorre(el, &segs, &buf); quebra(&buf)

            // Ênfase vira markdown — é o que o renderer do card já entende.
            case "b", "strong":
                envolve(el, "**", &segs, &buf)
            case "i", "em":
                envolve(el, "*", &segs, &buf)
            case "u":
                // O renderer trata <u> nativamente (sublinhado do editor rico).
                buf += "<u>"; percorre(el, &segs, &buf); buf += "</u>"

            // Expoente e índice CARREGAM significado em medicina: cm², 10⁶, H₂O.
            // A extração antiga apagava a tag e "10⁶" virava "106".
            case "sup":
                var interno = ""
                percorre(el, &segs, &interno)
                buf += sobrescrito(interno)
            case "sub":
                var interno = ""
                percorre(el, &segs, &interno)
                buf += subscrito(interno)

            // span, font, a e afins: sem semântica de bloco, só desce.
            // ⚠️ A COR do <font color> é descartada aqui. Em alguns
            // cards ela marca a exceção da lista ("o item que NÃO pertence"), e
            // isso é conteúdo. Preservar exige segmento com atributo + mudança
            // nas views — está reportado ao Rafael, não foi inventado aqui.
            default:
                percorre(el, &segs, &buf)
            }
        }
    }

    // MARK: - Auxiliares

    private static func quebra(_ buf: inout String) {
        let limpo = buf.replacingOccurrences(of: " · ", with: "")
        guard !limpo.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !buf.hasSuffix("\n") { buf += "\n" }
    }

    private static func envolve(_ el: Element, _ marca: String,
                                _ segs: inout [ContentSegment], _ buf: inout String) {
        var interno = ""
        percorre(el, &segs, &interno)
        let corte = interno.trimmingCharacters(in: .whitespacesAndNewlines)
        // Marcar vazio geraria "****" na tela.
        buf += corte.isEmpty ? interno : "\(marca)\(corte)\(marca)"
    }

    private static func descarrega(_ segs: inout [ContentSegment], _ buf: inout String) {
        let texto = normaliza(buf)
        if !texto.isEmpty { segs.append(.text(texto)) }
        buf = ""
    }

    private static func normaliza(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        r = r.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        r = r.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        // Separador de célula que sobrou no fim/começo de linha não ajuda ninguém.
        r = r.replacingOccurrences(of: "(^|\\n) · ", with: "$1", options: .regularExpression)
        r = r.replacingOccurrences(of: " · (\\n|$)", with: "$1", options: .regularExpression)
        return r.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let mapaSobrescrito: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
        "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻", "n": "ⁿ",
    ]
    private static let mapaSubscrito: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅",
        "6": "₆", "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋",
    ]

    private static func sobrescrito(_ s: String) -> String { converte(s, mapaSobrescrito, "^") }
    private static func subscrito(_ s: String) -> String { converte(s, mapaSubscrito, "_") }

    /// Converte pra Unicode quando TODO o conteúdo tem equivalente; senão marca
    /// com ^ ou _ . Meia conversão ("m²x") seria pior que marcação explícita.
    private static func converte(_ s: String, _ mapa: [Character: Character], _ marca: String) -> String {
        let corte = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corte.isEmpty else { return "" }
        if corte.allSatisfy({ mapa[$0] != nil }) {
            return String(corte.map { mapa[$0]! })
        }
        return "\(marca)\(corte)"
    }

    private static func semTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
