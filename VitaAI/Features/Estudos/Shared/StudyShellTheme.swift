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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                    .tracking(0)
            }
            .foregroundStyle(theme.primaryLight.opacity(0.98))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                        .fill(Color(red: 0.08, green: 0.085, blue: 0.10).opacity(0.92))  // ds-allow: tema signature por-ferramenta (pre-existente; tokenizar em refactor dedicado)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(0.28),
                                    theme.primary.opacity(0.16),
                                    Color.white.opacity(0.025),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
            .overlay(alignment: .top) {
                // Top inner highlight — overhead light simulation
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .top, endPoint: .init(x: 0.5, y: 0.20)
                        )
                    )
                    .frame(height: 10)
                    .padding(.horizontal, 1)
                    .allowsHitTesting(false)
            }
            .overlay(
                // Thin gradient stroke — liquid-glass rim, low contrast
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                    .stroke(
                        LinearGradient(
                            colors: [
                                theme.primaryLight.opacity(0.45),
                                theme.primary.opacity(0.08),
                                theme.primaryLight.opacity(0.22),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: theme.primary.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LensSwitcher (3 lentes Tradicional / PBL / CNRM-Enare)

/// Segmented switcher entre as 3 lentes de organização do conteúdo.
///
/// Aparece logo abaixo do hero nas três páginas Estudos (Questões, Simulados,
/// Flashcards) e troca a forma como disciplinas/sistemas/áreas aparecem nos
/// chips e na lista detalhada.
///
/// SOT do enum: `Generated/Models/ContentOrganizationMode.swift` + helpers em
/// `Core/Models/Journey/JourneyType+Helpers.swift`. Decisão canônica:
/// `agent-brain/decisions/2026-04-27_jornada-3lentes-FINAL.md`.
struct LensSwitcher: View {
    @Binding var selection: ContentOrganizationMode
    var theme: StudyShellTheme
    var onChange: ((ContentOrganizationMode) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ContentOrganizationMode.allCases, id: \.self) { mode in
                lensPill(mode: mode)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                .stroke(theme.primaryMuted.opacity(0.18), lineWidth: 0.75)
        )
    }

    @ViewBuilder
    private func lensPill(mode: ContentOrganizationMode) -> some View {
        let isSelected = selection == mode
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = mode
            }
            onChange?(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                Text(mode.displayName)
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                    .tracking(-0.1)
            }
            .foregroundStyle(
                isSelected ? theme.primaryLight.opacity(0.98) : VitaColors.textSecondary
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                            .fill(theme.primary.opacity(0.22))
                        RoundedRectangle(cornerRadius: 9, style: .continuous)  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
                            .stroke(theme.primaryLight.opacity(0.32), lineWidth: 0.75)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))  // ds-allow: componente compartilhado pre-existente (tokenizar em refactor dedicado)
        }
        .buttonStyle(.plain)
    }
}
