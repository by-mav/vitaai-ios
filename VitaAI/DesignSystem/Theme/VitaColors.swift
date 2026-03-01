import SwiftUI

// MARK: - VitaAI Cyan Ambient Glass Design System

enum VitaColors {
    // Accent: Cyan (ONLY accent color)
    static let accent = Color(hex: 0x22D3EE)        // cyan-400 primary
    static let accentDark = Color(hex: 0x06B6D4)     // cyan-500
    static let accentLight = Color(hex: 0x67E8F9)    // cyan-300
    static let accentSubtle = Color(hex: 0x082F38)   // deep subtle bg

    // Ambient light colors (for background radial gradients)
    static let ambientPrimary = Color(hex: 0x22D3EE)
    static let ambientSecondary = Color(hex: 0x06B6D4)
    static let ambientTertiary = Color(hex: 0x0891B2)

    // Glow animation colors
    static let glowA = Color(hex: 0x22D3EE)
    static let glowB = Color(hex: 0x00E5FF)
    static let glowC = Color(hex: 0x40C4FF)

    // Surfaces — near-black with cool tint
    static let black = Color(hex: 0x000000)
    static let surface = Color(hex: 0x040809)
    static let surfaceElevated = Color(hex: 0x0A1014)
    static let surfaceCard = Color(hex: 0x0D1318)
    static let surfaceBorder = Color(hex: 0x1A2028)

    // Glass
    static let glassBg = Color.white.opacity(0.025)
    static let glassBorder = Color.white.opacity(0.04)
    static let glassHighlight = Color.white.opacity(0.06)

    // Text
    static let white = Color.white
    static let textPrimary = Color.white.opacity(0.85)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.25)
}
