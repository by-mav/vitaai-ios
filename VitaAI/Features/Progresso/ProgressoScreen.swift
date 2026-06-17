import SwiftUI

// MARK: - ProgressoScreen — Mapa vivo da carreira médica (gold 3D, estilo Duolingo)
//
// 2026-06-16 (Rafael): home/mapa vivo do Vita. Uma tela só = gamificação no
// centro + estudo sempre a 1 toque.
//
//  - TRILHA = as 21 etapas reais da carreira (Termômetro → Vita-Caduceu),
//    espelhando o sistema canônico do backend (gamification.ts: getLevelIcon,
//    1 ícone a cada 5 níveis, 6 tiers Calouro→God). Estado vem do nível real:
//      nível passou da etapa  → concluída (✓)
//      nível dentro da etapa  → atual (anel + bonequinho Vita pulando)
//      nível abaixo           → bloqueada (cinza + cadeado)
//  - BAÚS nas viradas de tier (checkpoints). Cor muda por tier.
//  - DOCK 3D fixo: Flashcards · Questões · Simulados · Transcrição (toca → vai
//    pra ferramenta). É assim que se estuda — a trilha só mostra o progresso.
//  - Bonequinho = o Vita (asset "vita-btn-active"), pulando no nível atual.
//
// Ícones das etapas: SF Symbols por enquanto (limpos/garantidos); os 21 webp
// oficiais (/designs/levels/final/) entram quando confirmar o recorte deles.
// Ciclo do prestige (Cursinho/Faculdade/Residência/Revalida) entra junto com a
// extensão do GamificationStats — por ora mostro tier + nível (já corretos).
//
// Mantém `ProgressoScreen()` (sem params) → AppRouter/pbxproj intocados.

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var pulse = false
    @State private var hop = false
    @State private var scrolledToCurrent = false

    private var vmProg: ProgressoViewModel { container.progressoViewModel }
    private var dash: DashboardViewModel { container.dashboardViewModel }
    private var gamify: GamificationEventManager { container.gamificationEvents }

    private var userLevel: Int { max(1, vmProg.userProgress?.level ?? gamify.currentLevel) }
    private var xpProgress: Double { vmProg.userProgress?.levelProgress ?? gamify.currentXpProgress }
    private var streak: Int { vmProg.userProgress?.currentStreak ?? dash.streakDays }
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    private var currentStage: Stage {
        Self.stages.first(where: { userLevel >= $0.minLevel && userLevel <= $0.maxLevel }) ?? Self.stages[0]
    }
    private var currentTier: Tier { Self.tiers[currentStage.tierIdx] }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerStrip
                .padding(.horizontal, 16)
                .padding(.top, 8)
            toolsDock
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(trailItems.enumerated()), id: \.element.id) { idx, item in
                            trailRow(item, rowIndex: idx)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 56)
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
                            proxy.scrollTo(currentStage.index, anchor: .center)
                        }
                    }
                }
                .onChange(of: userLevel) { _, _ in
                    withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(currentStage.index, anchor: .center) }
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
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
            if !hop {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { hop = true }
            }
        }
        .trackScreen("Progresso")
    }

    // MARK: - Header (tier + nível + XP + streak)

    private var headerStrip: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(currentTier.dark).frame(width: 46, height: 46).offset(y: 3)
                Circle().fill(faceGradient(currentTier, locked: false, radius: 23)).frame(width: 46, height: 46)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                Image(systemName: currentStage.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(currentTier.name.uppercased())
                        .font(.system(size: 11, weight: .bold)).kerning(1.0)
                        .foregroundStyle(currentTier.bright)
                    Spacer()
                    Text("Nível \(userLevel)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                }
                xpBar(progress: xpProgress)
            }

            streakChip(streak)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [currentTier.dark.opacity(0.62), Color(white: 0.10).opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay( // brilho do tier no canto superior (luz)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(RadialGradient(colors: [currentTier.bright.opacity(0.22), .clear],
                                             center: UnitPoint(x: 0.12, y: 0.0), startRadius: 2, endRadius: 170))
                )
                .overlay(alignment: .top) { // brilho especular no topo
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
                        .frame(height: 26).padding(.horizontal, 1).padding(.top, 1)
                }
                .overlay( // moldura dourada do tier (rim light)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [currentTier.bright.opacity(0.45), currentTier.dark.opacity(0.25)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.34), radius: 12, y: 6)
                .shadow(color: currentTier.mid.opacity(0.22), radius: 18)
        )
    }

    private func xpBar(progress: Double) -> some View {
        let clamped = min(max(progress, 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(VitaColors.surfaceBorder).frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [currentTier.dark, currentTier.bright], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? 8 : 0), height: 8)
                    .shadow(color: currentTier.mid.opacity(0.4), radius: 4, y: 0)
            }
        }
        .frame(height: 8)
    }

    private func streakChip(_ days: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(VitaColors.dataAmber)
            Text("\(days)").font(.system(size: 15, weight: .heavy)).foregroundStyle(VitaColors.textPrimary)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(Capsule().fill(VitaColors.dataAmber.opacity(0.12)).overlay(Capsule().stroke(VitaColors.dataAmber.opacity(0.25), lineWidth: 1)))
    }

    // MARK: - Dock de ferramentas (3D, fixo)

    private var toolsDock: some View {
        HStack(spacing: 11) {
            toolButton("Flashcards", icon: "rectangle.on.rectangle.angled",
                       bright: Color(red: 0.78, green: 0.69, blue: 1.0), mid: VitaColors.toolFlashcards, dark: Color(red: 0.29, green: 0.23, blue: 0.63)) {
                openStudy(.flashcardHome())
            }
            toolButton("Questões", icon: "checklist",
                       bright: VitaColors.accentHover, mid: VitaColors.accent, dark: VitaColors.accentDark) {
                openStudy(.qbank)
            }
            toolButton("Simulados", icon: "doc.text.magnifyingglass",
                       bright: Color(red: 0.56, green: 0.77, blue: 0.98), mid: VitaColors.toolSimulados, dark: Color(red: 0.10, green: 0.37, blue: 0.65)) {
                openStudy(.simuladoHome)
            }
            toolButton("Transcrição", icon: "waveform",
                       bright: Color(red: 0.50, green: 0.88, blue: 0.83), mid: VitaColors.toolTranscricao, dark: Color(red: 0.08, green: 0.50, blue: 0.47)) {
                openStudy(.transcricao)
            }
        }
    }

    private func toolButton(_ title: String, icon: String, bright: Color, mid: Color, dark: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous).fill(dark)
                        .frame(width: 62, height: 62).offset(y: 5)
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(RadialGradient(colors: [bright, mid], center: UnitPoint(x: 0.34, y: 0.28), startRadius: 2, endRadius: 60))
                        .frame(width: 62, height: 62)
                        .overlay(
                            Ellipse().fill(Color.white.opacity(0.40)).frame(width: 24, height: 12)
                                .offset(x: -10, y: -16).blur(radius: 1)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    Image(systemName: icon).font(.system(size: 25, weight: .bold)).foregroundStyle(Color.white)
                        .shadow(color: Color(red: 0.10, green: 0.08, blue: 0.04).opacity(0.4), radius: 1, y: 1)
                }
                .shadow(color: .black.opacity(0.40), radius: 10, y: 7)
            }
            .buttonStyle(TrailPressStyle())
            Text(title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trilha

    private func trailRow(_ item: TrailItem, rowIndex: Int) -> some View {
        let dx = CGFloat(sin(Double(rowIndex) * 0.95)) * 58
        return Group {
            switch item {
            case .stage(let s): stageNode(s)
            case .chest(let t): chestNode(t)
            }
        }
        .offset(x: dx)
        .padding(.vertical, 7)
        .id(item.id)
    }

    private func stageNode(_ stage: Stage) -> some View {
        let state = stageState(stage)
        let tier = Self.tiers[stage.tierIdx]
        return ZStack {
            VStack(spacing: 6) {
                Button(action: { tapStage(state) }) {
                    coin(stage: stage, tier: tier, state: state)
                }
                .buttonStyle(TrailPressStyle())
                .disabled(state != .current)

                Text(state == .locked ? "Nível \(stage.minLevel)" : stage.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state == .locked ? VitaColors.textTertiary : VitaColors.textSecondary)
                    .lineLimit(1)
            }

            if state == .current {
                // Vita "em pé" EM CIMA do botão do nível atual (centralizado).
                mascot.offset(x: 0, y: -50)
            }
        }
    }

    // Medalhão premium: render 3D oficial sob luz vinda de cima —
    // elevação (sombra), moldura metálica do tier (rim light), brilho especular
    // no topo, anel pulsante no nível atual. Bloqueado = cofre escuro + cadeado.
    private func coin(stage: Stage, tier: Tier, state: StageState) -> some View {
        let locked = state == .locked
        let size: CGFloat = state == .current ? 78 : 62
        let radius: CGFloat = size * 0.30
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            // anel pulsante (nível atual)
            if state == .current {
                RoundedRectangle(cornerRadius: radius + 6, style: .continuous)
                    .stroke(tier.bright.opacity(0.6), lineWidth: 4)
                    .frame(width: size + 18, height: size + 18)
                    .scaleEffect(pulse ? 1.05 : 0.96)
                    .shadow(color: tier.mid.opacity(0.55), radius: 13)
            }
            // base escura deslocada = elevação (peça flutua sob luz de cima)
            shape.fill(locked ? Color(white: 0.09) : tier.dark)
                .frame(width: size, height: size).offset(y: 6)
                .shadow(color: .black.opacity(0.46), radius: 9, y: 8)
            // face do medalhão
            Group {
                if locked {
                    shape.fill(RadialGradient(colors: [Color(white: 0.22), Color(white: 0.11)],
                                              center: UnitPoint(x: 0.35, y: 0.30), startRadius: 2, endRadius: size))
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.30, weight: .bold))
                        .foregroundStyle(VitaColors.textTertiary)
                } else {
                    Image(stage.asset)
                        .resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(shape)
                }
            }
            .frame(width: size, height: size)
            // brilho especular no topo (reflexo → peça sólida)
            shape.fill(LinearGradient(colors: [Color.white.opacity(locked ? 0.05 : 0.34), .clear],
                                      startPoint: .top, endPoint: .center))
                .frame(width: size, height: size)
                .allowsHitTesting(false)
            // moldura metálica (rim light do tier)
            shape.strokeBorder(LinearGradient(colors: [tier.bright, tier.dark],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 2)
                .frame(width: size, height: size)
            // selo de concluído
            if state == .completed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                    .foregroundStyle(VitaColors.dataGreen)
                    .background(Circle().fill(Color.white).frame(width: 15, height: 15))
                    .offset(x: size * 0.36, y: -size * 0.36)
            }
        }
        .frame(width: size + 22, height: size + 22)
        // inclinação 3D: a trilha inteira vista num ângulo (não exatamente de
        // cima) — dá camada/profundidade de "jogo". Rafael 2026-06-17.
        .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0),
                          anchor: .center, perspective: 0.55)
    }

    private func chestNode(_ tierIdx: Int) -> some View {
        let reached = userLevel > Self.tiers[min(tierIdx, Self.tiers.count - 1)].maxLevel
        let tier = Self.tiers[min(tierIdx, Self.tiers.count - 1)]
        return Button(action: { router.navigate(to: .achievements) }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(reached ? tier.dark : Color(white: 0.12))
                        .frame(width: 56, height: 46).offset(y: 5)
                        .shadow(color: .black.opacity(0.40), radius: 7, y: 6)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(faceGradient(tier, locked: !reached, radius: 34))
                        .frame(width: 56, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(reached ? 0.18 : 0.06), lineWidth: 1))
                    Image(systemName: "gift.fill").font(.system(size: 22, weight: .bold))
                        .foregroundStyle(reached ? Color.white : VitaColors.textTertiary)
                }
                Text("Baú").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(VitaColors.textTertiary)
            }
        }
        .buttonStyle(TrailPressStyle())
    }

    private var mascot: some View {
        // O Vita REAL — IDÊNTICO ao VitaChat (VitaChatScreen:258) e ao onboarding:
        // OrbMascot, paleta gold, state .awake, grande (olhos + glow dourado, vivo).
        // Na TRILHA tem comportamento próprio: bounceEnabled=false (NÃO fica pulando
        // toda hora — só flutua/pisca/olha, calmo). TODO: saltar de nó em nó ao upar.
        OrbMascot(palette: .vita, state: .awake, size: 76, bounceEnabled: false)
    }

    private func faceGradient(_ tier: Tier, locked: Bool, radius: CGFloat) -> RadialGradient {
        let colors: [Color] = locked
            ? [Color(white: 0.32), Color(white: 0.22), Color(white: 0.14)]
            : [tier.bright, tier.mid, tier.dark]
        return RadialGradient(colors: colors, center: UnitPoint(x: 0.34, y: 0.28), startRadius: 2, endRadius: radius * 1.05)
    }

    // MARK: - Estado + ações

    private func stageState(_ stage: Stage) -> StageState {
        if userLevel > stage.maxLevel { return .completed }
        if userLevel >= stage.minLevel { return .current }
        return .locked
    }

    private func tapStage(_ state: StageState) {
        guard state == .current else { return }
        if flashcardsDue > 0 { openStudy(.flashcardHome()) } else { openStudy(.qbank) }
    }

    private func openStudy(_ route: Route) {
        router.selectedTab = .estudos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { router.navigate(to: route) }
    }

    // MARK: - Modelo (21 etapas / 6 tiers — espelha gamification.ts)

    private enum StageState { case completed, current, locked }

    private enum TrailItem: Identifiable {
        case stage(Stage)
        case chest(Int)
        var id: String {
            switch self {
            case .stage(let s): return "stage-\(s.index)"
            case .chest(let t): return "chest-\(t)"
            }
        }
    }

    private struct Stage: Identifiable {
        let index: Int        // 1…21
        let name: String
        let icon: String      // SF Symbol (fallback / header)
        let asset: String     // ícone oficial 3D (Assets.xcassets/Levels)
        let minLevel: Int
        let maxLevel: Int
        let tierIdx: Int      // 0…5
        var id: Int { index }
    }

    private struct Tier {
        let idx: Int
        let name: String
        let minLevel: Int
        let maxLevel: Int
        let bright: Color
        let mid: Color
        let dark: Color
    }

    private static let tiers: [Tier] = [
        Tier(idx: 0, name: "Calouro", minLevel: 1, maxLevel: 20,
             bright: Color(red: 0.91, green: 0.72, blue: 0.40), mid: Color(red: 0.78, green: 0.57, blue: 0.29), dark: Color(red: 0.45, green: 0.30, blue: 0.13)),
        Tier(idx: 1, name: "Acadêmico", minLevel: 21, maxLevel: 40,
             bright: Color(red: 1.0, green: 0.78, blue: 0.47), mid: Color(red: 0.78, green: 0.63, blue: 0.31), dark: Color(red: 0.55, green: 0.39, blue: 0.20)),
        Tier(idx: 2, name: "Residente", minLevel: 41, maxLevel: 60,
             bright: Color(red: 1.0, green: 0.82, blue: 0.48), mid: Color(red: 0.84, green: 0.64, blue: 0.24), dark: Color(red: 0.52, green: 0.37, blue: 0.13)),
        Tier(idx: 3, name: "Especialista", minLevel: 61, maxLevel: 80,
             bright: Color(red: 1.0, green: 0.86, blue: 0.63), mid: Color(red: 0.83, green: 0.66, blue: 0.31), dark: Color(red: 0.47, green: 0.33, blue: 0.12)),
        Tier(idx: 4, name: "Lenda", minLevel: 81, maxLevel: 99,
             bright: Color(red: 1.0, green: 0.94, blue: 0.80), mid: Color(red: 0.91, green: 0.81, blue: 0.53), dark: Color(red: 0.62, green: 0.50, blue: 0.24)),
        Tier(idx: 5, name: "GOD", minLevel: 100, maxLevel: 100,
             bright: Color(red: 1.0, green: 1.0, blue: 0.94), mid: Color(red: 0.90, green: 0.86, blue: 0.62), dark: Color(red: 0.70, green: 0.62, blue: 0.36)),
    ]

    private static let stages: [Stage] = [
        Stage(index: 1,  name: "Termômetro",   icon: "thermometer.medium", asset: "level-01-thermometer",   minLevel: 1,   maxLevel: 5,   tierIdx: 0),
        Stage(index: 2,  name: "Seringa",      icon: "syringe.fill",       asset: "level-02-syringe",       minLevel: 6,   maxLevel: 10,  tierIdx: 0),
        Stage(index: 3,  name: "Bisturi",      icon: "cross.case.fill",    asset: "level-03-scalpel",       minLevel: 11,  maxLevel: 15,  tierIdx: 0),
        Stage(index: 4,  name: "Estetoscópio", icon: "stethoscope",        asset: "level-04-stethoscope",   minLevel: 16,  maxLevel: 20,  tierIdx: 0),
        Stage(index: 5,  name: "Máscara",      icon: "facemask.fill",      asset: "level-05-mask",          minLevel: 21,  maxLevel: 25,  tierIdx: 1),
        Stage(index: 6,  name: "Microscópio",  icon: "microbe.fill",       asset: "level-06-microscope",    minLevel: 26,  maxLevel: 30,  tierIdx: 1),
        Stage(index: 7,  name: "Martelo",      icon: "hammer.fill",        asset: "level-07-reflex-hammer", minLevel: 31,  maxLevel: 35,  tierIdx: 1),
        Stage(index: 8,  name: "Desfibrilador",icon: "bolt.heart.fill",    asset: "level-08-defibrillator", minLevel: 36,  maxLevel: 40,  tierIdx: 1),
        Stage(index: 9,  name: "DNA",          icon: "waveform.path.ecg",  asset: "level-09-dna",           minLevel: 41,  maxLevel: 45,  tierIdx: 2),
        Stage(index: 10, name: "Comprimido",   icon: "pills.fill",         asset: "level-10-pill",          minLevel: 46,  maxLevel: 50,  tierIdx: 2),
        Stage(index: 11, name: "Coração",      icon: "heart.fill",         asset: "level-11-heart",         minLevel: 51,  maxLevel: 55,  tierIdx: 2),
        Stage(index: 12, name: "Jaleco",       icon: "cross.case.fill",    asset: "level-12-labcoat",       minLevel: 56,  maxLevel: 60,  tierIdx: 2),
        Stage(index: 13, name: "Robô Da Vinci",icon: "gearshape.2.fill",   asset: "level-13-davinci-robot", minLevel: 61,  maxLevel: 65,  tierIdx: 3),
        Stage(index: 14, name: "Cérebro",      icon: "brain.head.profile", asset: "level-14-brain",         minLevel: 66,  maxLevel: 70,  tierIdx: 3),
        Stage(index: 15, name: "Crânio",       icon: "staroflife.fill",    asset: "level-15-skull",         minLevel: 71,  maxLevel: 75,  tierIdx: 3),
        Stage(index: 16, name: "Escudo",       icon: "shield.fill",        asset: "level-16-shield",        minLevel: 76,  maxLevel: 80,  tierIdx: 3),
        Stage(index: 17, name: "Diploma",      icon: "graduationcap.fill", asset: "level-17-diploma",       minLevel: 81,  maxLevel: 85,  tierIdx: 4),
        Stage(index: 18, name: "Caduceu",      icon: "cross.fill",         asset: "level-18-caduceus-staff",minLevel: 86,  maxLevel: 90,  tierIdx: 4),
        Stage(index: 19, name: "Coroa",        icon: "crown.fill",         asset: "level-19-crown",         minLevel: 91,  maxLevel: 95,  tierIdx: 4),
        Stage(index: 20, name: "Vita",         icon: "rosette",            asset: "level-20-vita-caduceu",  minLevel: 96,  maxLevel: 99,  tierIdx: 4),
        Stage(index: 21, name: "GOD",          icon: "crown.fill",         asset: "level-21-vita-caduceu",  minLevel: 100, maxLevel: 100, tierIdx: 5),
    ]

    private var trailItems: [TrailItem] {
        var out: [TrailItem] = []
        for s in Self.stages {
            out.append(.stage(s))
            if s.index % 4 == 0 && s.index < 21 {
                out.append(.chest(s.index / 4))
            }
        }
        return out
    }
}

// MARK: - Press style (afunda no toque)

private struct TrailPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
