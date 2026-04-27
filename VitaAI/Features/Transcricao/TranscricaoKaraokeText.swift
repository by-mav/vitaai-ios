import SwiftUI

/// Transcript com word-level karaoke highlight + tap em qualquer palavra
/// pula áudio. Implementação via AttributedString com link custom — SwiftUI
/// Text.reduce concatena num Text único e NÃO suporta tap por palavra.
/// AttributedString + URL handler é o jeito que funciona.
///
/// Custom URL scheme `vita-tap-word://<index>` interceptado pelo openURL
/// handler que chama onTapWord(idx).
struct TranscricaoKaraokeText: View {
    let words: [WhisperWord]
    let signals: [ProfessorSignals.Signal]
    let activeWordIndex: Int?
    let isPlaying: Bool
    let onTapWord: (Int) -> Void

    /// Word indices que match um ProfessorSignals (palavras-chave do prof).
    /// Pre-computado via overlap de char ranges.
    private var signalIndices: Set<Int> {
        guard !signals.isEmpty else { return [] }
        let fullText = words.map(\.word).joined(separator: " ")
        let lowerFull = fullText.lowercased()
        var indices = Set<Int>()
        for signal in signals {
            var charPos = 0
            for (i, _) in words.enumerated() {
                let wordStart = charPos
                let wordEnd = charPos + words[i].word.count
                let signalStart = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.lowerBound)
                let signalEnd = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.upperBound)
                if wordStart < signalEnd && wordEnd > signalStart {
                    indices.insert(i)
                }
                charPos = wordEnd + 1
            }
        }
        return indices
    }

    private func signalColor(for wordIndex: Int) -> Color {
        let fullText = words.map(\.word).joined(separator: " ")
        let lowerFull = fullText.lowercased()
        var charPos = 0
        for (i, word) in words.enumerated() {
            if i == wordIndex {
                for signal in signals {
                    let signalStart = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.lowerBound)
                    let signalEnd = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.upperBound)
                    let wordEnd = charPos + word.word.count
                    if charPos < signalEnd && wordEnd > signalStart {
                        return signal.category.color
                    }
                }
                break
            }
            charPos += word.word.count + 1
        }
        return VitaColors.accentLight
    }

    /// Constrói AttributedString com cada palavra colorida pelo estado
    /// (active/passed/upcoming/signal) + link `vita-tap-word://<idx>` pra
    /// permitir tap.
    private var attributed: AttributedString {
        let active = activeWordIndex ?? -1
        var result = AttributedString()
        for (idx, word) in words.enumerated() {
            var token = AttributedString(word.word)
            token.font = .system(size: 13)

            let isActive = idx == active && isPlaying
            let isPassed = isPlaying && idx < active
            let isSignal = signalIndices.contains(idx)

            if isSignal {
                token.foregroundColor = signalColor(for: idx)
                token.font = .system(size: 13, weight: .semibold)
                token.underlineStyle = .single
            } else if isActive {
                token.foregroundColor = VitaColors.accentLight
                token.font = .system(size: 13, weight: .semibold)
            } else if isPassed {
                token.foregroundColor = Color.white.opacity(0.70)
            } else {
                token.foregroundColor = Color.white.opacity(0.45)
            }

            // Link invisível habilita tap. Scheme `vita-tap-word://` interceptado
            // pelo openURL handler abaixo.
            if let url = URL(string: "vita-tap-word://\(idx)") {
                token.link = url
            }

            result.append(token)
            if idx < words.count - 1 {
                var space = AttributedString(" ")
                space.font = .system(size: 13)
                space.foregroundColor = Color.white.opacity(0.30)
                result.append(space)
            }
        }
        return result
    }

    var body: some View {
        Text(attributed)
            .lineSpacing(6)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 12)
            .animation(.easeOut(duration: 0.18), value: activeWordIndex)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "vita-tap-word",
                      let host = url.host,
                      let idx = Int(host) else {
                    return .systemAction
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapWord(idx)
                return .handled
            })
    }
}

// MARK: - Fallback: Plain transcript with professor signal highlights only (no word timestamps)

struct TranscricaoHighlightedText: View {
    let text: String
    let signals: [ProfessorSignals.Signal]

    var body: some View {
        if signals.isEmpty {
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(4)
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12)
        } else {
            Text(ProfessorSignals.highlightedWithDefault(text, signals: signals))
                .font(.system(size: 12))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12)
        }
    }
}
