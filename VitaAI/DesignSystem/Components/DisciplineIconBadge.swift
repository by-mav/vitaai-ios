import SwiftUI

/// Badge redondo de disciplina/área — glifo semântico (DisciplineImages.iconSpec)
/// sobre círculo com gradiente da cor + highlight especular + glow. É o MESMO
/// visual da home dos flashcards (FlashcardBuilderScreen.deckIconTile), extraído
/// pra reuso (Rafael 2026-07-16: mesma taxonomia, mesmos ícones em todo lugar).
struct DisciplineIconBadge: View {
    /// Nome da disciplina OU da grande área (resolve símbolo+cor pelo iconSpec).
    let name: String
    var size: CGFloat = 50

    var body: some View {
        let spec = DisciplineImages.iconSpec(for: name)
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [spec.color.opacity(0.95), spec.color.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            Image(systemName: spec.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))  // ds-allow: glifo do ícone (não é texto)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: spec.color.opacity(0.35), radius: size * 0.1, y: 3)
    }
}
