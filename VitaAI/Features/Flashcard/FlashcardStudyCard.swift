import SwiftUI

// MARK: - FlashcardStudyCard (reescrito do zero — Rafael 2026-07-17)
//
// Card de estudo à prova de vazamento. O card VELHO deixava o ZStack inchar até
// a largura do texto (cards longos como Farmacologia rendiam texto de 748pt numa
// tela de 402pt → vazava as bordas). Aqui um GeometryReader é a RAIZ: ele dá o
// tamanho REAL do card (finito, vindo do pai), as duas faces são travadas nesse
// tamanho e o texto é travado na largura do card. Logo:
//   • o texto SEMPRE quebra dentro do card;
//   • se ainda for alto demais, ENCOLHE (minimumScaleFactor no FlashcardContentView);
//   • nada infla a largura, seja qual for a proposta do shell.
//
// Mantém tudo do card antigo: flip 3D, frente/verso, cloze, superfície (gradiente
// + borda + brilho + sombra), tap pra virar.
struct FlashcardStudyCard: View {

    let front: String
    let back: String
    let isFlipped: Bool
    var onFlip: () -> Void

    @State private var rotationDegrees: Double = 0

    // Cloze ({{c1::resposta}}): na frente vira lacuna; no verso preenche.
    private var isCloze: Bool {
        front.range(of: #"\{\{c\d+::[^}]+\}\}"#, options: .regularExpression) != nil
    }

    private var displayFront: String {
        front.replacingOccurrences(
            of: #"\{\{c\d+::[^}]+\}\}"#, with: "____", options: .regularExpression
        )
    }

    private var displayBack: String {
        guard isCloze else { return back }
        let revealed = front.replacingOccurrences(
            of: #"\{\{c\d+::([^}]+)\}\}"#, with: "$1", options: .regularExpression
        )
        let complement = back.trimmingCharacters(in: .whitespacesAndNewlines)
        return complement.isEmpty ? revealed : "\(revealed)\n\n\(complement)"
    }

    var body: some View {
        // RAIZ: o GeometryReader dá o tamanho finito do card. As faces se travam
        // nele — o texto não consegue inchar a largura.
        GeometryReader { geo in
            ZStack {
                face(showHint: true, size: geo.size)
                    .opacity(rotationDegrees < 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(rotationDegrees), axis: (0, 1, 0), perspective: 0.4)

                face(showHint: false, size: geo.size)
                    .opacity(rotationDegrees >= 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(rotationDegrees - 180), axis: (0, 1, 0), perspective: 0.4)
            }
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

    // MARK: Face (frente = showHint true, verso = false)

    @ViewBuilder
    private func face(showHint: Bool, size: CGSize) -> some View {
        // Largura útil do texto = card menos o padding horizontal (24×2).
        let textWidth = max(size.width - 48, 1)

        ZStack {
            // Superfície (gradiente + borda + brilho especular)
            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .fill(FlashcardCardStyle.gradient)
            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .fill(
                    RadialGradient(
                        colors: [VitaColors.accent.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.85, y: 0.15),
                        startRadius: 0,
                        endRadius: 120
                    )
                )

            VStack(spacing: 0) {
                // Largura TRAVADA → o texto quebra. Conteúdo curto CENTRALIZA
                // (minHeight = altura útil); conteúdo longo (card "livro" de 1000+
                // chars) ROLA DENTRO do card em vez de vazar por trás dos botões.
                // Rafael 2026-07-18: um card de 2700 chars batia no piso do
                // minimumScaleFactor e transbordava a tela inteira.
                ScrollView(.vertical, showsIndicators: false) {
                    faceContent(showHint: showHint)
                        .frame(width: textWidth)
                        .frame(minHeight: max(size.height - 72, 1), alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)

                if showHint {
                    Text("Toque para ver a resposta")
                        .font(.system(size: 11, weight: .regular).italic())
                        .foregroundStyle(Color.white.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        // TRAVA a face no tamanho do card — nada infla a partir daqui.
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 12)
        .shadow(color: VitaColors.accent.opacity(0.20), radius: 24, x: 0, y: 0)
    }

    @ViewBuilder
    private func faceContent(showHint: Bool) -> some View {
        // frente = showHint; verso = !showHint
        if showHint {
            FlashcardContentView(
                content: displayFront,
                fontSize: 20,
                textColor: VitaColors.white.opacity(0.95),
                alignment: .center
            )
        } else if isCloze {
            ClozeRevealContent(
                source: front,
                complement: back.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            FlashcardContentView(
                content: back,
                fontSize: 20,
                textColor: VitaColors.white.opacity(0.95),
                alignment: .center
            )
        }
    }
}

// MARK: - Cloze reveal
//
// Reconstrói a frase declarativa no verso e destaca só as respostas que estavam
// ocultas na frente (`{{c1::resposta}}`).
struct ClozeRevealContent: View {
    let source: String
    let complement: String

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(revealedSentence)
                .font(VitaTypography.headlineSmall.weight(.medium))
                .foregroundStyle(VitaColors.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .center)

            if !complement.isEmpty {
                Rectangle()
                    .fill(VitaColors.glassBorder.opacity(0.55))
                    .frame(width: 40, height: 0.5)

                // Nota "Extra" do card. Legível (16, contraste maior) e COLADA no
                // divisor — o fixedSize impede o efeito de flutuar no meio do card
                // (o maxHeight:.infinity do FlashcardContentView inflava). Rafael 2026-07-17.
                FlashcardContentView(
                    content: complement,
                    fontSize: 16,
                    textColor: VitaColors.white.opacity(0.68),
                    alignment: .center
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var revealedSentence: AttributedString {
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
            let inner = ns.substring(with: match.range(at: 1))
            let answerText = inner.components(separatedBy: "::").first ?? inner
            var answer = AttributedString(answerText)
            answer.foregroundColor = VitaColors.dataRed
            answer.font = .system(size: 20, weight: .bold)
            answer.underlineStyle = Text.LineStyle(pattern: .solid, color: VitaColors.dataRed.opacity(0.72))
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
