import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudos"
    case faculdade = "Faculdade"
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

    private let barHeight: CGFloat = 54
    private let vitaSize: CGFloat = 58
    private let gap: CGFloat = 5 // gap between button edge and arc

    // How far above bar top the button center sits
    private var buttonCenterAboveTop: CGFloat {
        vitaSize * 0.35 - barHeight / 2 + vitaSize / 2
        // = 20.3 - 27 + 29 = 22.3
    }
    private var arcRadius: CGFloat { vitaSize / 2 + gap }

    var body: some View {
        ZStack {
            // Notched glass bar
            NotchedBarShape(
                buttonCenterAboveTop: buttonCenterAboveTop,
                arcRadius: arcRadius,
                cornerRadius: 24
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.133, green: 0.090, blue: 0.071).opacity(0.75),
                        Color(red: 0.071, green: 0.047, blue: 0.043).opacity(0.82)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                NotchedBarShape(
                    buttonCenterAboveTop: buttonCenterAboveTop,
                    arcRadius: arcRadius,
                    cornerRadius: 24
                )
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.910, blue: 0.733).opacity(0.07),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.0),
                        startRadius: 0, endRadius: 120
                    )
                )
            )
            .overlay(
                NotchedBarShape(
                    buttonCenterAboveTop: buttonCenterAboveTop,
                    arcRadius: arcRadius,
                    cornerRadius: 24
                )
                .stroke(
                    Color(red: 1.0, green: 0.941, blue: 0.839).opacity(0.10),
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

            // Vita button
            Button(action: onCenterTap) {
                Image("vita-btn-idle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: vitaSize, height: vitaSize)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }
            .offset(y: -(vitaSize * 0.35))
            .accessibilityIdentifier("tab_vita_chat")
            .accessibilityLabel("Abrir Vita Chat")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func tabButton(_ item: TabItem) -> some View {
        let isSelected = selectedTab == item
        return Button(action: {
            if isSelected {
                onTabReselect?(item)
            } else {
                selectedTab = item
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.92)
                            : Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.35)
                    )

                Circle()
                    .fill(Color(red: 1.0, green: 0.824, blue: 0.549).opacity(isSelected ? 0.85 : 0))
                    .frame(width: 4, height: 4)
                    .shadow(color: Color(red: 1.0, green: 0.784, blue: 0.392).opacity(isSelected ? 0.4 : 0), radius: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.testID)
        .accessibilityLabel(item.rawValue)
        .frame(maxWidth: .infinity)
    }
}
