import SwiftUI
import UIKit

// PixioCompat — camada de compatibilidade que expoe a API de design do Pixio
// (PixioColor / PixioSpacing / PixioTypo / PixioHaptics / PixioShadow) com os
// MESMOS nomes do Pixio, resolvendo nos tokens DOURADOS do Vita. Permite colar
// telas do Pixio iOS VERBATIM (forma/sombra/textura/posicao identicas) sem
// arrastar o cerebro/mascote do Pixio. Estrutura do Pixio, cor do Vita.
// Pixio = referencia CONGELADA. SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md

enum PixioColor {
    // marca (Pixio grafite -> dourado Vita)
    static let brand        = VitaColors.accent
    static let brandLight   = VitaColors.accentLight
    static let brandDark    = VitaColors.accentDark
    static let premium      = VitaColors.accent
    static let premiumSoft  = VitaColors.accentHover
    static let premiumText  = VitaColors.goldText
    // superficies (Pixio "light" surface system -> superficies Vita)
    static let pageLight       = VitaColors.surface
    static let cardLight       = VitaColors.surfaceCard
    static let borderLight     = VitaColors.surfaceBorder
    static let textLight       = VitaColors.textPrimary
    static let textLightMuted  = VitaColors.textSecondary
    static let textLightFaint  = VitaColors.textTertiary
    static let textPrimary     = VitaColors.textPrimary
    static let textSecondary   = VitaColors.textSecondary
    static let textMuted       = VitaColors.textTertiary
    static let surface         = VitaColors.surface
    static let void            = VitaColors.surface
    static let graphiteBlue    = VitaColors.surfaceElevated
    // semanticas
    static let positive  = VitaColors.success
    static let negative  = VitaColors.danger
    static let warning   = VitaColors.warning
    static let success   = VitaColors.success
    static let error     = VitaColors.danger
    // paleta de categoria (icones) -> cores de dado do Vita
    static let catGreen   = VitaColors.dataGreen
    static let catCyan    = VitaColors.dataTeal
    static let catBlue    = VitaColors.dataBlue
    static let catAmber   = VitaColors.dataAmber
    static let catYellow  = VitaColors.dataAmber
    static let catOrange  = VitaColors.dataAmber
    static let catViolet  = VitaColors.dataIndigo
    static let catIndigo  = VitaColors.dataIndigo
    static let catPink     = VitaColors.dataRed
    static let catPurple   = VitaColors.dataIndigo
    static let catRed      = VitaColors.dataRed
    static let catSlate    = VitaColors.textTertiary
    static let catGray     = VitaColors.textTertiary
    static let catGrayLt   = VitaColors.textTertiary
}

enum PixioSpacing {
    static let none: CGFloat = 0
    static let xxs:  CGFloat = 2
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let screenH: CGFloat = 20
    static let section: CGFloat = 32
    static let intra:   CGFloat = 16
}

enum PixioTypo {
    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(VitaTokens.Typography.fontFamilySans, size: size).weight(weight)
    }
    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(VitaTokens.Typography.fontFamilyMono, size: size).weight(weight)
    }
    static func geist(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        sans(size: size, weight: weight)
    }
    static var screenTitle: Font { sans(size: 28, weight: .bold) }
    static var title: Font       { sans(size: 22, weight: .bold) }
    static var cardTitle: Font   { sans(size: 17, weight: .semibold) }
    static var body: Font        { sans(size: 15, weight: .medium) }
    static var caption: Font     { sans(size: 12, weight: .medium) }
    static var micro: Font       { sans(size: 10, weight: .semibold) }
    static var sectionLabel: Font { sans(size: 11, weight: .bold) }
}

enum PixioHaptics {
    static func tap()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

enum PixioShadow {
    static func contact(dark: Bool) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(dark ? 0.45 : 0.10), 8, 0, 3)
    }
    static func ambient(dark: Bool) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(dark ? 0.35 : 0.08), 20, 0, 8)
    }
    static func projected(dark: Bool) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(dark ? 0.5 : 0.14), 24, 0, 10)
    }
    static func glow(_ color: Color, intensity: Double = 0.45) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (color.opacity(intensity), 14, 0, 6)
    }
}
