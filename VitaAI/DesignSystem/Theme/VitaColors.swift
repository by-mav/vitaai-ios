import SwiftUI

// MARK: - VitaAI Gold Glassmorphism Design System
// Source of truth: mockup CSS at vita-design-system.css
// All values extracted from actual mockup rgba() values.

enum VitaColors {
    // Accent: Gold (primary brand color)
    static let accent        = VitaTokens.DarkColors.accent          // rgba(200,160,80)
    static let accentDark    = VitaTokens.PrimitiveColors.gold600    // rgba(140,100,50)
    static let accentLight   = VitaTokens.PrimitiveColors.gold300    // rgba(255,220,160)
    static let accentSubtle  = VitaTokens.DarkColors.bgSubtle        // gold subtle bg
    static let accentHover   = VitaTokens.DarkColors.accentHover     // rgba(255,200,120)

    // Ambient light colors (for background radial gradients)
    static let ambientPrimary   = VitaTokens.PrimitiveColors.glowA      // rgba(255,192,95)
    static let ambientSecondary = VitaTokens.PrimitiveColors.glowB      // rgba(255,200,120)
    static let ambientTertiary  = VitaTokens.PrimitiveColors.gold400    // rgba(200,160,80)

    // Glow animation colors
    static let glowA = VitaTokens.PrimitiveColors.glowA              // rgba(255,192,95)
    static let glowB = VitaTokens.PrimitiveColors.glowB              // rgba(255,200,120)
    static let glowC = VitaTokens.PrimitiveColors.glowC              // rgba(200,160,80)

    // Surfaces — warm near-black
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg             // #08060a
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard         // rgba(12,9,7)
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface  // rgba(255,240,214,0.04)

    // Glass — 3-layer system (matches mockup .g3 / .gpanel)
    static let glassBg        = Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.92) // rgba(12,9,7,0.92)
    static let glassBorder    = Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.14)   // rgba(255,200,120,0.14)
    static let glassHighlight = Color(red: 1.0, green: 0.941, blue: 0.824).opacity(0.10)   // rgba(255,240,210,0.10)
    static let glassInnerLight = VitaTokens.PrimitiveColors.gold700                         // rgba(200,155,70)

    // Text — warm white
    static let white         = VitaTokens.PrimitiveColors.white
    static let textPrimary   = VitaTokens.DarkColors.text            // rgba(255,252,248,0.96)
    static let textSecondary = VitaTokens.DarkColors.textSecondary   // rgba(255,240,215,0.40)
    static let textTertiary  = VitaTokens.DarkColors.textMuted       // rgba(255,240,215,0.25)

    // Section label
    static let sectionLabel  = Color(red: 1.0, green: 0.945, blue: 0.843).opacity(0.55) // rgba(255,241,215,0.55)

    // Subtle warm white (base for opacity variations)
    static let textWarm      = Color(red: 1.0, green: 0.941, blue: 0.843)               // rgba(255,240,215) — use with .opacity()

    // Semantic data colors
    static let dataGreen  = VitaTokens.PrimitiveColors.green500     // #22c55e
    static let dataRed    = VitaTokens.PrimitiveColors.red500       // #ef4444
    static let dataAmber  = VitaTokens.PrimitiveColors.amber500     // #f59e0b
    static let dataBlue   = VitaTokens.PrimitiveColors.blue400      // #60a5fa
    static let dataIndigo = VitaTokens.PrimitiveColors.indigo400    // #a78bfa
    static let dataTeal   = VitaTokens.PrimitiveColors.teal400      // rgba(60,180,170)

    // Semantic state colors — agents UI usam estes em vez de Color.red/.green direto.
    // Adicione tokens novos aqui quando aparecer demanda nova de state.
    static let recording  = VitaTokens.PrimitiveColors.red500       // REC indicator (Apple Notes/Notability/Goodnotes pattern)
    static let success    = VitaTokens.PrimitiveColors.green500     // ✓ acertou, salvo, conectado
    static let danger     = VitaTokens.PrimitiveColors.red500       // delete, error, destructive action
    static let warning    = VitaTokens.PrimitiveColors.amber500     // alerta não-bloqueante

    // Tool-specific accent colors
    static let toolQBank       = VitaTokens.PrimitiveColors.gold400    // gold
    static let toolSimulados   = VitaTokens.PrimitiveColors.blue400    // blue
    static let toolTranscricao = VitaTokens.PrimitiveColors.teal400    // teal
    static let toolFlashcards  = VitaTokens.PrimitiveColors.indigo400  // purple

    // Derived / convenience
    static let goldText = accentLight                                   // rgba(255,220,160)
    static let goldBarGradient = LinearGradient(
        colors: [accent, accentHover],
        startPoint: .leading,
        endPoint: .trailing
    )
}
