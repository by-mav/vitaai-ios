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
            // Deep warm near-black base (#08060A — deeper than pure black, slightly purple-warm)
            Color(red: 0.031, green: 0.024, blue: 0.039) // #08060A
                .ignoresSafeArea()

            Canvas { context, size in
                // ── Light 1: TOP-LEFT dominant gold glow — THIS IS THE HERO LIGHT ──
                // Must be BOLD and visible so glass cards "float" over it.
                // Mockup spec: rgba(200,160,80,0.22) but iOS Canvas needs higher to match CSS render
                let center1 = CGPoint(x: size.width * 0.08, y: size.height * 0.12)
                let gradient1 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.32),  // stronger core
                    VitaColors.ambientPrimary.opacity(0.18),  // mid spread
                    VitaColors.ambientPrimary.opacity(0.06),  // fade
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center1.x - size.width * 0.85,
                            y: center1.y - size.width * 0.85,
                            width: size.width * 1.70,
                            height: size.width * 1.70
                        )),
                        with: .radialGradient(
                            gradient1,
                            center: center1,
                            startRadius: 0,
                            endRadius: size.width * 0.85
                        )
                    )
                }

                // ── Light 2: BOTTOM-RIGHT warm amber-gold counter-light ──
                // Mockup: rgba(220,171,120,0.16). Boosted for iOS rendering.
                let center2 = CGPoint(x: size.width * 0.90, y: size.height * 0.78)
                let gradient2 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.24),
                    VitaColors.ambientSecondary.opacity(0.12),
                    VitaColors.ambientSecondary.opacity(0.04),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center2.x - size.width * 0.70,
                            y: center2.y - size.width * 0.70,
                            width: size.width * 1.40,
                            height: size.width * 1.40
                        )),
                        with: .radialGradient(
                            gradient2,
                            center: center2,
                            startRadius: 0,
                            endRadius: size.width * 0.70
                        )
                    )
                }

                // ── Light 3: TOP-CENTER header halo — makes TopBar area feel premium ──
                let center3 = CGPoint(x: size.width * 0.50, y: size.height * 0.00)
                let gradient3 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.20),
                    VitaColors.ambientSecondary.opacity(0.10),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center3.x - size.width * 0.70,
                            y: center3.y - size.width * 0.20,
                            width: size.width * 1.40,
                            height: size.width * 0.90
                        )),
                        with: .radialGradient(
                            gradient3,
                            center: center3,
                            startRadius: 0,
                            endRadius: size.width * 0.70
                        )
                    )
                }

                // ── Light 4: MID-LEFT gold wash — fills the content area ──
                // Ensures glass cards in mid-scroll position still have visible background
                let center4 = CGPoint(x: size.width * 0.20, y: size.height * 0.50)
                let gradient4 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.14),
                    VitaColors.ambientPrimary.opacity(0.05),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center4.x - size.width * 0.85,
                            y: center4.y - size.width * 0.85,
                            width: size.width * 1.70,
                            height: size.width * 1.70
                        )),
                        with: .radialGradient(
                            gradient4,
                            center: center4,
                            startRadius: 0,
                            endRadius: size.width * 0.85
                        )
                    )
                }

                // ── Light 5: BOTTOM-CENTER deep warmth — base glow for bottom scroll ──
                let center5 = CGPoint(x: size.width * 0.50, y: size.height * 0.95)
                let gradient5 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.12),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center5.x - size.width * 0.60,
                            y: center5.y - size.width * 0.60,
                            width: size.width * 1.20,
                            height: size.width * 1.20
                        )),
                        with: .radialGradient(
                            gradient5,
                            center: center5,
                            startRadius: 0,
                            endRadius: size.width * 0.60
                        )
                    )
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
