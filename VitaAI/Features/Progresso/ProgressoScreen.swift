import SwiftUI

// MARK: - ProgressoScreen — Trilha de progresso (gold 3D)
//
// 2026-06-16 (Rafael): a aba Progresso virou uma TRILHA gamificada estilo
// Duolingo, no Vita Gold Glassmorphism — nós em "moeda" 3D dourada com brilho
// no topo, espessura embaixo e sombra no chão (profundidade real, nada chapado).
//
//  - Header liga no gamify REAL: ProgressoViewModel.userProgress (nível, XP,
//    streak) com fallback no GamificationEventManager. Nada inventado.
//  - Cada nó abre uma feature real que JÁ loga atividade e dá XP
//    (Flashcards / QBank / Simulado / Atlas 3D / Transcrição) → o overlay de
//    level-up (VitaLevelUpOverlay) e os badges disparam sozinhos ao subir.
//  - Baú no topo abre Conquistas; nó final abre o Ranking.
//
// Mantém `ProgressoScreen()` (sem params) → AppRouter e o pbxproj intocados.

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var pulse = false

    private var vmProg: ProgressoViewModel { container.progressoViewModel }
    private var dash: DashboardViewModel { container.dashboardViewModel }
    private var gamify: GamificationEventManager { container.gamificationEvents }

    private var level: Int { vmProg.userProgress?.level ?? gamify.currentLevel }
    private var xpProgress: Double { vmProg.userProgress?.levelProgress ?? gamify.currentXpProgress }
    private var streak: Int { vmProg.userProgress?.currentStreak ?? dash.streakDays }
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                gamifyStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                unitBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                trailView
                    .padding(.top, 20)
                    .padding(.bottom, 56)
            }
        }
        .trackedScroll()
        .refreshable {
            await vmProg.load()
            await dash.loadDashboard()
            if let stats = try? await container.api.getGamificationStats() {
                gamify.updateFromStats(stats)
            }
        }
        .onAppear {
            if !pulse {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            Task {
                await vmProg.loadIfNeeded()
                await dash.loadDashboard()
                ScreenLoadContext.finish(for: "Progresso")
                if let stats = try? await container.api.getGamificationStats() {
                    gamify.updateFromStats(stats)
                }
            }
        }
        .trackScreen("Progresso")
    }

    // MARK: - Gamify strip (nível + XP + streak — dado real)

    private var gamifyStrip: some View {
        HStack(spacing: 12) {
            levelBadge(level)

            VStack(alignment: .leading, spacing: 6) {
                xpBar(progress: xpProgress)
                HStack {
                    Text("Nível \(level)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                    Spacer()
                    Text("Nível \(level + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }

            streakChip(streak)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VitaColors.glassBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
        )
    }

    private func levelBadge(_ level: Int) -> some View {
        ZStack {
            Circle().fill(VitaColors.accentDark)
                .frame(width: 44, height: 44)
                .offset(y: 3)
            Circle().fill(coinFace(bright: true, radius: 22))
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            Text("\(level)")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color(red: 0.20, green: 0.13, blue: 0.04))
        }
        .frame(width: 48, height: 48)
    }

    private func xpBar(progress: Double) -> some View {
        let clamped = min(max(progress, 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(VitaColors.surfaceBorder).frame(height: 9)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [VitaColors.accentDark, VitaColors.accentHover],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? 9 : 0), height: 9)
                    .shadow(color: VitaColors.accent.opacity(0.4), radius: 4, y: 0)
            }
        }
        .frame(height: 9)
    }

    private func streakChip(_ days: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.dataAmber)
            Text("\(days)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(VitaColors.dataAmber.opacity(0.12))
                .overlay(Capsule().stroke(VitaColors.dataAmber.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - Unit banner (header da jornada — glass dourado)

    private var unitBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SUA JORNADA DE HOJE")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                Text(unitTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(VitaColors.accentLight)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(VitaColors.accent.opacity(0.14))
                        .overlay(Circle().stroke(VitaColors.accent.opacity(0.25), lineWidth: 1))
                )
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private var unitTitle: String {
        let name = dash.subjects.first?.name ?? ""
        return name.isEmpty ? "Plano de estudos de hoje" : name
    }

    // MARK: - Trilha

    private var trailView: some View {
        let nodes = makeNodes()
        return VStack(spacing: 6) {
            chestNode
                .padding(.bottom, 8)
            ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                trailRow(node: node, index: idx)
            }
        }
    }

    private func trailRow(node: TrailNode, index: Int) -> some View {
        let dx = CGFloat(sin(Double(index) * 0.9)) * 62
        return VStack(spacing: 9) {
            switch node.state {
            case .completed: starRow(filled: true)
            case .current:   starRow(filled: false)
            case .available: EmptyView()
            }

            nodeButton(node)

            if node.state == .current {
                startPill
            } else {
                Text(node.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(VitaColors.glassBg)
                            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
                    )
            }
        }
        .offset(x: dx)
        .padding(.vertical, 10)
    }

    private func nodeButton(_ node: TrailNode) -> some View {
        Button(action: node.action) {
            coin(node)
        }
        .buttonStyle(TrailPressStyle())
    }

    private func coin(_ node: TrailNode) -> some View {
        let bright = node.state != .available
        let size: CGFloat = node.state == .current ? 76 : 68

        return ZStack {
            if node.state == .current {
                Circle()
                    .stroke(VitaColors.accentHover.opacity(0.55), lineWidth: 5)
                    .frame(width: size + 16, height: size + 16)
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .shadow(color: VitaColors.accent.opacity(0.5), radius: 12)
            }

            // Espessura da "moeda" 3D + sombra no chão
            Circle().fill(VitaColors.accentDark)
                .frame(width: size, height: size)
                .offset(y: 7)
                .shadow(color: .black.opacity(0.45), radius: 9, y: 8)

            // Face com degradê radial (brilho topo-esquerda → ouro → base escura)
            Circle().fill(coinFace(bright: bright, radius: size / 2))
                .frame(width: size, height: size)
                .overlay(
                    Ellipse()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: size * 0.42, height: size * 0.24)
                        .offset(x: -size * 0.12, y: -size * 0.22)
                        .blur(radius: 1)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

            Image(systemName: node.icon)
                .font(.system(size: node.state == .current ? 30 : 27, weight: .bold))
                .foregroundStyle(Color.white)
                .shadow(color: Color(red: 0.30, green: 0.20, blue: 0.05).opacity(0.5), radius: 1, y: 1)

            if node.state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(VitaColors.dataGreen)
                    .background(Circle().fill(Color.white).frame(width: 17, height: 17))
                    .offset(x: size * 0.34, y: -size * 0.34)
            }
        }
        .frame(width: size + 20, height: size + 20)
    }

    private func coinFace(bright: Bool, radius: CGFloat) -> RadialGradient {
        RadialGradient(
            colors: bright
                ? [VitaColors.accentHover, VitaColors.accent, VitaColors.accentDark]
                : [VitaColors.accent, VitaColors.accentDark],
            center: UnitPoint(x: 0.34, y: 0.30),
            startRadius: 2,
            endRadius: radius * 1.05
        )
    }

    private func starRow(filled: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(filled ? VitaColors.accentHover : VitaColors.textTertiary.opacity(0.5))
            }
        }
    }

    private var startPill: some View {
        Text("Comece")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(red: 0.20, green: 0.13, blue: 0.04))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(VitaColors.accentHover))
            .shadow(color: VitaColors.accent.opacity(0.4), radius: 6, y: 2)
    }

    private var chestNode: some View {
        Button(action: { router.navigate(to: .achievements) }) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.accentDark)
                        .frame(width: 66, height: 58)
                        .offset(y: 6)
                        .shadow(color: .black.opacity(0.40), radius: 8, y: 7)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(coinFace(bright: true, radius: 40))
                        .frame(width: 66, height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    Image(systemName: "gift.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color(red: 0.30, green: 0.20, blue: 0.05).opacity(0.5), radius: 1, y: 1)
                }
                Text("Próxima recompensa")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .buttonStyle(TrailPressStyle())
    }

    // MARK: - Node model

    private enum TrailState { case completed, current, available }

    private struct TrailNode: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let state: TrailState
        let action: () -> Void
    }

    private func makeNodes() -> [TrailNode] {
        let due = flashcardsDue
        let revisaoDone = due == 0
        return [
            TrailNode(
                title: revisaoDone ? "Revisão em dia" : "Revisar \(due) cards",
                icon: "rectangle.on.rectangle.angled",
                state: revisaoDone ? .completed : .current,
                action: { openStudy(.flashcardHome()) }
            ),
            TrailNode(
                title: "Questões",
                icon: "checklist",
                state: revisaoDone ? .current : .available,
                action: { openStudy(.qbank) }
            ),
            TrailNode(
                title: "Simulado",
                icon: "doc.text.magnifyingglass",
                state: .available,
                action: { openStudy(.simuladoHome) }
            ),
            TrailNode(
                title: "Caso clínico",
                icon: "brain.head.profile",
                state: .available,
                action: { openStudy(.atlas3D) }
            ),
            TrailNode(
                title: "Gravar aula",
                icon: "waveform",
                state: .available,
                action: { openStudy(.transcricao) }
            ),
            TrailNode(
                title: "Ranking",
                icon: "trophy.fill",
                state: .available,
                action: { router.navigate(to: .leaderboard) }
            ),
        ]
    }

    /// Abre uma sub-feature de Estudos trocando a tab pro bottom-nav refletir o
    /// contexto (mesmo padrão usado nos deep links do AppRouter).
    private func openStudy(_ route: Route) {
        router.selectedTab = .estudos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            router.navigate(to: route)
        }
    }
}

// MARK: - Press style (afunda a moeda no toque)

private struct TrailPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
