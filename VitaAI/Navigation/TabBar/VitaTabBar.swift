import SwiftUI

// MARK: - TabItem
// Matches mockup nav: home | estudos | [vita center] | faculdade | historico
enum TabItem: String, CaseIterable {
    case home       = "Home"
    case estudos    = "Estudos"
    case faculdade  = "Faculdade"
    case historico  = "Progresso"

    var icon: String {
        switch self {
        case .home:      return "house"
        case .estudos:   return "books.vertical"
        case .faculdade: return "graduationcap"
        case .historico: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:      return "house.fill"
        case .estudos:   return "books.vertical.fill"
        case .faculdade: return "graduationcap.fill"
        case .historico: return "chart.bar.fill"
        }
    }
}

// MARK: - VitaTabBar
// Matches mockup .nav-pill: 4 nav-circles + vita-center medallion
// Style: floating pill with blur, no background bar, just circles
struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    var body: some View {
        ZStack {
            // Fade gradient behind nav (matches mockup ::before — glass fade background)
            // Taller gradient so medallion floats above content naturally
            LinearGradient(
                colors: [Color.clear, Color(red: 0.031, green: 0.024, blue: 0.039).opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                // Left side
                navCircle(.home)
                navCircle(.estudos)

                // Center gap for 100px medallion
                Spacer().frame(width: 108)

                // Right side
                navCircle(.faculdade)
                navCircle(.historico)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)

            // Center Vita medallion (100px — matches mockup .vita-center)
            VStack {
                Spacer()
                Button(action: onCenterTap) {
                    VitaMedallionButton()
                }
                .buttonStyle(.plain)
                .offset(y: -18) // lift above nav row
                .padding(.bottom, 24)
            }
        }
        .frame(height: 130) // taller to fit 100px medallion floating up
    }

    // MARK: - Nav Circle (matches .nav-circle — neumorphic 48x48)
    // Mockup: inset shadow dark+light, gold glow active, subtle glass bg always visible
    @ViewBuilder
    private func navCircle(_ item: TabItem) -> some View {
        let isActive = selectedTab == item

        Button(action: { selectedTab = item }) {
            ZStack {
                // Neumorphic base: dark inset shadow (concave effect)
                Circle()
                    .fill(
                        isActive
                            ? Color(red: 0.080, green: 0.063, blue: 0.100) // slightly lighter when active
                            : Color(red: 0.055, green: 0.043, blue: 0.075)
                    )
                    .frame(width: 48, height: 48)
                    // Outer depth shadow (dark side)
                    .shadow(
                        color: Color.black.opacity(isActive ? 0.55 : 0.50),
                        radius: 6, x: 3, y: 3
                    )
                    // Outer highlight (light side — subtle)
                    .shadow(
                        color: Color.white.opacity(0.04),
                        radius: 4, x: -2, y: -2
                    )

                // Inner inset shadow ring — simulates concave depth
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.35),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 48, height: 48)

                // Gold border ring (active only)
                if isActive {
                    Circle()
                        .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                }

                // Icon
                Image(systemName: isActive ? item.selectedIcon : item.icon)
                    .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(
                        isActive
                            ? Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.92)
                            : Color.white.opacity(0.35)
                    )
            }
            // Gold glow radiate when active
            .shadow(
                color: isActive ? VitaColors.accent.opacity(0.30) : .clear,
                radius: 12, x: 0, y: 0
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vita Medallion Center Button
// Matches mockup .vita-center + .vita-snake (medalha PNG com glow dourado)
private struct VitaMedallionButton: View {
    @State private var glowing = false

    var body: some View {
        ZStack {
            // Outer ambient glow halo (pulsing)
            Circle()
                .fill(VitaColors.accent.opacity(glowing ? 0.20 : 0.10))
                .frame(width: 100, height: 100)
                .blur(radius: glowing ? 18 : 12)

            // Mid glow ring
            Circle()
                .fill(VitaColors.ambientPrimary.opacity(glowing ? 0.12 : 0.06))
                .frame(width: 84, height: 84)
                .blur(radius: 8)

            // Medallion image (if asset exists) or premium fallback
            if UIImage(named: "medallion-nav") != nil {
                Image("medallion-nav")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: VitaColors.accent.opacity(0.60), radius: 20)
                    .shadow(color: VitaColors.accent.opacity(0.25), radius: 40)
            } else {
                // Fallback: 80px neumorphic gold medallion
                ZStack {
                    // Neumorphic base
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.100, green: 0.082, blue: 0.125),
                                    Color(red: 0.059, green: 0.047, blue: 0.082)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.55), radius: 8, x: 4, y: 4)
                        .shadow(color: .white.opacity(0.04), radius: 6, x: -3, y: -3)

                    // Gold ring border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentLight.opacity(0.60),
                                    VitaColors.accent.opacity(0.30),
                                    VitaColors.accentDark.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 72, height: 72)

                    // Gold glow shadow
                    Circle()
                        .fill(.clear)
                        .frame(width: 72, height: 72)
                        .shadow(color: VitaColors.accent.opacity(0.55), radius: 18)
                        .shadow(color: VitaColors.accent.opacity(0.25), radius: 36)

                    // Medical icon — caduceus / star of life
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 220/255, blue: 160/255),
                                    VitaColors.accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: VitaColors.accent.opacity(0.8), radius: 8)
                }
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}
