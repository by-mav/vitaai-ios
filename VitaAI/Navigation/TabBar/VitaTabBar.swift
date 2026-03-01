import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudo"
    case trabalhos = "Trabalho"
    case agenda = "Agenda"
    case insights = "Insight"
    case profile = "Perfil"

    var icon: String {
        switch self {
        case .home: return "house"
        case .estudos: return "book"
        case .trabalhos: return "doc.text"
        case .agenda: return "calendar"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .estudos: return "book.fill"
        case .trabalhos: return "doc.text.fill"
        case .agenda: return "calendar"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.fill"
        }
    }

    static var leftItems: [TabItem] { [.home, .estudos, .trabalhos] }
    static var rightItems: [TabItem] { [.agenda, .insights, .profile] }
}

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    private let navBarHeight: CGFloat = 92
    private let notchDepth: CGFloat = 70

    var body: some View {
        ZStack {
            // Nav background with notch clip
            Canvas { context, size in
                let sx = size.width / 360
                let sy = notchDepth / 36

                var path = Path()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 130 * sx, y: 0))
                path.addQuadCurve(to: CGPoint(x: 148 * sx, y: 8 * sy), control: CGPoint(x: 142 * sx, y: 0))
                path.addQuadCurve(to: CGPoint(x: 168 * sx, y: 32 * sy), control: CGPoint(x: 158 * sx, y: 24 * sy))
                path.addQuadCurve(to: CGPoint(x: 180 * sx, y: 36 * sy), control: CGPoint(x: 174 * sx, y: 36 * sy))
                path.addQuadCurve(to: CGPoint(x: 192 * sx, y: 32 * sy), control: CGPoint(x: 186 * sx, y: 36 * sy))
                path.addQuadCurve(to: CGPoint(x: 212 * sx, y: 8 * sy), control: CGPoint(x: 202 * sx, y: 24 * sy))
                path.addQuadCurve(to: CGPoint(x: 230 * sx, y: 0), control: CGPoint(x: 218 * sx, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                // Fill background
                context.fill(path, with: .color(VitaColors.surface))

                // Top border glow
                var glowPath = Path()
                glowPath.move(to: .zero)
                glowPath.addLine(to: CGPoint(x: 130 * sx, y: 0))
                glowPath.addQuadCurve(to: CGPoint(x: 148 * sx, y: 8 * sy), control: CGPoint(x: 142 * sx, y: 0))
                glowPath.addQuadCurve(to: CGPoint(x: 168 * sx, y: 32 * sy), control: CGPoint(x: 158 * sx, y: 24 * sy))
                glowPath.addQuadCurve(to: CGPoint(x: 180 * sx, y: 36 * sy), control: CGPoint(x: 174 * sx, y: 36 * sy))
                glowPath.addQuadCurve(to: CGPoint(x: 192 * sx, y: 32 * sy), control: CGPoint(x: 186 * sx, y: 36 * sy))
                glowPath.addQuadCurve(to: CGPoint(x: 212 * sx, y: 8 * sy), control: CGPoint(x: 202 * sx, y: 24 * sy))
                glowPath.addQuadCurve(to: CGPoint(x: 230 * sx, y: 0), control: CGPoint(x: 218 * sx, y: 0))
                glowPath.addLine(to: CGPoint(x: size.width, y: 0))

                // Diffuse glow
                context.stroke(glowPath, with: .color(VitaColors.accent.opacity(0.08)), lineWidth: 12)
                // Crisp line
                context.stroke(glowPath, with: .color(VitaColors.accent.opacity(0.15)), lineWidth: 2)
            }
            .frame(height: navBarHeight)

            // Tab items
            HStack(spacing: 0) {
                // Left group
                HStack(spacing: 0) {
                    ForEach(TabItem.leftItems, id: \.self) { item in
                        tabButton(item)
                    }
                }
                .frame(maxWidth: .infinity)

                // Center notch gap
                Spacer().frame(width: 80)

                // Right group
                HStack(spacing: 0) {
                    ForEach(TabItem.rightItems, id: \.self) { item in
                        tabButton(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 15)

            // Center caduceus logo
            VStack {
                Spacer()
                Button(action: onCenterTap) {
                    VStack(spacing: 0) {
                        // Pulsing glow
                        PulsingGlow()
                            .frame(width: 32, height: 32)

                        Image(systemName: "cross.vial.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.accent)
                    }
                }
                .offset(y: -(navBarHeight - notchDepth - 8))
            }
        }
        .frame(height: navBarHeight)
    }

    private func tabButton(_ item: TabItem) -> some View {
        Button(action: { selectedTab = item }) {
            VStack(spacing: 2) {
                Image(systemName: selectedTab == item ? item.selectedIcon : item.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(selectedTab == item ? VitaColors.accent.opacity(0.65) : VitaColors.textTertiary)
                Text(item.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(selectedTab == item ? VitaColors.accent.opacity(0.5) : VitaColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct PulsingGlow: View {
    @State private var opacity: Double = 0.15

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [VitaColors.accent.opacity(opacity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 16
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    opacity = 0.35
                }
            }
    }
}
