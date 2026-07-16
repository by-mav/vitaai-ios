import Foundation
import SwiftUI

// MARK: - FlashcardCardView

/// Animated flip card matching flashcard-session-v1.html mockup.
/// - Front: uppercase tag, question, italic hint at bottom
/// - Back: "Resposta" tag, divider ouro, answer text
struct FlashcardCardView: View {

    let front: String
    let back: String
    let deckTitle: String
    let isFlipped: Bool
    var onFlip: () -> Void

    @State private var rotationDegrees: Double = 0

    /// Cards cloze do motor ({{c1::resposta}}): no front a resposta vira lacuna
    /// estilo Anki; no back a marcacao some e o texto fica limpo. Cards basic
    /// nao tem a sintaxe e passam intactos.
    private var isCloze: Bool {
        front.range(of: #"\{\{c\d+::[^}]+\}\}"#, options: .regularExpression) != nil
    }

    private var displayFront: String {
        front.replacingOccurrences(
            of: #"\{\{c\d+::[^}]+\}\}"#, with: "____", options: .regularExpression
        )
    }

    /// Cloze: o verso revela a frase inteira com a peca preenchida (+ complemento
    /// do back). Basic: verso = back normal.
    private var displayBack: String {
        guard isCloze else { return back }
        let revealed = front.replacingOccurrences(
            of: #"\{\{c\d+::([^}]+)\}\}"#, with: "$1", options: .regularExpression
        )
        let complement = back.trimmingCharacters(in: .whitespacesAndNewlines)
        return complement.isEmpty ? revealed : "\(revealed)\n\n\(complement)"
    }

    var body: some View {
        ZStack {
            frontFace
                .opacity(rotationDegrees < 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotationDegrees), axis: (0, 1, 0), perspective: 0.4)

            backFace
                .opacity(rotationDegrees >= 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotationDegrees - 180), axis: (0, 1, 0), perspective: 0.4)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFlip() }
        .accessibilityLabel(isFlipped
            ? "Resposta: \(displayBack). Toque para ver a pergunta."
            : "Flashcard: \(displayFront). Toque para revelar a resposta."
        )
        .onChange(of: isFlipped) { flipped in
            withAnimation(.easeInOut(duration: 0.5)) {
                rotationDegrees = flipped ? 180 : 0
            }
        }
    }

    // MARK: Front face

    private var frontFace: some View {
        cardShell {
            VStack(spacing: 0) {
                // Card LIMPO: sem label de título dentro (o título do baralho e o
                // "Frente" vivem no header). Só o conteúdo, centralizado. Rafael 2026-07-15.
                FlashcardContentView(
                    content: displayFront,
                    fontSize: 20,
                    textColor: VitaColors.white.opacity(0.95),
                    alignment: .center
                )
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)

                // Hint — italic, rgba(255,255,255,0.18), centered at bottom
                Text("Toque para ver a resposta")
                    .font(.system(size: 11, weight: .regular).italic())
                    .foregroundStyle(Color.white.opacity(0.18))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Back face

    private var backFace: some View {
        cardShell {
            VStack(spacing: 0) {
                // Verso LIMPO: sem label "RESPOSTA" nem divisor dentro do card (o "Verso"
                // vive no header). Só o conteúdo, centralizado igual à frente. Rafael 2026-07-15.
                if isCloze {
                    ClozeRevealContent(
                        source: front,
                        complement: back.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                } else {
                    FlashcardContentView(
                        content: back,
                        fontSize: 20,
                        textColor: VitaColors.white.opacity(0.95),
                        alignment: .center
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: Card shell — border-radius 22, gradient bg, border rgba(148,75,220,0.20)

    // Superfície canônica compartilhada (FlashcardCardSurface) — usada também pelo
    // editor, pra o card editado ser idêntico ao estudado.
    @ViewBuilder
    private func cardShell<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content().flashcardCardSurface()
    }
}

// MARK: - Cloze reveal

/// Reconstrói a frase declarativa no verso e aplica hierarquia somente às
/// respostas que estavam ocultas no front (`{{c1::resposta}}`).
private struct ClozeRevealContent: View {
    let source: String
    let complement: String

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Mesma tipografia/centro da frente (size 20, centralizado)
            Text(revealedSentence)
                .font(VitaTypography.headlineSmall.weight(.medium))
                .foregroundStyle(VitaColors.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)

            if !complement.isEmpty {
                Rectangle()
                    .fill(VitaColors.glassBorder.opacity(0.55))
                    .frame(width: 40, height: 0.5)

                FlashcardContentView(
                    content: complement,
                    fontSize: 15,
                    textColor: VitaColors.textSecondary,
                    alignment: .center
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var revealedSentence: AttributedString {
        // Decodifica &nbsp;/entidades + remove tags ANTES de montar a frase.
        let clean = flashcardDecodeText(source)
        let pattern = #"\{\{c\d+::([^}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return AttributedString(clean)
        }

        let ns = clean as NSString
        let matches = regex.matches(in: clean, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return AttributedString(clean) }

        var result = AttributedString()
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                result += AttributedString(
                    ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                )
            }

            // {{cN::resposta::dica}} -> só a resposta (a dica do cloze não entra no verso)
            let inner = ns.substring(with: match.range(at: 1))
            let answerText = inner.components(separatedBy: "::").first ?? inner
            var answer = AttributedString(answerText)
            answer.foregroundColor = VitaColors.dataRed
            answer.font = .system(size: 20, weight: .bold)
            answer.underlineStyle = Text.LineStyle(
                pattern: .solid,
                color: VitaColors.dataRed.opacity(0.72)
            )
            result += answer
            cursor = match.range.location + match.range.length
        }

        if cursor < ns.length {
            result += AttributedString(
                ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            )
        }
        return result
    }
}
