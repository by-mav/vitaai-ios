import SwiftUI

/// Color palette shared across a StudySuite screen (hero, CTA, chips, recents).
///
/// Each of the four tools on the dashboard has a signature colour:
///   Questões   → laranja/âmbar (cérebro dourado)
///   Flashcards → roxo/magenta (coração anatómico)
///   Simulados  → azul elétrico (silhueta + escudo)
///   Transcrição → teal ciano (microfone + onda)
///
/// The shell screens reuse the same silhouette (hero + CTA + chips + recent
/// sessions) but take on the theme colour so the four pages feel connected
/// to their dashboard entry point rather than looking like identical gold
/// clones.
struct StudyShellTheme {
    /// Dominant hue used for the big headline number, chip selection, CTA
    /// gradient, and session card accents.
    let primary: Color
    /// Lighter tint (highlights, inner glows, eyebrow text).
    let primaryLight: Color
    /// Muted tint (borders, dividers, low-opacity motif).
    let primaryMuted: Color
    /// Top of the hero surface gradient (slight warm/cool lift).
    let surfaceTop: Color
    /// Bottom of the hero surface gradient (near-black, same hue family).
    let surfaceBottom: Color
    /// Colour of the radial accent glow in the top-right of the hero.
    let glow: Color
    /// SF Symbol used as the decorative motif in the hero top-right.
    let motifSymbol: String
    /// Short label for the tab (used by the hero eyebrow).
    let eyebrow: String

    // MARK: - Factory per tool

    static let questoes = StudyShellTheme(
        primary: VitaColors.accent,
        primaryLight: VitaColors.accentLight,
        primaryMuted: VitaColors.accent.opacity(0.30),
        surfaceTop: Color(red: 0.075, green: 0.078, blue: 0.095),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceBottom: Color(red: 0.030, green: 0.032, blue: 0.040),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        glow: VitaColors.accent,
        motifSymbol: "brain.head.profile",
        eyebrow: "Quest\u{f5}es"
    )

    // Vita é monocromático OURO (design system: "múltiplas accent colors proibido").
    // Flashcards era roxo/violeta — trocado pra gold accent (Rafael 2026-07-09).
    static let flashcards = StudyShellTheme(
        primary: VitaColors.accent,
        primaryLight: VitaColors.accentLight,
        primaryMuted: VitaColors.accent.opacity(0.30),
        surfaceTop: Color(red: 0.075, green: 0.078, blue: 0.095),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceBottom: Color(red: 0.030, green: 0.032, blue: 0.040),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        glow: VitaColors.accent,
        motifSymbol: "rectangle.on.rectangle",
        eyebrow: "Flashcards"
    )

    static let simulados = StudyShellTheme(
        primary: Color(red: 0.26, green: 0.64, blue: 1.00),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        primaryLight: Color(red: 0.50, green: 0.77, blue: 1.00),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        primaryMuted: Color(red: 0.26, green: 0.64, blue: 1.00).opacity(0.35),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceTop: Color(red: 0.03, green: 0.10, blue: 0.22),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceBottom: Color(red: 0.015, green: 0.045, blue: 0.115),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        glow: Color(red: 0.42, green: 0.76, blue: 1.00),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        motifSymbol: "doc.text.magnifyingglass",
        eyebrow: "Simulados"
    )

    static let transcricao = StudyShellTheme(
        primary: Color(red: 0.25, green: 0.85, blue: 0.76),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        primaryLight: Color(red: 0.50, green: 0.92, blue: 0.85),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        primaryMuted: Color(red: 0.25, green: 0.85, blue: 0.76).opacity(0.35),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceTop: Color(red: 0.025, green: 0.14, blue: 0.13),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        surfaceBottom: Color(red: 0.01, green: 0.065, blue: 0.06),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        glow: Color(red: 0.38, green: 0.92, blue: 0.82),  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
        motifSymbol: "waveform",
        eyebrow: "Transcri\u{e7}\u{e3}o"
    )
}

// MARK: - Shared CTA button applying the theme gradient + inner highlight

struct StudyShellCTA: View {
    let title: String
    let theme: StudyShellTheme
    let action: () -> Void
    var systemImage: String? = nil

    private var chromePalette: VitaCTAChromePalette {
        VitaCTAChromePalette(
            foreground: theme.primaryLight.opacity(0.96),
            tint: theme.primary,
            highlight: theme.primaryLight,
            rim: theme.primaryLight,
            glow: theme.glow
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(
                            size: VitaTokens.Typography.fontSizeMd,
                            weight: .medium
                        ))
                }
                Text(title)
                    .font(VitaTypography.buttonMedium)
                    .tracking(VitaTokens.Typography.letterSpacingWide * 0.5)
            }
            .foregroundStyle(chromePalette.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VitaTokens.Spacing.lg)
            .vitaPrimaryCTAChrome(palette: chromePalette)
        }
        .buttonStyle(VitaButtonPressStyle())
    }
}
