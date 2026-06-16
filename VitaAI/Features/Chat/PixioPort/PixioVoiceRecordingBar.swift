import SwiftUI

// MARK: - PixioVoiceRecordingBar (Rafael 2026-05-14)
//
// Inline voice recording UI que SUBSTITUI o input row do chat enquanto user
// fala. Pattern ChatGPT/Claude 2026: bar shape com [Stop] [Waveform] [Send].
//
// Flow:
//   1. User tap no mic do ChatInput → bar aparece + recording inicia
//   2. Enquanto fala: waveform anima (decorativo agora, amplitude real depois)
//   3. Tap [Stop] (quadrado branco esquerda) → cancela (sem enviar)
//   4. Tap [Send] (arrow up preto direita) → para gravação + transcreve +
//      callback com texto pra ChatViewModel.send() automático
//
// Usa SpeechRecognitionManager existente (SFSpeechRecognizer on-device).
// Transcript final via callback onSend.

struct PixioVoiceRecordingBar: View {
    /// Callback quando user tap em send — recebe transcript final.
    let onSend: (String) -> Void
    /// Callback quando user tap em stop — cancela sem enviar.
    let onCancel: () -> Void

    @State private var speech = SpeechRecognitionManager()
    @State private var animationPhase: Double = 0

    private let barCount: Int = 28

    var body: some View {
        HStack(spacing: 12) {
            // ─── Stop button (esquerda, branco com quadrado preto) ────────
            Button {
                PixioHaptics.tap()
                speech.stopListening()
                onCancel()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(PixioColor.textLightMuted.opacity(0.15), lineWidth: 0.5)
                        )
                    Image(systemName: "square.fill")
                        .font(PixioTypo.sans(size: 13, weight: .regular))
                        .foregroundStyle(PixioColor.textLight)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancelar gravação")

            // ─── Waveform bars (centro) ──────────────────────────────────
            waveformView
                .frame(maxWidth: .infinity)

            // ─── Send button (direita, preto com seta branca) ────────────
            Button {
                PixioHaptics.confirm()
                speech.stopListening()
                // Transcript final pode estar em `transcribedText` (final) ou
                // `partialText` (ainda streaming) — pega o mais recente.
                let text = !speech.transcribedText.isEmpty
                    ? speech.transcribedText
                    : speech.partialText
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSend(trimmed)
                } else {
                    onCancel()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(PixioColor.textLight)
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.up")
                        .font(PixioTypo.sans(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enviar")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(PixioColor.cardLight)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .onAppear {
            Task {
                await speech.requestPermissions()
                speech.startListening()
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            }
        }
        .onDisappear {
            speech.stopListening()
        }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        // Decorative waveform: bars com altura modulada por sine wave + fase
        // animada. MVP — em V2 substitui por amplitude real do mic.
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(PixioColor.textLightMuted)
                    .frame(width: 2.5, height: barHeight(for: i))
            }
        }
        .frame(height: 32)
        .clipped()
    }

    /// Altura de cada barra: combinação de função sine + posição + phase.
    /// Resultado: padrão que parece "respirar" como áudio real, sem precisar
    /// medir amplitude do mic ainda.
    private func barHeight(for index: Int) -> CGFloat {
        let normalized = Double(index) / Double(barCount - 1)
        // 3 ondas senoidais sobrepostas com frequências diferentes
        let wave1 = sin(normalized * 6 + animationPhase * 4) * 0.4
        let wave2 = sin(normalized * 11 + animationPhase * 7) * 0.3
        let wave3 = sin(normalized * 3 + animationPhase * 2) * 0.3
        let combined = abs(wave1 + wave2 + wave3)
        let baseHeight: CGFloat = 4
        let maxExtra: CGFloat = 24
        return baseHeight + CGFloat(combined) * maxExtra
    }
}

#if DEBUG
#Preview("Voice Recording Bar") {
    VStack {
        Spacer()
        PixioVoiceRecordingBar(
            onSend: { text in print("Send:", text) },
            onCancel: { print("Cancel") }
        )
    }
    .background(PixioColor.surface)
}
#endif
