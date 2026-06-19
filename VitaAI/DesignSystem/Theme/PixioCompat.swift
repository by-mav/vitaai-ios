import SwiftUI
import UIKit
import Observation

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

// ---- Extensao p/ port do chat (PixioRadius + scrim/mascot + .pixioGlass) ----

extension PixioColor {
    static let scrim       = Color.black.opacity(0.18)
    static let glassBorder = VitaColors.glassBorder
    static let mascot      = VitaColors.accent       // tema Vita = dourado
    static let mascotLight = VitaColors.accentLight
    static let mascotDark  = VitaColors.accentDark
}

enum PixioRadius {
    static let card: CGFloat = 18
    static let hero: CGFloat = 22
    static let large: CGFloat = 24
    static let button: CGFloat = 12
    static let buttonPill: CGFloat = 999
    static let pill: CGFloat = 999
    static let iconCircle: CGFloat = 20
    static let iconBadge: CGFloat = 14
    static let chip: CGFloat = 8
    static let tag: CGFloat = 6
}

enum PixioGlassStyle {
    case regular, thin, thick
    /// Vidro "transparente tingido" — usado nas bolhas do usuário e no indicador
    /// "Pensando". Carrega a cor do tint (ex.: dourado Vita com opacity).
    case clearTinted(Color)
}

extension View {
    @ViewBuilder
    func pixioGlass<S: Shape>(_ style: PixioGlassStyle = .regular, in shape: S) -> some View {
        switch style {
        case .clearTinted(let tint):
            // Vidro fosco + camada de cor (tint) por cima — bolha do usuário /
            // "Pensando". Mantém legível em claro e escuro.
            self
                .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill(tint))
        default:
            self.background(shape.fill(.ultraThinMaterial))
        }
    }
    @ViewBuilder
    func pixioGlassInteractive<S: Shape>(in shape: S) -> some View {
        self.pixioGlass(.regular, in: shape)
    }
}

// ---- Shim do estado de tema/mascote do Pixio (Vita = dourado, mascote vita-btn) ----
enum PixioThemeColor: Equatable {
    case teal, gold, burgundy, royal, violet
    case custom(hue: Double)
    var color: Color { VitaColors.accent }
    var colorLight: Color { VitaColors.accentLight }
    var colorDark: Color { VitaColors.accentDark }
    static func tintedMascot(asset: String, for theme: PixioThemeColor) -> UIImage? {
        UIImage(named: "vita-btn-active")
    }
}
@Observable
final class PixioCoState {
    static let shared = PixioCoState()
    var activeThemeColor: PixioThemeColor = .gold
}

// ---- Extras p/ os sub-componentes de chat (tile premium, premium light/dark, assets do mascote) ----
extension PixioColor {
    static let premiumLight = VitaColors.accentLight
    static let premiumDark  = VitaColors.accentDark
}
extension PixioThemeColor {
    var mascotIdleAsset: String   { "vita-btn-idle" }
    var mascotActiveAsset: String { "vita-btn-active" }
}
struct PixioPremiumTile<Content: View>: View {
    let size: CGFloat
    let corner: CGFloat
    @ViewBuilder var content: () -> Content
    init(size: CGFloat, corner: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.size = size; self.corner = corner; self.content = content
    }
    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(PixioColor.borderLight.opacity(0.5), lineWidth: 0.5))
    }
}

// ---- Membros extras p/ sub-componentes do chat ----
extension PixioTypo {
    static var callout: Font       { sans(size: 14, weight: .medium) }
    static var bodySecondary: Font { sans(size: 13, weight: .regular) }
}
extension PixioHaptics {
    static func confirm() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
extension PixioColor {
    static let premiumGradient = LinearGradient(colors: [VitaColors.accent, VitaColors.accentDark], startPoint: .topLeading, endPoint: .bottomTrailing)
}


// ---- Stub: Vita nao usa artifacts (Pixio chat referencia o tipo) ----
struct ChatArtifact: Identifiable, Equatable { let id = UUID() }
extension ChatMessage { var artifact: ChatArtifact? { nil } }
