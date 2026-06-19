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
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .estudos: return "book.fill"
        case .faculdade: return "graduationcap.fill"
        case .progresso: return "chart.bar.fill"
        }
    }
    var shortLabel: String {
        switch self {
        case .home: return "Home"
        case .estudos: return "Estudos"
        case .faculdade: return "Jornada"
        case .progresso: return "Progresso"
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
}

// MARK: - VitaTabBar — bottom nav colada VERBATIM do Pixio (berco/bump + grabber),
// re-skin dourado via PixioCompat. Centro = mascote Vita (abre chat). Grabber =
// abre a gaveta "+" (VitaAddSheet). SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var homeGlass: Bool = false
    var onCenterTap: () -> Void
    var onTabReselect: ((TabItem) -> Void)? = nil
    var onAddSelect: ((VitaAddSheet.Kind) -> Void)? = nil

    @State private var vitaAwake: Bool = false
    @State private var showAdd: Bool = false
    @Environment(\.colorScheme) private var scheme

    private var navContactShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        PixioShadow.contact(dark: scheme == .dark)
    }
    private var navAmbientShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        PixioShadow.ambient(dark: scheme == .dark)
    }

    private let bumpHeight: CGFloat = 21
    private let bumpWidth: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            VitaBarGrabber(active: showAdd, homeGlass: homeGlass) { showAdd = true }
                .frame(height: bumpHeight)
                .padding(.top, 5)

            GeometryReader { geo in
                let padding = geo.size.width / 24
                let colWidth = (geo.size.width - 2 * padding) / 5
                HStack(spacing: 0) {
                    tabButton(.home,      width: colWidth)
                    tabButton(.estudos,   width: colWidth)
                    vitaCenterButton(width: colWidth)
                    tabButton(.faculdade, width: colWidth)
                    tabButton(.progresso, width: colWidth)
                }
                .padding(.horizontal, padding)
            }
            .frame(height: 46)
            .padding(.top, 3)
            .padding(.bottom, 2)
        }
        // Rafael 2026-06-17: puxa o conteúdo pra baixo (centro do ícone vira o centro
        // da barra) e encolhe a faixa vazia embaixo — em vez de reservar a safe area
        // inteira (~34px) que deixava os ícones altos com vão escuro embaixo.
        .padding(.bottom, homeGlass ? 0 : 4)
        .offset(y: homeGlass ? 10 : 0)
        .background(navBackground.ignoresSafeArea(edges: .bottom))
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showAdd) {
            VitaAddSheet(onSelect: { kind in
                showAdd = false
                onAddSelect?(kind)
            })
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .presentationDetents([.height(360)])
            .presentationBackground(.clear)
            .presentationDragIndicator(.visible)
        }
    }

    private func tabButton(_ item: TabItem, width: CGFloat) -> some View {
        let isSelected = selectedTab == item
        return Button(action: {
            if isSelected {
                onTabReselect?(item)
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = item }
                PixioHaptics.soft()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(PixioTypo.sans(size: 19, weight: isSelected ? .medium : .light))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 21)
            Text(item.shortLabel)
                    .font(PixioTypo.sans(size: 10, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(tabForeground(isSelected: isSelected))
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.testID)
        .accessibilityLabel(item.rawValue)
    }

    private func vitaCenterButton(width: CGFloat) -> some View {
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
                .frame(width: 54, height: 54)
                .scaleEffect(vitaAwake ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vitaAwake)
                .frame(width: width)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_vita_chat")
        .accessibilityLabel("Abrir Vita Chat")
    }

    @ViewBuilder
    private var navBackground: some View {
        let shape = VitaNavBarBumpShape(bumpWidth: bumpWidth, bumpHeight: bumpHeight)
        if homeGlass {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color(red: 0.42, green: 0.72, blue: 0.34).opacity(0.18),
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.16),
                                Color.black.opacity(0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
                )
                .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: -4)
                .shadow(color: Color(red: 0.20, green: 0.47, blue: 0.19).opacity(0.20), radius: 22, x: 0, y: -8)
        } else {
            shape
                .fill(PixioColor.cardLight)
                .overlay(
                    shape.stroke(PixioColor.borderLight.opacity(0.7), lineWidth: 0.5)
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(scheme == .dark ? 0.18 : 0.0),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.75
                    )
                )
                .shadow(color: navContactShadow.color, radius: navContactShadow.radius, x: 0, y: -navContactShadow.y)
                .shadow(color: navAmbientShadow.color, radius: navAmbientShadow.radius, x: 0, y: -navAmbientShadow.y)
        }
    }

    private func tabForeground(isSelected: Bool) -> Color {
        if homeGlass {
            return isSelected ? .white : .white.opacity(0.68)
        }
        return isSelected ? PixioColor.textLight : PixioColor.textLightMuted
    }
}

// MARK: - VitaNavBarBumpShape — colado verbatim do PixioNavBarBumpShape
struct VitaNavBarBumpShape: Shape {
    var bumpWidth: CGFloat
    var bumpHeight: CGFloat
    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let flatTop = rect.minY + bumpHeight
        let peakY = rect.minY
        let half = bumpWidth / 2
        let lStart = midX - half
        let rEnd = midX + half
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: flatTop))
        p.addLine(to: CGPoint(x: lStart, y: flatTop))
        p.addCurve(to: CGPoint(x: midX, y: peakY),
                   control1: CGPoint(x: lStart + half * 0.5, y: flatTop),
                   control2: CGPoint(x: midX - half * 0.5, y: peakY))
        p.addCurve(to: CGPoint(x: rEnd, y: flatTop),
                   control1: CGPoint(x: midX + half * 0.5, y: peakY),
                   control2: CGPoint(x: rEnd - half * 0.5, y: flatTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: flatTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - VitaBarGrabber — colado verbatim do PixioBarGrabber (tap abre a gaveta)
private struct VitaBarGrabber: View {
    var active: Bool = false
    var homeGlass: Bool = false
    var onTap: () -> Void
    @State private var glow = false
    var body: some View {
        let theme = PixioColor.brand
        let tint = active ? theme : (homeGlass ? Color.white.opacity(0.62) : PixioColor.textLightFaint)
        return ZStack {
            if homeGlass {
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.42).opacity(glow ? 0.42 : 0.18),
                                Color.white.opacity(glow ? 0.16 : 0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 28
                        )
                    )
                    .frame(width: 48, height: 28)
                    .blur(radius: 3)
                    .blendMode(.plusLighter)
            }

            VStack(spacing: PixioSpacing.xxs) {
                Capsule().fill(tint).frame(width: 16, height: 3)
                Grid(horizontalSpacing: PixioSpacing.xxs, verticalSpacing: PixioSpacing.xxs) {
                    ForEach(0..<3, id: \.self) { _ in
                        GridRow {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().fill(tint).frame(width: 3, height: 3)
                            }
                        }
                    }
                }
            }
        }
        .shadow(color: homeGlass ? Color(red: 1.0, green: 0.82, blue: 0.42).opacity(glow ? 0.46 : 0.20) : (active ? theme.opacity(glow ? 0.85 : 0.28) : .clear), radius: homeGlass ? (glow ? 11 : 5) : (active ? (glow ? 7 : 3) : 0))
        .animation(.easeInOut(duration: 0.3), value: active)
        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: glow)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { PixioHaptics.tap(); onTap() }
        .onAppear { glow = true }
        .accessibilityLabel("Adicionar")
        .accessibilityIdentifier("quick_add_drawer_button")
        .accessibilityAddTraits(.isButton)
    }
}
