// VitaAI Gold Design Tokens — Source of truth: mockup CSS
// Brand: vita-gold | Regenerate from mockup vita-design-system.css

import SwiftUI

// MARK: - Vita Design Tokens

enum VitaTokens {

    // MARK: Dark Colors (Gold Glassmorphism)
    enum DarkColors {
        // Backgrounds — warm dark
        static let bg           = Color(red: 0.031, green: 0.024, blue: 0.039) // #08060a
        static let bgCard       = Color(red: 0.047, green: 0.035, blue: 0.027) // rgba(12,9,7) glass base
        static let bgElevated   = Color(red: 0.055, green: 0.043, blue: 0.031) // rgba(14,11,8)
        static let bgHover      = Color(red: 0.071, green: 0.055, blue: 0.039)
        static let bgActive     = Color(red: 0.094, green: 0.075, blue: 0.055)
        static let bgSubtle     = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.08) // gold subtle
        static let borderSurface = Color(red: 1.0, green: 0.941, blue: 0.839).opacity(0.04) // rgba(255,240,214,0.04)

        // Text — warm whites
        static let text          = Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.96)  // rgba(255,252,248,0.96)
        static let textSecondary = Color(red: 1.0, green: 0.941, blue: 0.843).opacity(0.40)  // rgba(255,240,215,0.40)
        static let textMuted     = Color(red: 1.0, green: 0.941, blue: 0.843).opacity(0.25)  // rgba(255,240,215,0.25)

        // Data colors
        static let dataBlue  = Color(red: 0.376, green: 0.647, blue: 0.980)
        static let dataGreen = Color(red: 0.290, green: 0.871, blue: 0.502)
        static let dataAmber = Color(red: 0.984, green: 0.749, blue: 0.141)
        static let dataRed   = Color(red: 0.973, green: 0.443, blue: 0.443)

        // Accent — gold
        static let accent       = Color(red: 0.784, green: 0.627, blue: 0.314) // rgba(200,160,80)
        static let accentHover  = Color(red: 1.0,   green: 0.784, blue: 0.471) // rgba(255,200,120)
        static let accentSubtle = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.08)

        // Borders — gold tinted
        static let border       = Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.08) // rgba(255,200,120,0.08)
        static let borderHover  = Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.14)
        static let borderActive = Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.20)
    }

    // MARK: Light Colors (kept for potential future use)
    enum LightColors {
        static let bg = Color(red: 0.980, green: 0.975, blue: 0.965)
        static let bgCard = Color(red: 1.000, green: 0.996, blue: 0.988)
        static let bgElevated = Color(red: 0.961, green: 0.953, blue: 0.941)
        static let bgHover = Color(red: 0.941, green: 0.933, blue: 0.918)
        static let bgActive = Color(red: 0.910, green: 0.898, blue: 0.878)
        static let border = Color(red: 0.898, green: 0.878, blue: 0.843)
        static let borderHover = Color(red: 0.820, green: 0.796, blue: 0.753)
        static let borderActive = Color(red: 0.612, green: 0.588, blue: 0.545)
        static let text = Color(red: 0.122, green: 0.110, blue: 0.094)
        static let textSecondary = Color(red: 0.420, green: 0.400, blue: 0.365)
        static let textMuted = Color(red: 0.612, green: 0.588, blue: 0.545)
        static let dataBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
        static let dataGreen = Color(red: 0.133, green: 0.773, blue: 0.369)
        static let dataAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
        static let dataRed = Color(red: 0.937, green: 0.267, blue: 0.267)
        static let accent = Color(red: 0.706, green: 0.549, blue: 0.235)
        static let accentHover = Color(red: 0.627, green: 0.471, blue: 0.188)
        static let accentSubtle = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.06)
    }

    // MARK: Primitive Colors
    enum PrimitiveColors {
        // Gold palette (replaces cyan)
        static let gold300   = Color(red: 1.0,   green: 0.863, blue: 0.627) // rgba(255,220,160)
        static let gold400   = Color(red: 0.784, green: 0.627, blue: 0.314) // rgba(200,160,80)
        static let gold500   = Color(red: 1.0,   green: 0.784, blue: 0.471) // rgba(255,200,120)
        static let gold600   = Color(red: 0.549, green: 0.392, blue: 0.196) // rgba(140,100,50)
        static let gold700   = Color(red: 0.784, green: 0.608, blue: 0.275) // rgba(200,155,70) inner light

        // Keep cyan for legacy/data use
        static let cyan300 = Color(red: 0.404, green: 0.910, blue: 0.976)
        static let cyan400 = Color(red: 0.133, green: 0.827, blue: 0.933)
        static let cyan500 = Color(red: 0.024, green: 0.714, blue: 0.831)
        static let cyan600 = Color(red: 0.031, green: 0.569, blue: 0.698)

        static let orange400 = Color(red: 0.984, green: 0.573, blue: 0.235)
        static let orange500 = Color(red: 0.976, green: 0.451, blue: 0.086)
        static let orange600 = Color(red: 0.918, green: 0.345, blue: 0.047)
        static let orange700 = Color(red: 0.761, green: 0.255, blue: 0.047)
        static let blue400  = Color(red: 0.376, green: 0.647, blue: 0.980)
        static let blue500  = Color(red: 0.231, green: 0.510, blue: 0.965)
        static let green400 = Color(red: 0.290, green: 0.871, blue: 0.502)
        static let green500 = Color(red: 0.133, green: 0.773, blue: 0.369)
        static let amber400 = Color(red: 0.984, green: 0.749, blue: 0.141)
        static let amber500 = Color(red: 0.961, green: 0.620, blue: 0.043)
        static let red400   = Color(red: 0.973, green: 0.443, blue: 0.443)
        static let red500   = Color(red: 0.937, green: 0.267, blue: 0.267)
        static let indigo400 = Color(red: 0.655, green: 0.545, blue: 0.980)
        static let teal400   = Color(red: 0.235, green: 0.706, blue: 0.667) // rgba(60,180,170) transcricao

        // Glow — gold
        static let glowA = Color(red: 1.0, green: 0.753, blue: 0.373)   // rgba(255,192,95)
        static let glowB = Color(red: 1.0, green: 0.784, blue: 0.471)   // rgba(255,200,120)
        static let glowC = Color(red: 0.784, green: 0.627, blue: 0.314) // rgba(200,160,80)

        static let white = Color(red: 1.000, green: 1.000, blue: 1.000)
        static let black = Color(red: 0.000, green: 0.000, blue: 0.000)
    }

    // MARK: Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let _2xl: CGFloat = 24
        static let _3xl: CGFloat = 32
        static let _4xl: CGFloat = 48
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
    }

    // MARK: Elevation
    enum Elevation {
        static let none: CGFloat = 0
        static let xs: CGFloat = 1
        static let sm: CGFloat = 2
        static let md: CGFloat = 4
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let _2xl: CGFloat = 24
    }

    // MARK: Typography
    enum Typography {
        static let fontSizeXs: CGFloat = 10
        static let fontSizeSm: CGFloat = 12
        static let fontSizeBase: CGFloat = 13
        static let fontSizeMd: CGFloat = 14
        static let fontSizeLg: CGFloat = 16
        static let fontSizeXl: CGFloat = 20
        static let fontSize_2xl: CGFloat = 24
        static let fontSize_3xl: CGFloat = 30

        static let fontWeightNormal: CGFloat = 400
        static let fontWeightMedium: CGFloat = 500
        static let fontWeightSemibold: CGFloat = 600
        static let fontWeightBold: CGFloat = 700

        static let letterSpacingTight: CGFloat = -0.4
        static let letterSpacingNormal: CGFloat = 0
        static let letterSpacingWide: CGFloat = 0.5

        static let fontFamilySans = "Space Grotesk"
        static let fontFamilyMono = "JetBrains Mono"
        static let fontFamilyIosBody = "SF Pro Text"
        static let fontFamilyIosDisplay = "SF Pro Display"
    }

    // MARK: Animation
    enum Animation {
        static let durationFast: Double = 0.15
        static let durationNormal: Double = 0.30
        static let durationSlow: Double = 0.50
        static let easeOut = "cubic-bezier(0.33, 1, 0.68, 1)"
    }

    // MARK: Components
    enum Components {
        enum RatingButton {
            static let minHeight: CGFloat = 56
            static let radius: CGFloat = 14
            static let fontSize: CGFloat = 12
            static let iconSize: CGFloat = 16
            static let bgAlpha: Double = 0.08
            static let borderAlpha: Double = 0.18
        }
        enum GlassCard {
            static let radius: CGFloat = 16
            static let bgAlpha: Double = 0.92 // rgba(12,9,7,0.92) — opaque dark
            static let borderAlpha: Double = 0.34 // conic peak
            static let innerLightAlpha: Double = 0.16 // corner radials
        }
        enum ChatBubble {
            static let radius: CGFloat = 16
            static let maxWidth = "85%"
        }
        enum Flashcard {
            static let flipDuration: Double = 0.50
            static let perspective: CGFloat = 1200
            static let frontBorderAlpha: Double = 0.12
            static let backBorderAlpha: Double = 0.12
            static let blur: CGFloat = 16
        }
        enum Chip {
            static let paddingV: CGFloat = 8
            static let paddingH: CGFloat = 14
            static let radius: CGFloat = 9999
            static let fontSize: CGFloat = 11
            static let fontWeight: CGFloat = 500
        }
        enum DeckPill {
            static let paddingV: CGFloat = 4
            static let paddingH: CGFloat = 12
            static let radius: CGFloat = 9999
            static let fontSize: CGFloat = 10
            static let fontWeight: CGFloat = 600
            static let letterSpacing: CGFloat = 0.8
        }
    }
}
