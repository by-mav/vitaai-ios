import SwiftUI

// MARK: - VitaAI Cyan Ambient Glass Design System
// DO NOT hardcode Color(hex:) here — all values must come from VitaTokens.
// Source of truth: packages/design-tokens/tokens.json → node generate.mjs

enum VitaColors {
    // Accent: Cyan (ONLY accent color)
    static let accent        = VitaTokens.DarkColors.accent          // cyan-400 primary
    static let accentDark    = VitaTokens.DarkColors.accentHover     // cyan-500
    static let accentLight   = VitaTokens.PrimitiveColors.cyan300    // cyan-300
    static let accentSubtle  = VitaTokens.DarkColors.bgSubtle        // deep accent-tinted bg

    // Ambient light colors (for background radial gradients)
    static let ambientPrimary   = VitaTokens.DarkColors.accent          // cyan-400
    static let ambientSecondary = VitaTokens.DarkColors.accentHover     // cyan-500
    static let ambientTertiary  = VitaTokens.PrimitiveColors.cyan600    // cyan-600

    // Glow animation colors
    static let glowA = VitaTokens.DarkColors.accent                  // cyan-400
    static let glowB = VitaTokens.PrimitiveColors.glowB              // #00e5ff
    static let glowC = VitaTokens.PrimitiveColors.glowC              // #40c4ff

    // Surfaces — near-black with cool tint
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface  // #1A2028

    // Glass (fine-tuned opacities — no exact token, intentional)
    static let glassBg        = Color.white.opacity(0.025)
    static let glassBorder    = Color.white.opacity(0.04)
    static let glassHighlight = Color.white.opacity(0.06)

    // Text
    static let white         = VitaTokens.PrimitiveColors.white
    static let textPrimary   = VitaTokens.DarkColors.text
    static let textSecondary = VitaTokens.DarkColors.textSecondary
    static let textTertiary  = VitaTokens.DarkColors.textMuted

    // Semantic data colors
    static let dataGreen  = VitaTokens.PrimitiveColors.green500     // #22c55e
    static let dataRed    = VitaTokens.PrimitiveColors.red500       // #ef4444
    static let dataAmber  = VitaTokens.PrimitiveColors.amber500     // #f59e0b
    static let dataBlue   = VitaTokens.PrimitiveColors.blue400      // #60a5fa
    static let dataIndigo = VitaTokens.PrimitiveColors.indigo400    // #a78bfa (card back accent)

    // MARK: - Teal Theme (Simulados + Transcricao)
    static let tealAccent       = Color(red: 80/255, green: 200/255, blue: 180/255)
    static let tealAccentLight  = Color(red: 120/255, green: 220/255, blue: 200/255)
    static let tealAccentBright = Color(red: 160/255, green: 240/255, blue: 220/255)
    static let tealGlow         = Color(red: 60/255, green: 180/255, blue: 160/255)
    static let tealCardStart    = Color(red: 31/255, green: 47/255, blue: 43/255)
    static let tealCardEnd      = Color(red: 39/255, green: 55/255, blue: 47/255)
    static let tealBorderStrong = Color(red: 80/255, green: 200/255, blue: 180/255).opacity(0.36)
    static let tealBorderMedium = Color(red: 80/255, green: 200/255, blue: 180/255).opacity(0.16)

    // MARK: - Gold Theme (PDFs/Documentos, Faculdade, etc.)
    static let goldAccent       = Color(red: 200/255, green: 160/255, blue: 80/255)
    static let goldAccentLight  = Color(red: 255/255, green: 200/255, blue: 120/255)
    static let goldAccentBright = Color(red: 255/255, green: 240/255, blue: 210/255)
    static let goldGlow         = Color(red: 180/255, green: 140/255, blue: 60/255)
    static let goldCardStart    = Color(red: 12/255, green: 9/255, blue: 7/255)
    static let goldCardEnd      = Color(red: 14/255, green: 11/255, blue: 8/255)
    static let goldBorderStrong = Color(red: 255/255, green: 200/255, blue: 120/255).opacity(0.32)
    static let goldBorderMedium = Color(red: 255/255, green: 200/255, blue: 120/255).opacity(0.16)

    // MARK: - Badge Colors (shared across themed pages)
    static let badgeSuccessBg     = Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.15)
    static let badgeSuccessText   = Color(red: 74/255, green: 222/255, blue: 128/255).opacity(0.85)
    static let badgeSuccessBorder = Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.20)
    static let badgeWarningBg     = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.15)
    static let badgeWarningText   = Color(red: 251/255, green: 191/255, blue: 36/255).opacity(0.85)
    static let badgeWarningBorder = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.20)
    static let badgeRecordingBg   = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.15)
    static let badgeRecordingText = Color(red: 248/255, green: 113/255, blue: 113/255).opacity(0.85)

    // MARK: - QBank Blue Theme
    static let qbankAccent       = Color(red: 96/255, green: 165/255, blue: 250/255)
    static let qbankAccentLight  = Color(red: 147/255, green: 197/255, blue: 253/255)
    static let qbankAccentBright = Color(red: 191/255, green: 219/255, blue: 254/255)
    static let qbankGlow         = Color(red: 96/255, green: 165/255, blue: 250/255)
    static let qbankCardStart    = Color(red: 7/255, green: 12/255, blue: 20/255)
    static let qbankCardEnd      = Color(red: 8/255, green: 14/255, blue: 24/255)
    static let qbankBorderStrong = Color(red: 140/255, green: 190/255, blue: 255/255).opacity(0.14)
    static let qbankBorderMedium = Color(red: 140/255, green: 190/255, blue: 255/255).opacity(0.08)

    // MARK: - Flashcard Purple Theme
    static let flashcardAccent       = Color(red: 148/255, green: 75/255, blue: 220/255)
    static let flashcardAccentLight  = Color(red: 180/255, green: 120/255, blue: 255/255)
    static let flashcardAccentBright = Color(red: 210/255, green: 170/255, blue: 255/255)
    static let flashcardGlow         = Color(red: 148/255, green: 75/255, blue: 220/255)
    static let flashcardCardStart    = Color(red: 16/255, green: 8/255, blue: 24/255)
    static let flashcardCardEnd      = Color(red: 8/255, green: 4/255, blue: 14/255)
    static let flashcardBorderStrong = Color(red: 180/255, green: 120/255, blue: 240/255).opacity(0.14)
    static let flashcardBorderMedium = Color(red: 180/255, green: 120/255, blue: 240/255).opacity(0.08)

    // MARK: - FSRS Rating Button Colors
    static let ratingAgain   = Color(red: 255/255, green: 120/255, blue: 80/255)
    static let ratingHard    = Color(red: 245/255, green: 180/255, blue: 60/255)
    static let ratingGood    = Color(red: 180/255, green: 120/255, blue: 255/255)
    static let ratingEasy    = Color(red: 130/255, green: 200/255, blue: 140/255)
    static let ratingAgainBg = Color(red: 30/255, green: 12/255, blue: 12/255)
    static let ratingHardBg  = Color(red: 24/255, green: 16/255, blue: 8/255)
    static let ratingGoodBg  = Color(red: 16/255, green: 10/255, blue: 20/255)
    static let ratingEasyBg  = Color(red: 8/255, green: 20/255, blue: 14/255)
}
