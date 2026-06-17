import SwiftUI

// MARK: - PixioAuroraBackground — canon Liquid Glass bg (PORT do Pixio, cor Vita)
//
// Fonte: pixio-ios `Pixio/DesignSystem/Components/PixioAuroraBackground.swift`.
// Light = cinza Apple #F2F2F7 flat (Health/Settings systemGroupedBackground).
// Dark = preto graphite #0A0C10 + 2 fontes de luz na cor do tema (Vita = DOURADO,
// via PixioThemeColor.color → VitaColors.accent). Glass cards refratam ESTE bg.
// SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md

struct PixioAuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable private var coState = PixioCoState.shared

    /// Override opcional pra preview de cor temática. nil = lê do estado ativo.
    var themeOverride: PixioThemeColor? = nil

    /// Cor temática efetiva — override > activeThemeColor.
    private var themeColor: Color {
        (themeOverride ?? coState.activeThemeColor).color
    }

    var body: some View {
        if scheme == .light {
            lightAmbient
        } else {
            darkAurora
        }
    }

    // Light = cinza Apple #F2F2F7 flat (pattern Apple-native systemGroupedBackground).
    @ViewBuilder
    private var lightAmbient: some View {
        Color(hex: 0xF2F2F7)
            .ignoresSafeArea()
    }

    // Dark canon Liquid Glass — base graphite #0A0C10 + 2 fontes de luz distantes
    // (faróis fora da UI) na cor do tema. Decay 7-stops + blur 40 = luz difusa real.
    @ViewBuilder
    private var darkAurora: some View {
        ZStack {
            Color(red: 0x0A / 255.0, green: 0x0C / 255.0, blue: 0x10 / 255.0)
                .ignoresSafeArea()

            // Light source #1 — ESQUERDA, 30% altura.
            GeometryReader { geo in
                RadialGradient(
                    colors: [
                        themeColor.opacity(0.30),
                        themeColor.opacity(0.22),
                        themeColor.opacity(0.15),
                        themeColor.opacity(0.09),
                        themeColor.opacity(0.04),
                        themeColor.opacity(0.01),
                        themeColor.opacity(0)
                    ],
                    center: UnitPoint(x: -0.15, y: 0.30),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.85
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Light source #2 — DIREITA, 60% altura.
            GeometryReader { geo in
                RadialGradient(
                    colors: [
                        themeColor.opacity(0.26),
                        themeColor.opacity(0.19),
                        themeColor.opacity(0.13),
                        themeColor.opacity(0.07),
                        themeColor.opacity(0.03),
                        themeColor.opacity(0.01),
                        themeColor.opacity(0)
                    ],
                    center: UnitPoint(x: 1.15, y: 0.60),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.80
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }
}
