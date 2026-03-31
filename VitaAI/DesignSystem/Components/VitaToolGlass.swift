import SwiftUI

// MARK: - Tool-specific glass cards
// Each tool has its own accent color from the mockup:
//   QBank = gold (default VitaGlassCard)
//   Simulado = teal (.g3c: rgba(80,200,220))
//   Flashcards = purple/indigo
//   Transcrição = teal (same as simulado)

enum ToolAccent {
    case gold      // QBank, default
    case teal      // Simulado, Transcrição
    case purple    // Flashcards

    // Mockup teal: --al: 160,240,220  --ab: 60,180,160  --ad: 30,120,100
    // CSS uses rgba(80,200,180) for borders, rgba(60,180,160) for glows

    var borderStrong: Color {
        switch self {
        case .gold:   return Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.32)
        case .teal:   return Color(red: 0.314, green: 0.784, blue: 0.706).opacity(0.36)
        case .purple: return Color(red: 148/255, green: 75/255, blue: 220/255).opacity(0.32) // mockup purple
        }
    }

    var borderMedium: Color {
        switch self {
        case .gold:   return Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.16)
        case .teal:   return Color(red: 0.314, green: 0.784, blue: 0.706).opacity(0.16)
        case .purple: return Color(red: 148/255, green: 75/255, blue: 220/255).opacity(0.16)
        }
    }

    var innerLight: Color {
        switch self {
        case .gold:   return Color(red: 0.784, green: 0.608, blue: 0.275)
        case .teal:   return Color(red: 0.235, green: 0.706, blue: 0.627) // rgba(60,180,160)
        case .purple: return Color(red: 100/255, green: 40/255, blue: 180/255)  // --ad from mockup
        }
    }

    var glowShadow: Color {
        switch self {
        case .gold:   return Color(red: 0.706, green: 0.549, blue: 0.235)
        case .teal:   return Color(red: 0.235, green: 0.706, blue: 0.627) // rgba(60,180,160)
        case .purple: return Color(red: 148/255, green: 75/255, blue: 220/255)  // mockup purple glow
        }
    }

    var baseBg: (Color, Color) {
        switch self {
        case .gold:   return (Color(red: 0.047, green: 0.035, blue: 0.027), Color(red: 0.055, green: 0.043, blue: 0.031))
        case .teal:   return (Color(red: 0.031, green: 0.047, blue: 0.043), Color(red: 0.039, green: 0.055, blue: 0.047)) // greenish-dark
        case .purple: return (Color(red: 16/255, green: 8/255, blue: 24/255), Color(red: 10/255, green: 6/255, blue: 14/255))
        }
    }

    var accent: Color {
        switch self {
        case .gold:   return VitaColors.accent
        case .teal:   return Color(red: 0.314, green: 0.784, blue: 0.706) // rgba(80,200,180)
        case .purple: return Color(red: 168/255, green: 85/255, blue: 247/255)  // --ab
        }
    }

    var accentLight: Color {
        switch self {
        case .gold:   return VitaColors.accentLight
        case .teal:   return Color(red: 0.627, green: 0.941, blue: 0.863) // rgba(160,240,220)
        case .purple: return Color(red: 200/255, green: 160/255, blue: 1.0)     // --al
        }
    }
}

// MARK: - Tool-themed glass card

struct VitaToolGlassCard<Content: View>: View {
    let accent: ToolAccent
    let cornerRadius: CGFloat
    let content: Content

    init(accent: ToolAccent = .gold, cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let bg = accent.baseBg
        content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [bg.0.opacity(0.92), bg.1.opacity(0.88)],
                            startPoint: .init(x: 0.5, y: 0),
                            endPoint: .init(x: 0.45, y: 1)
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: accent.borderStrong, location: 0.0),
                                .init(color: accent.borderMedium, location: 0.17),
                                .init(color: Color.white.opacity(0.03), location: 0.39),
                                .init(color: Color.white.opacity(0.08), location: 0.61),
                                .init(color: accent.borderMedium, location: 0.83),
                                .init(color: accent.borderStrong, location: 1.0),
                            ]),
                            center: UnitPoint(x: 0.4, y: 0.8)
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 8)
            .shadow(color: accent.glowShadow.opacity(0.06), radius: 10, x: 0, y: 0)
    }
}

// MARK: - Tool-themed screen background

struct VitaToolScreenBg: View {
    let accent: ToolAccent

    var body: some View {
        ZStack {
            VitaColors.surface
            Canvas { context, size in
                let color = accent.innerLight
                for (cx, cy, r, a) in [(0.08, 0.12, 0.45, 0.08), (0.92, 0.12, 0.45, 0.08), (0.5, 0.95, 0.5, 0.05)] as [(Double, Double, Double, Double)] {
                    let center = CGPoint(x: size.width * cx, y: size.height * cy)
                    let radius = size.width * r
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(Gradient(colors: [color.opacity(a), .clear]), center: center, startRadius: 0, endRadius: radius)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}
