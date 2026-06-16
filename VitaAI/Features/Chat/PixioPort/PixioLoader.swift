import SwiftUI

// MARK: - PixioLoader — canon de loading (Rafael 2026-06-13: mascote temático + "pensando")
//
// SOT do loading do app. Substitui `ProgressView()` em TODO lugar. É o MASCOTE
// Pixio (a fotinho) tingido na COR DO TEMA ativo — troca de cor junto com o app —
// com um efeito "pensando" clean: 3 pontinhos na cor do tema pulsando em onda.
// Mesmo mascote do EmptyState. (Antes era o planeta-orbitando, "horrível" — Rafael
// deletou 2026-06-13.)
//
// Gate bloqueia `ProgressView()` raw — bypass pontual: `// pixio-loader-ignore: <razão>`.
//
// Tamanhos: .small 28 · .medium 48 · .large 80 (mascote).
//
// Uso:
//   PixioLoader()                                  // medium
//   PixioLoader(size: .small)
//   PixioLoader(size: .large, showsLabel: "Sincronizando bancos…")

struct PixioLoader: View {
    enum Size {
        case small, medium, large
        var mascot: CGFloat { self == .small ? 28 : self == .medium ? 48 : 80 }
        var dot: CGFloat { self == .small ? 4 : self == .medium ? 6 : 8 }
        var gap: CGFloat { self == .small ? 8 : self == .medium ? 10 : 14 }
        // compat: alguns call sites antigos liam .canvas
        var canvas: CGFloat { mascot }
    }

    let size: Size
    let showsLabel: String?

    init(size: Size = .medium, showsLabel: String? = nil) {
        self.size = size
        self.showsLabel = showsLabel
    }

    @State private var animating = false

    private var themeColor: Color { PixioCoState.shared.activeThemeColor.color }

    var body: some View {
        VStack(spacing: size.gap) {
            // Mascote tingido pelo tema ativo (troca de cor com o app) + breathing + glow.
            Image(PixioCoState.shared.activeThemeColor.mascotIdleAsset)
                .resizable()
                .scaledToFit()
                .frame(width: size.mascot, height: size.mascot)
                // pixio-design-gate-ignore: glow do mascote na cor do tema (assinatura Pixio)
                .shadow(color: themeColor.opacity(0.35), radius: size.mascot * 0.16, x: 0, y: 3)
                .scaleEffect(animating ? 1.05 : 0.97)
                .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: animating)

            // "Pensando" — 3 pontinhos na cor do tema, pulsando em onda (stagger).
            HStack(spacing: size.dot) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(themeColor)
                        .frame(width: size.dot, height: size.dot)
                        .opacity(animating ? 1.0 : 0.3)
                        .scaleEffect(animating ? 1.0 : 0.65)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: animating
                        )
                }
            }

            if let label = showsLabel {
                Text(label)
                    .font(PixioTypo.caption)
                    .foregroundStyle(PixioColor.textLightMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel(showsLabel ?? "Carregando")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Convenience wrappers

extension PixioLoader {
    /// Inline pequeno — pra dentro de Button/Row.
    static var inline: PixioLoader { PixioLoader(size: .small) }

    /// Default canon — sheets/cards.
    static var standard: PixioLoader { PixioLoader(size: .medium) }

    /// Fullscreen — overlays, sync longo.
    static func fullscreen(label: String? = nil) -> PixioLoader {
        PixioLoader(size: .large, showsLabel: label)
    }
}
