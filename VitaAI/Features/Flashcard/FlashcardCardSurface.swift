import SwiftUI

// MARK: - Superfície canônica do card
//
// Gradiente + borda + brilho + sombra do card. FONTE ÚNICA usada pelo card de
// estudo (FlashcardCardView) E pelo editor (CardEditorScreen) — assim o que o
// aluno edita é visualmente idêntico ao que ele estuda. Mexeu aqui, muda nos dois.

enum FlashcardCardStyle {
    static let corner: CGFloat = 22
    static let gradient = LinearGradient(
        colors: [VitaTokens.DarkColors.bgHover, VitaColors.surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct FlashcardCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .fill(FlashcardCardStyle.gradient)

            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)

            // brilho especular no canto superior direito
            RoundedRectangle(cornerRadius: FlashcardCardStyle.corner)
                .fill(
                    RadialGradient(
                        colors: [VitaColors.accent.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.85, y: 0.15),
                        startRadius: 0,
                        endRadius: 120
                    )
                )

            content
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
        }
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 12)
        .shadow(color: VitaColors.accent.opacity(0.20), radius: 24, x: 0, y: 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Aplica a superfície canônica do card (gradiente + borda + brilho + sombra).
    func flashcardCardSurface() -> some View { modifier(FlashcardCardSurface()) }
}
