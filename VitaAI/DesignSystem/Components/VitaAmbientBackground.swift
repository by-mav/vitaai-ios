import SwiftUI

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Layer 0: solid dark base
            VitaColors.surface
                .ignoresSafeArea()

            // Layer 1: background image with dark gradient overlay
            Image("fundo_dashboard")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.32) // 132% scale like mockup
                .overlay(
                    LinearGradient(
                        colors: [
                            Color(red: 6/255, green: 4/255, blue: 4/255).opacity(0.46),
                            Color(red: 6/255, green: 4/255, blue: 4/255).opacity(0.68)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()

            // Layer 2: center warm glow + edge vignettes (::before)
            Canvas { context, size in
                // Center warm glow
                let centerGlow = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: centerGlow.x - size.width * 0.38,
                            y: centerGlow.y - size.height * 0.38,
                            width: size.width * 0.76,
                            height: size.height * 0.76
                        )),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1, green: 214/255, blue: 152/255).opacity(0.05),
                                .clear
                            ]),
                            center: centerGlow,
                            startRadius: 0,
                            endRadius: size.width * 0.38
                        )
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Layer 3: gold accent glows at corners (::after)
            Canvas { context, size in
                // Top-left gold glow
                let tl = CGPoint(x: size.width * 0.08, y: size.height * 0.14)
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: tl.x - size.width * 0.22,
                            y: tl.y - size.height * 0.22,
                            width: size.width * 0.44,
                            height: size.height * 0.44
                        )),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1, green: 192/255, blue: 95/255).opacity(0.12),
                                .clear
                            ]),
                            center: tl,
                            startRadius: 0,
                            endRadius: size.width * 0.22
                        )
                    )
                }

                // Top-right gold glow
                let tr = CGPoint(x: size.width * 0.92, y: size.height * 0.14)
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: tr.x - size.width * 0.22,
                            y: tr.y - size.height * 0.22,
                            width: size.width * 0.44,
                            height: size.height * 0.44
                        )),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1, green: 192/255, blue: 95/255).opacity(0.12),
                                .clear
                            ]),
                            center: tr,
                            startRadius: 0,
                            endRadius: size.width * 0.22
                        )
                    )
                }

                // Bottom-center gold glow
                let bc = CGPoint(x: size.width * 0.5, y: size.height)
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: bc.x - size.width * 0.28,
                            y: bc.y - size.height * 0.28,
                            width: size.width * 0.56,
                            height: size.height * 0.56
                        )),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1, green: 192/255, blue: 95/255).opacity(0.08),
                                .clear
                            ]),
                            center: bc,
                            startRadius: 0,
                            endRadius: size.width * 0.28
                        )
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
