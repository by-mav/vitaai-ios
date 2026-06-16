import SwiftUI
import UIKit

// VitaShellKit — ponte de conveniencia p/ componentes portados do Pixio iOS.
// "Estrutura do Pixio, cor do Vita": expoe os nomes que os componentes do
// Pixio referenciam (PixioColor/Spacing/Typo/Haptics) resolvendo nos tokens
// DOURADOS do Vita (VitaColor / VitaTokens). NAO traz mascote/tema do Pixio.
// Pixio e referencia CONGELADA — nunca editar o Pixio.
// SOT do port: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md

enum VitaShellColor {
    // Superficies neutras (Pixio "light" surface system -> superficies Vita)
    static let pageLight      = VitaColors.surface
    static let cardLight      = VitaColors.surfaceCard
    static let borderLight    = VitaColors.surfaceBorder
    static let textLight      = VitaColors.textPrimary
    static let textLightMuted = VitaColors.textSecondary
    static let textLightFaint = VitaColors.textTertiary
    static let textPrimary    = VitaColors.textPrimary
    static let textSecondary  = VitaColors.textSecondary
    // Marca premium (Pixio grafite -> dourado Vita)
    static let premium        = VitaColors.accent
    static let premiumText    = VitaColors.goldText
    // Semanticas
    static let positive       = VitaColors.success
    static let negative       = VitaColors.danger
    // Paleta de categoria (icones da gaveta) -> cores de dado do Vita
    static let catGreen       = VitaColors.dataGreen
    static let catCyan        = VitaColors.dataTeal
    static let catBlue        = VitaColors.dataBlue
    static let catAmber       = VitaColors.dataAmber
    static let catViolet      = VitaColors.dataIndigo
    static let catPink        = VitaColors.dataRed
}

enum VitaShellSpacing {
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

enum VitaShellType {
    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(VitaTokens.Typography.fontFamilySans, size: size).weight(weight)
    }
    static func geist(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        sans(size: size, weight: weight)
    }
    static var screenTitle: Font { sans(size: 28, weight: .bold) }
    static var cardTitle:   Font { sans(size: 17, weight: .semibold) }
    static var body:        Font { sans(size: 15, weight: .medium) }
    static var caption:     Font { sans(size: 12, weight: .medium) }
    static var micro:       Font { sans(size: 10, weight: .semibold) }
}

enum VitaShellHaptics {
    static func tap()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}
