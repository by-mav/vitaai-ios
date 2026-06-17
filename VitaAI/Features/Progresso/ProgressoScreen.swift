import SwiftUI

// MARK: - ProgressoScreen — Trilha de carreira médica (gold 3D, estilo Duolingo)
//
// 2026-06-16 (Rafael): a aba Progresso é uma TRILHA de carreira — 50 fases em 5
// tiers (10 cada), cada tier uma etapa da carreira médica com sua cor dourada.
//
//  - Cada fase = um NÍVEL (1…50), linkado direto no nível da conta (API):
//      nível da conta  > fase  → concluída (dourada + ✓)
//      nível da conta == fase  → atual (anel pulsante + bonequinho aqui)
//      nível da conta  < fase  → bloqueada (cinza + cadeado)
//  - O bonequinho (Image "vita-btn-active") sobe pro nó do nível atual
//    (auto-scroll até ele no boot).
//  - Tocar a fase atual abre o estudo que dá XP → sobe nível → desbloqueia a
//    próxima → o boneco sobe. O level-up/badges (VitaLevelUpOverlay) já disparam.
//  - Nível/XP/streak e achievements vêm do gamify real (ProgressoViewModel +
//    GamificationEventManager). Toca no nível → Conquistas.
//
// Mantém `ProgressoScreen()` (sem params) → AppRouter e o pbxproj intocados.

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var pulse = false
    @State private var scrolledToCurrent = false

    private var vmProg: ProgressoViewModel { container.progressoViewModel }
    private var dash: DashboardViewModel { container.dashboardViewModel }
    private var gamify: GamificationEventManager { container.gamificationEvents }

    private var userLevel: Int { max(1, vmProg.userProgress?.level ?? gamify.currentLevel) }
    private var xpProgress: Double { vmProg.userProgress?.levelProgress ?? gamify.currentXpProgress }
    private var streak: Int { vmProg.userProgress?.currentStreak ?? dash.streakDays }
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    gamifyStrip
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(Self.tiers) { tier in
                        tierHeader(tier)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                            .padding(.bottom, 4)
                            .id("tier-\(tier.index)")

                        ForEach(phases(in: tier)) { phase in
                            phaseRow(phase)
                                .id(phase.level)
                        }
                    }
                }
                .padding(.bottom, 64)
            }
            .trackedScroll()
            .onChange(of: userLevel) { _, lvl in
                withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(lvl, anchor: .center) }
            }
            .task {
                await vmProg.loadIfNeeded()
                await dash.loadDashboard()
                ScreenLoadContext.finish(for: "Progresso")
                if let stats = try? await container.api.getGamificationStats() {
                    gamify.updateFromStats(stats)
                }
                if !scrolledToCurrent {
                    scrolledToCurrent = true
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.easeInOut(duration: 0.6)) {
                        proxy.scrollTo(min(userLevel, 50), anchor: .center)
                    }
                }
            }
        }
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
        }
        .trackScreen("Progresso")
    }

    // MARK: - Gamify strip (nível + XP + streak — dado real)

    private var gamifyStrip: some View {
        HStack(spacing: 12) {
            Button(action: { router.navigate(to: .achievements) }) {
                levelBadge(userLevel)
            }
            .buttonStyle(TrailPressStyle())

            VStack(alignment: .leading, spacing: 6) {
                xpBar(progress: xpProgress)
                HStack {
                    Text(currentTier.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                    Spacer()
                    Text("Nível \(userLevel)")
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

    private var currentTier: CareerTier {
        Self.tiers.last(where: { userLevel >= $0.levelStart }) ?? Self.tiers[0]
    }

    private func levelBadge(_ level: Int) -> some View {
        ZStack {
            Circle().fill(currentTier.dark)
                .frame(width: 44, height: 44)
                .offset(y: 3)
            Circle().fill(faceGradient(currentTier, locked: false, radius: 22))
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
                            colors: [currentTier.dark, currentTier.bright],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? 9 : 0), height: 9)
                    .shadow(color: currentTier.mid.opacity(0.4), radius: 4, y: 0)
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

    // MARK: - Tier header (banner da etapa de carreira)

    private func tierHeader(_ tier: CareerTier) -> some View {
        let reached = userLevel >= tier.levelStart
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(tier.dark).frame(width: 40, height: 40).offset(y: 2)
                Circle().fill(faceGradient(tier, locked: !reached, radius: 20)).frame(width: 40, height: 40)
                Image(systemName: reached ? tier.icon : "lock.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(reached ? Color.white : VitaColors.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.1)
                    .foregroundStyle(reached ? tier.bright : VitaColors.textTertiary)
                Text("\(tier.subtitle) · Níveis \(tier.levelStart)–\(tier.levelStart + 9)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(reached ? tier.mid.opacity(0.10) : VitaColors.glassBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(reached ? tier.mid.opacity(0.30) : VitaColors.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Fase (nó da trilha)

    private func phaseRow(_ phase: Phase) -> some View {
        let state = phaseState(phase)
        let dx = CGFloat(sin(Double(phase.level) * 0.9)) * 60
        return ZStack {
            VStack(spacing: 8) {
                if state == .completed { starRow(phase.tier, filled: true) }
                else if state == .current { starRow(phase.tier, filled: false) }

                Button(action: { tapPhase(phase, state: state) }) {
                    coin(phase, state: state)
                }
                .buttonStyle(TrailPressStyle())
                .disabled(state == .locked)

                if state == .current {
                    startPill(phase.tier)
                } else {
                    Text(state == .locked ? "Nível \(phase.level)" : phase.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(state == .locked ? VitaColors.textTertiary : VitaColors.textSecondary)
                        .lineLimit(1)
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

            if state == .current {
                mascot
                    .offset(x: dx + 64, y: -8)
            }
        }
        .padding(.vertical, 10)
    }

    private func coin(_ phase: Phase, state: PhaseState) -> some View {
        let locked = state == .locked
        let size: CGFloat = state == .current ? 76 : 68
        let isTierReward = phase.level % 10 == 0

        return ZStack {
            if state == .current {
                Circle()
                    .stroke(phase.tier.bright.opacity(0.55), lineWidth: 5)
                    .frame(width: size + 16, height: size + 16)
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .shadow(color: phase.tier.mid.opacity(0.5), radius: 12)
            }

            Circle().fill(thickness(phase.tier, locked: locked))
                .frame(width: size, height: size)
                .offset(y: 7)
                .shadow(color: .black.opacity(0.45), radius: 9, y: 8)

            Circle().fill(faceGradient(phase.tier, locked: locked, radius: size / 2))
                .frame(width: size, height: size)
                .overlay(
                    Ellipse()
                        .fill(Color.white.opacity(locked ? 0.10 : 0.40))
                        .frame(width: size * 0.42, height: size * 0.24)
                        .offset(x: -size * 0.12, y: -size * 0.22)
                        .blur(radius: 1)
                )
                .overlay(Circle().stroke(Color.white.opacity(locked ? 0.06 : 0.18), lineWidth: 1))

            Image(systemName: locked ? "lock.fill" : (isTierReward ? "trophy.fill" : phase.icon))
                .font(.system(size: state == .current ? 30 : 26, weight: .bold))
                .foregroundStyle(locked ? VitaColors.textTertiary : Color.white)
                .shadow(color: Color(red: 0.30, green: 0.20, blue: 0.05).opacity(locked ? 0 : 0.5), radius: 1, y: 1)

            if state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(VitaColors.dataGreen)
                    .background(Circle().fill(Color.white).frame(width: 17, height: 17))
                    .offset(x: size * 0.34, y: -size * 0.34)
            }
        }
        .frame(width: size + 20, height: size + 20)
    }

    private var mascot: some View {
        Image("vita-btn-active")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 52, height: 52)
            .scaleEffect(pulse ? 1.04 : 0.98)
            .shadow(color: VitaColors.accent.opacity(0.35), radius: 8, y: 4)
    }

    private func faceGradient(_ tier: CareerTier, locked: Bool, radius: CGFloat) -> RadialGradient {
        let colors: [Color] = locked
            ? [Color(white: 0.32), Color(white: 0.22), Color(white: 0.14)]
            : [tier.bright, tier.mid, tier.dark]
        return RadialGradient(
            colors: colors,
            center: UnitPoint(x: 0.34, y: 0.30),
            startRadius: 2,
            endRadius: radius * 1.05
        )
    }

    private func thickness(_ tier: CareerTier, locked: Bool) -> Color {
        locked ? Color(white: 0.12) : tier.dark
    }

    private func starRow(_ tier: CareerTier, filled: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(filled ? tier.bright : VitaColors.textTertiary.opacity(0.5))
            }
        }
    }

    private func startPill(_ tier: CareerTier) -> some View {
        Text("Comece")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(red: 0.20, green: 0.13, blue: 0.04))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(tier.bright))
            .shadow(color: tier.mid.opacity(0.4), radius: 6, y: 2)
    }

    // MARK: - State + ações

    private func phaseState(_ phase: Phase) -> PhaseState {
        if userLevel > phase.level { return .completed }
        if userLevel == phase.level { return .current }
        return .locked
    }

    private func tapPhase(_ phase: Phase, state: PhaseState) {
        guard state != .locked else { return }
        // A fase atual/concluída leva pro estudo que dá XP → sobe nível → libera a próxima.
        if flashcardsDue > 0 {
            openStudy(.flashcardHome())
        } else {
            openStudy(.qbank)
        }
    }

    /// Abre uma sub-feature de Estudos trocando a tab pro bottom-nav refletir o
    /// contexto (mesmo padrão dos deep links do AppRouter).
    private func openStudy(_ route: Route) {
        router.selectedTab = .estudos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            router.navigate(to: route)
        }
    }

    // MARK: - Modelo das 50 fases / 5 tiers

    private enum PhaseState { case completed, current, locked }

    private struct CareerTier: Identifiable {
        let index: Int
        let name: String
        let subtitle: String
        let icon: String
        let bright: Color
        let mid: Color
        let dark: Color
        var levelStart: Int { index * 10 + 1 }
        var id: Int { index }
    }

    private struct Phase: Identifiable {
        let level: Int      // 1…50 (global, == nível da conta)
        let title: String
        let icon: String
        let tier: CareerTier
        var id: Int { level }
    }

    private static let tiers: [CareerTier] = [
        CareerTier(index: 0, name: "Ciclo Básico", subtitle: "Fundamentos", icon: "atom",
                   bright: Color(red: 0.91, green: 0.72, blue: 0.40),
                   mid:    Color(red: 0.78, green: 0.57, blue: 0.29),
                   dark:   Color(red: 0.45, green: 0.30, blue: 0.13)),
        CareerTier(index: 1, name: "Ciclo Clínico", subtitle: "Diagnóstico", icon: "stethoscope",
                   bright: VitaColors.accentHover,
                   mid:    VitaColors.accent,
                   dark:   VitaColors.accentDark),
        CareerTier(index: 2, name: "Internato", subtitle: "Prática hospitalar", icon: "cross.case.fill",
                   bright: Color(red: 1.00, green: 0.82, blue: 0.48),
                   mid:    Color(red: 0.84, green: 0.64, blue: 0.24),
                   dark:   Color(red: 0.52, green: 0.37, blue: 0.13)),
        CareerTier(index: 3, name: "Residência", subtitle: "Especialização", icon: "graduationcap.fill",
                   bright: Color(red: 1.00, green: 0.86, blue: 0.63),
                   mid:    Color(red: 0.83, green: 0.66, blue: 0.31),
                   dark:   Color(red: 0.47, green: 0.33, blue: 0.12)),
        CareerTier(index: 4, name: "Especialista", subtitle: "Maestria", icon: "rosette",
                   bright: Color(red: 1.00, green: 0.94, blue: 0.80),
                   mid:    Color(red: 0.91, green: 0.81, blue: 0.53),
                   dark:   Color(red: 0.62, green: 0.50, blue: 0.24)),
    ]

    private static let phaseTitles: [[String]] = [
        ["Anatomia", "Histologia", "Embriologia", "Biologia Celular", "Bioquímica",
         "Fisiologia", "Genética", "Imunologia", "Microbiologia", "Bioética"],
        ["Patologia", "Farmacologia", "Semiologia", "Cardiologia", "Pneumologia",
         "Gastroenterologia", "Neurologia", "Endocrinologia", "Nefrologia", "Hematologia"],
        ["Clínica Médica", "Cirurgia", "Pediatria", "Gineco-Obstetrícia", "Emergência",
         "Terapia Intensiva", "Saúde da Família", "Psiquiatria", "Ortopedia", "Dermatologia"],
        ["Prova de Residência", "R1", "Plantões", "Visita Clínica", "Pesquisa Clínica",
         "Especialização", "Artigos", "Congressos", "Mentoria", "Defesa"],
        ["Título de Especialista", "Preceptoria", "Coordenação", "Docência", "Liderança",
         "Inovação", "Pesquisa Sênior", "Referência", "Legado", "Mestre"],
    ]

    private func phases(in tier: CareerTier) -> [Phase] {
        (0..<10).map { i in
            Phase(
                level: tier.levelStart + i,
                title: Self.phaseTitles[tier.index][i],
                icon: tier.icon,
                tier: tier
            )
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
