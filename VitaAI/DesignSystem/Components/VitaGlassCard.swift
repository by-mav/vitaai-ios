import SwiftUI

// MARK: - VitaGlassCard — 3-Layer Gold Glass System
// Matches mockup .g3 / .gpanel CSS exactly:
//   Layer 0: Dark warm base bg
//   Layer 1: Corner radial-gradient gold inner lights + inset shadows
//   Layer 2: Conic-gradient gold border

struct VitaGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    // Layer 0 — Base: dark warm gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.glassBg,
                                    VitaColors.surfaceElevated.opacity(0.88)
                                ],
                                startPoint: .init(x: 0.5, y: 0),
                                endPoint: .init(x: 0.45, y: 1)
                            )
                        )

                    // Layer 1 — Inner light: gold radial glows at corners
                    Canvas { context, size in
                        let rect = CGRect(origin: .zero, size: size)
                        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                        context.clip(to: path)

                        // Bottom-left glow (strongest)
                        drawRadial(context: &context, size: size,
                                   center: CGPoint(x: 0, y: size.height),
                                   radius: size.width * 0.6,
                                   color: VitaColors.glassInnerLight,
                                   alpha: 0.16)

                        // Bottom-right glow
                        drawRadial(context: &context, size: size,
                                   center: CGPoint(x: size.width, y: size.height),
                                   radius: size.width * 0.55,
                                   color: VitaColors.glassInnerLight,
                                   alpha: 0.10)

                        // Top-left glow
                        drawRadial(context: &context, size: size,
                                   center: CGPoint(x: 0, y: 0),
                                   radius: size.width * 0.5,
                                   color: VitaColors.glassInnerLight,
                                   alpha: 0.08)

                        // Top-right glow (subtlest)
                        drawRadial(context: &context, size: size,
                                   center: CGPoint(x: size.width, y: 0),
                                   radius: size.width * 0.5,
                                   color: VitaColors.glassInnerLight,
                                   alpha: 0.05)
                    }
                    .allowsHitTesting(false)

                    // Layer 1b — Top edge highlight line
                    VStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, VitaColors.glassHighlight, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // Layer 2 — Conic gold border via AngularGradient stroke
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: VitaColors.accentHover.opacity(0.34), location: 0.0),
                                .init(color: VitaColors.accentHover.opacity(0.16), location: 0.17),
                                .init(color: Color.white.opacity(0.03), location: 0.39),
                                .init(color: Color.white.opacity(0.08), location: 0.61),
                                .init(color: VitaColors.accentHover.opacity(0.12), location: 0.83),
                                .init(color: VitaColors.accentHover.opacity(0.34), location: 1.0),
                            ]),
                            center: UnitPoint(x: 0.4, y: 0.8)
                        ),
                        lineWidth: 1
                    )
            )
            // Shadows matching mockup box-shadow
            .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 8)
            .shadow(color: VitaColors.glassInnerLight.opacity(0.06), radius: 10, x: 0, y: 0)
    }

    private func drawRadial(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        alpha: Double
    ) {
        context.drawLayer { ctx in
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(alpha), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }
}

// MARK: - View modifier for inline glass styling

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.glassBg,
                                    VitaColors.surfaceElevated.opacity(0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
    }
}
