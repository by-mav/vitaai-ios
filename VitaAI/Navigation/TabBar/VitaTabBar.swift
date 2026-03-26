import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudos"
    case faculdade = "Faculdade"
    case progresso = "Progresso"
}

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    var body: some View {
        // Mockup: .bottom-nav-shell → position:absolute; bottom:0; padding:0 28px 22px
        ZStack {
            // Pill-shaped glassmorphism rail
            bottomNavRail

            // Vita center button — absolute positioned
            Button(action: onCenterTap) {
                Image("vita_btn")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .brightness(0.02)
                    .saturation(0.96)
                    .shadow(color: Color(red: 248/255, green: 169/255, blue: 55/255).opacity(0.22), radius: 6, x: 0, y: 0)
                    .shadow(color: Color(red: 248/255, green: 169/255, blue: 55/255).opacity(0.08), radius: 18, x: 0, y: 0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
    }

    private var bottomNavRail: some View {
        HStack(spacing: 4) {
            // Home
            navCircle(tab: .home, icon: "house", iconWidth: 25, iconHeight: 25)

            // Estudos
            navCircle(tab: .estudos, icon: "book", iconWidth: 25, iconHeight: 25)

            // Vita spacer (fixed size, non-greedy)
            Color.clear
                .frame(width: 52, height: 42)

            // Faculdade
            navCircle(tab: .faculdade, icon: "graduationcap", iconWidth: 25, iconHeight: 25)

            // Progresso
            navCircle(tab: .progresso, icon: "chart.bar", iconWidth: 25, iconHeight: 25)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            ZStack {
                // Multi-layer background matching mockup .bottom-nav-rail
                RoundedRectangle(cornerRadius: 999)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 34/255, green: 23/255, blue: 18/255).opacity(0.72),
                                Color(red: 18/255, green: 12/255, blue: 11/255).opacity(0.78)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Radial glow at top
                RoundedRectangle(cornerRadius: 999)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 255/255, green: 232/255, blue: 187/255).opacity(0.08),
                                .clear
                            ],
                            center: .top,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 999))
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color(red: 255/255, green: 240/255, blue: 214/255).opacity(0.08), lineWidth: 1)
        )
        // Inner top highlight
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color(red: 255/255, green: 245/255, blue: 226/255).opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .offset(y: 0.5)
        }
        .shadow(color: .black.opacity(0.42), radius: 30, x: 0, y: 24)
    }

    private func navCircle(tab: TabItem, icon: String, iconWidth: CGFloat, iconHeight: CGFloat) -> some View {
        Button(action: { selectedTab = tab }) {
            let isActive = selectedTab == tab
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: iconWidth, height: iconHeight)
                .foregroundColor(
                    isActive
                        ? Color(red: 255/255, green: 230/255, blue: 181/255).opacity(0.92)
                        : Color(red: 255/255, green: 244/255, blue: 226/255).opacity(0.52)
                )
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(
                            isActive
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 224/255, green: 186/255, blue: 117/255).opacity(0.2),
                                        Color(red: 116/255, green: 74/255, blue: 39/255).opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(red: 255/255, green: 248/255, blue: 236/255).opacity(0.045),
                                        Color(red: 255/255, green: 248/255, blue: 236/255).opacity(0.02)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isActive
                                ? Color(red: 224/255, green: 186/255, blue: 117/255).opacity(0.24)
                                : Color(red: 255/255, green: 240/255, blue: 214/255).opacity(0.08),
                            lineWidth: 1
                        )
                )
                // Active glow
                .shadow(
                    color: isActive
                        ? Color(red: 224/255, green: 186/255, blue: 117/255).opacity(0.08)
                        : .clear,
                    radius: 15, x: 0, y: 0
                )
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
