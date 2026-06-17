import SwiftUI

// MARK: - PixioMaterial — material premium (PORT do Pixio, cor Vita)
//
// Fonte: pixio-ios `Pixio/DesignSystem/PixioDesign.swift` (enum PixioMaterial +
// modifiers). Estrutura/forma do Pixio; cores resolvem via PixioCompat nos tokens
// DOURADOS do Vita. SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
//
// raisedFill = superfície ELEVADA (pega luz de cima). rimStroke = fio de luz no
// topo da borda. pixioFieldSurface = campo RECESSO (afunda: inner shadow).

enum PixioMaterial {
    /// Superfície ELEVADA — gradiente que pega luz de cima (claro no topo → borda embaixo).
    static var raisedFill: LinearGradient {
        LinearGradient(colors: [PixioColor.cardLight, PixioColor.borderLight],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Rim light — fio de luz no topo da borda (reflexo que dá "vida" à peça).
    static var rimStroke: LinearGradient {
        LinearGradient(colors: [PixioColor.premiumText.opacity(0.5), .clear],
                       startPoint: .top, endPoint: .center)
    }

    /// Largura do rim.
    static let rimWidth: CGFloat = 0.75
}

extension View {
    /// Veste o conteúdo com o material ELEVADO premium (fill + rim) numa shape.
    /// A sombra de elevação fica por conta do call site (varia com o tamanho da peça).
    func pixioRaised<S: InsettableShape>(in shape: S) -> some View {
        self
            .background(shape.fill(PixioMaterial.raisedFill))
            .overlay(shape.strokeBorder(PixioMaterial.rimStroke, lineWidth: PixioMaterial.rimWidth))
    }

    /// Material RECESSO premium pra CAMPO de input (afundado: inner shadow + borda
    /// sutil). O oposto do `pixioRaised`: input AFUNDA, botão FLUTUA.
    func pixioFieldSurface(cornerRadius: CGFloat = PixioRadius.button) -> some View {
        modifier(PixioFieldSurfaceModifier(cornerRadius: cornerRadius))
    }
}

private struct PixioFieldSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(
                shape.fill(
                    PixioColor.textLightMuted.opacity(scheme == .dark ? 0.16 : 0.08)
                        .shadow(.inner(color: .black.opacity(scheme == .dark ? 0.45 : 0.07), radius: 2, x: 0, y: 1))
                )
            )
            .overlay(shape.strokeBorder(PixioColor.borderLight.opacity(0.8), lineWidth: 0.75))
    }
}
