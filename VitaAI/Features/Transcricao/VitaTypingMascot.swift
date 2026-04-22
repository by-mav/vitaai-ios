import SwiftUI

/// Mascote do Vita "digitando" enquanto a transcrição está ativa.
///
/// Visual layering, top → bottom:
/// 1. `btn-transcricao` (mascote orb gold, já existente)
/// 2. Keyboard glyph (SF Symbol `keyboard.fill`) abaixo do mascote
/// 3. Cursor piscante (barra vertical) à direita do teclado
///
/// Comportamento:
/// - `isRecording == false` → estático, igual ao mascote original
/// - `isRecording == true`  → cursor pisca 800ms on/off, teclado pulsa
///   (scale 1.0 → 0.94 → 1.0) em loop 600ms, simulando digitação
/// - Respeita `UIAccessibility.isReduceMotionEnabled`: sem animações
struct VitaTypingMascot: View {
    let isRecording: Bool
    let size: CGFloat

    @State private var cursorVisible = true
    @State private var keyPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("btn-transcricao")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size)
                .shadow(color: VitaColors.accent.opacity(0.30), radius: 20)
                .opacity(isRecording ? 0.85 : 1.0)
                .scaleEffect(isRecording ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.4), value: isRecording)

            if isRecording {
                keyboardStrip
                    .offset(y: size * 0.08)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: size)
        .onAppear { startAnimations() }
        .onChange(of: isRecording) { _, recording in
            if recording { startAnimations() }
        }
    }

    private var keyboardStrip: some View {
        HStack(spacing: 4) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: size * 0.18, weight: .regular))
                .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                .scaleEffect(keyPressed ? 0.94 : 1.0)
                .shadow(color: VitaColors.accent.opacity(0.45), radius: 6)

            RoundedRectangle(cornerRadius: 1)
                .fill(VitaColors.accentLight.opacity(cursorVisible ? 0.9 : 0))
                .frame(width: 2, height: size * 0.16)
                .shadow(color: VitaColors.accent.opacity(0.6), radius: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func startAnimations() {
        guard isRecording, !reduceMotion else {
            cursorVisible = true
            keyPressed = false
            return
        }
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            cursorVisible.toggle()
        }
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            keyPressed.toggle()
        }
    }
}

#Preview("idle") {
    VitaTypingMascot(isRecording: false, size: 155)
        .padding(40)
        .background(Color.black)
}

#Preview("recording") {
    VitaTypingMascot(isRecording: true, size: 155)
        .padding(40)
        .background(Color.black)
}
