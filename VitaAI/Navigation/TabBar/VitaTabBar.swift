import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudos"
    case faculdade = "Jornada"
    case progresso = "Progresso"

    var icon: String {
        switch self {
        case .home: return "house"
        case .estudos: return "book"
        case .faculdade: return "graduationcap"
        case .progresso: return "chart.bar"
        }
    }

    var testID: String {
        switch self {
        case .home: return "tab_home"
        case .estudos: return "tab_estudos"
        case .faculdade: return "tab_faculdade"
        case .progresso: return "tab_progresso"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .estudos: return "book.fill"
        case .faculdade: return "graduationcap.fill"
        case .progresso: return "chart.bar.fill"
        }
    }
}

// MARK: - Notched Shape
// The arc center matches the Vita button center (above the bar top edge).
// The arc follows the button curvature with a small gap.

struct NotchedBarShape: Shape {
    /// Y offset of button center above bar top edge (positive = above)
    let buttonCenterAboveTop: CGFloat
    /// Arc radius (button radius + gap)
    let arcRadius: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let top = rect.minY
        // Button center is above the bar's top edge
        let centerY = top - buttonCenterAboveTop

        // Find where the arc intersects the bar's top edge (y = top)
        // Circle: (x - midX)^2 + (y - centerY)^2 = arcRadius^2
        // At y = top: (x - midX)^2 = arcRadius^2 - (top - centerY)^2
        //                           = arcRadius^2 - buttonCenterAboveTop^2
        let dx = sqrt(max(arcRadius * arcRadius - buttonCenterAboveTop * buttonCenterAboveTop, 0))
        let leftEdgeX = midX - dx
        let rightEdgeX = midX + dx

        // Angle at these intersection points
        // atan2(top - centerY, leftEdgeX - midX) = atan2(buttonCenterAboveTop, -dx)
        let startAngle = Angle(radians: atan2(Double(top - centerY), Double(leftEdgeX - midX)))
        let endAngle = Angle(radians: atan2(Double(top - centerY), Double(rightEdgeX - midX)))

        // Ramp for smooth transition from flat edge into arc
        let ramp: CGFloat = 12

        var path = Path()

        // Top-left corner
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: top))

        // Flat top edge → ramp start
        path.addLine(to: CGPoint(x: leftEdgeX - ramp, y: top))

        // Smooth curve into the arc (small quad ramp)
        path.addQuadCurve(
            to: CGPoint(x: leftEdgeX, y: top),
            control: CGPoint(x: leftEdgeX - ramp * 0.2, y: top)
        )

        // Circular arc — concave notch (screen-counterclockwise = clockwise:true in CG)
        path.addArc(
            center: CGPoint(x: midX, y: centerY),
            radius: arcRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        // Smooth curve out of the arc
        path.addQuadCurve(
            to: CGPoint(x: rightEdgeX + ramp, y: top),
            control: CGPoint(x: rightEdgeX + ramp * 0.2, y: top)
        )

        // Flat top edge right
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: top))

        // Corners
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: top + cornerRadius),
                     radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                     radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                     radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: top + cornerRadius))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: top + cornerRadius),
                     radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        path.closeSubpath()
        return path
    }
}

// MARK: - Gold Glassmorphism Tab Bar

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void
    var onTabReselect: ((TabItem) -> Void)? = nil

    // Rafael (2026-04-24): mascote gold acorda quando tu toca. Idle = olho
    // fechado (sleeping). Tap → olho aberto (awake) por 1s → volta a dormir.
    @State private var vitaAwake: Bool = false

    // Liquid-glass selector bubble — anima entre tabs com physics spring
    // (Rafael 2026-04-25). matchedGeometryEffect garante interpolação suave
    // de posição+tamanho entre o tab antigo e o novo selecionado.
    @Namespace private var selectorNS

    private let barHeight: CGFloat = 54
    private let vitaSize: CGFloat = 58
    private let gap: CGFloat = 5 // gap between button edge and arc

    // How far above bar top the button center sits
    private var buttonCenterAboveTop: CGFloat {
        vitaSize * 0.35 - barHeight / 2 + vitaSize / 2
        // = 20.3 - 27 + 29 = 22.3
    }
    private var arcRadius: CGFloat { vitaSize / 2 + gap }

    private var barShape: NotchedBarShape {
        NotchedBarShape(
            buttonCenterAboveTop: buttonCenterAboveTop,
            arcRadius: arcRadius,
            cornerRadius: 24
        )
    }

    var body: some View {
        ZStack {
            // Liquid Glass + cor marrom BYMAV. Stack:
            //   1. .glassEffect() refração nativa (iOS 26+) — distorce o
            //      conteúdo do app passando por baixo
            //   2. Gradient marrom translúcido (~55-62% opacity, não 75/82
            //      como antes) — preserva identidade visual mas deixa o
            //      vidro respirar e mostrar refração
            //   3. Radial gold highlight + border + shadow (identidade)
            // Fallback iOS 17-25: ultraThinMaterial + gradient marrom.
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear.glassEffect(.regular, in: barShape)
                } else {
                    barShape.fill(.ultraThinMaterial)
                }
            }
            .overlay(
                barShape.fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.133, green: 0.090, blue: 0.071).opacity(0.55),
                            Color(red: 0.071, green: 0.047, blue: 0.043).opacity(0.62)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(
                barShape.fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.910, blue: 0.733).opacity(0.10),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.0),
                        startRadius: 0, endRadius: 120
                    )
                )
            )
            .overlay(
                barShape.stroke(
                    Color(red: 1.0, green: 0.941, blue: 0.839).opacity(0.14),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .frame(height: barHeight)

            // Tab icons
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.estudos)

                Color.clear.frame(width: arcRadius * 2 + 16)

                tabButton(.faculdade)
                tabButton(.progresso)
            }
            .padding(.horizontal, 16)
            .frame(height: barHeight)

            // Vita button — gold mascot, olho fechado (sleeping) por padrão.
            // Tap abre o olho (awake) e dispara onCenterTap; fecha de novo em
            // 1.2s pra reforçar o feedback visual.
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { vitaAwake = true }
                onCenterTap()
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.35)) { vitaAwake = false }
                    }
                }
            }) {
                Image(vitaAwake ? "vita-btn-active" : "vita-btn-idle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: vitaSize, height: vitaSize)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    .scaleEffect(vitaAwake ? 1.04 : 1.0)
            }
            .offset(y: -(vitaSize * 0.35))
            .accessibilityIdentifier("tab_vita_chat")
            .accessibilityLabel("Abrir Vita Chat")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4) // Rafael 2026-04-25: bar 16px mais perto da borda
    }

    private func tabButton(_ item: TabItem) -> some View {
        let isSelected = selectedTab == item
        return Button(action: {
            if isSelected {
                onTabReselect?(item)
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                    selectedTab = item
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }) {
            ZStack {
                // Liquid-glass bubble — só renderiza no tab selecionado, mas o
                // matchedGeometryEffect anima a transição entre tabs como
                // se a bolha pulasse de um pro outro com physics spring.
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.824, blue: 0.549).opacity(0.18),
                                            Color(red: 1.0, green: 0.690, blue: 0.353).opacity(0.10)
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.30),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color(red: 1.0, green: 0.784, blue: 0.392).opacity(0.18), radius: 8, y: 2)
                        .matchedGeometryEffect(id: "tab_selector_bubble", in: selectorNS)
                }

                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.95)
                            : Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.40)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
            }
            .frame(height: 38)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.testID)
        .accessibilityLabel(item.rawValue)
        .frame(maxWidth: .infinity)
    }
}
