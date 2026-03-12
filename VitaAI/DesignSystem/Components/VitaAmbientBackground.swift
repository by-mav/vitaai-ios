import SwiftUI

// MARK: - VitaAmbientBackground
// Gold glassmorphism ambient light system.
// Background: #08060A (deep warm near-black) with rich gold radial glows.
// Matches mockup vita-app.html: bg #08060a + gold ambient pulses (opacity >0.18 so glass is visible).

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Deep warm near-black base (#08060A — darker, slightly warm)
            Color(red: 0.031, green: 0.024, blue: 0.039) // #08060A
                .ignoresSafeArea()

            Canvas { context, size in
                // Light 1: top-left dominant gold glow — must be VISIBLE so glass cards pop
                // Mockup: radial-gradient(ellipse at top left, rgba(200,160,80,0.22), transparent 65%)
                let center1 = CGPoint(x: size.width * 0.10, y: size.height * 0.08)
                let gradient1 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.22),
                    VitaColors.ambientPrimary.opacity(0.08),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center1.x - size.width * 0.75,
                            y: center1.y - size.width * 0.75,
                            width: size.width * 1.50,
                            height: size.width * 1.50
                        )),
                        with: .radialGradient(
                            gradient1,
                            center: center1,
                            startRadius: 0,
                            endRadius: size.width * 0.75
                        )
                    )
                }

                // Light 2: bottom-right warm amber-gold
                // Mockup: radial-gradient(ellipse at bottom right, rgba(220,171,120,0.16), transparent 60%)
                let center2 = CGPoint(x: size.width * 0.92, y: size.height * 0.82)
                let gradient2 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.16),
                    VitaColors.ambientSecondary.opacity(0.06),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center2.x - size.width * 0.65,
                            y: center2.y - size.width * 0.65,
                            width: size.width * 1.30,
                            height: size.width * 1.30
                        )),
                        with: .radialGradient(
                            gradient2,
                            center: center2,
                            startRadius: 0,
                            endRadius: size.width * 0.65
                        )
                    )
                }

                // Light 3: top-center dramatic top glow (header area)
                // Makes the top bar area feel premium + illuminated
                let center3 = CGPoint(x: size.width * 0.50, y: -size.height * 0.02)
                let gradient3 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.14),
                    VitaColors.ambientSecondary.opacity(0.06),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center3.x - size.width * 0.60,
                            y: center3.y - size.width * 0.30,
                            width: size.width * 1.20,
                            height: size.width * 0.80
                        )),
                        with: .radialGradient(
                            gradient3,
                            center: center3,
                            startRadius: 0,
                            endRadius: size.width * 0.60
                        )
                    )
                }

                // Light 4: mid-center subtle deep gold warmth
                let center4 = CGPoint(x: size.width * 0.50, y: size.height * 0.42)
                let gradient4 = Gradient(colors: [
                    VitaColors.ambientTertiary.opacity(0.08),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center4.x - size.width * 0.80,
                            y: center4.y - size.width * 0.80,
                            width: size.width * 1.60,
                            height: size.width * 1.60
                        )),
                        with: .radialGradient(
                            gradient4,
                            center: center4,
                            startRadius: 0,
                            endRadius: size.width * 0.80
                        )
                    )
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
