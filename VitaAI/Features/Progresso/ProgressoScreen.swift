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
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    private var currentStage: Stage {
        Self.stages.first(where: { userLevel >= $0.minLevel && userLevel <= $0.maxLevel }) ?? Self.stages[0]
    }

    // Geometria da trilha — cada nó ocupa um "slot" de altura fixa (rowStride) e
    // serpenteia em x por sin(i*freq)*amp. A estrada usa a MESMA fórmula → alinha.
    private static let rowStride: CGFloat = 116
    private static let rowAmp: CGFloat = 60
    private static let rowFreq: Double = 0.9

    /// Stops travados por seção (cada tier ocupa 1/n da altura, cor sólida) — a cor
    /// muda EXATAMENTE na fronteira de capítulo (estrada + fundo), nunca antes.
    private static func sectionStops(_ key: (Tier) -> Color) -> Gradient {
        let n = tiers.count
        var stops: [Gradient.Stop] = []
        for (i, t) in tiers.enumerated() {
            stops.append(.init(color: key(t), location: Double(i) / Double(n)))
            stops.append(.init(color: key(t), location: Double(i + 1) / Double(n)))
        }
        return Gradient(stops: stops)
    }

    // MARK: - Caminho de TERRA sobre a grama (ref Duolingo, Rafael 2026-06-18).
    // Aterra os nós no mundo (não flutuam). Terra clara em cima + borda escura +
    // sombra na grama + pegadas tracejadas. Sem cor de seção (a terra é neutra).
    private var dirtPath: some View {
        let road = TrailRoad(count: trailItems.count, stride: Self.rowStride,
                             amp: Self.rowAmp, freq: Self.rowFreq)
        return ZStack {
            // sombra do caminho na grama
            road.stroke(Color.black.opacity(0.14),
                        style: StrokeStyle(lineWidth: 36, lineCap: .round, lineJoin: .round))
                .offset(y: 3).blur(radius: 3)
            // terra — borda escura (espessura)
            road.stroke(Color(red: 0.52, green: 0.39, blue: 0.24),
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
            // terra — topo claro (a superfície batida)
            road.stroke(Color(red: 0.80, green: 0.66, blue: 0.45),
                        style: StrokeStyle(lineWidth: 27, lineCap: .round, lineJoin: .round))
            // pegadas / centro tracejado
            road.stroke(Color.white.opacity(0.30),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 16]))
        }
    }

    // MARK: - Mundo de GRAMA (fundo) — ref Duolingo. Base verde + textura de folhas
    // (Canvas) + tinta sutil da cor do capítulo (cada "mundo" muda de cor a cada 20
    // níveis). Preenche a tela: sem céu, sem estrelado, sem glassmorphism.
    private var grassField: some View {
        let h = CGFloat(trailItems.count) * Self.rowStride + 200
        return ZStack {
            GrassField(height: h)
            LinearGradient(gradient: Self.sectionStops { $0.mid.opacity(0.18) },
                           startPoint: .top, endPoint: .bottom)
                .blendMode(.overlay)
        }
        .frame(height: h)
        .allowsHitTesting(false)
    }

    // Verde base do mundo — preenche a tela inteira atrás de tudo (mata o dark/
    // estrelado do shell). A grama detalhada (folhas) scrolla por cima em grassField.
    private static let grassBaseTop = Color(red: 0.52, green: 0.78, blue: 0.40)
    private static let grassBaseBot = Color(red: 0.34, green: 0.62, blue: 0.28)
    private var grassBase: some View {
        LinearGradient(colors: [Self.grassBaseTop, Self.grassBaseBot],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Card de seção (flat sólido, ref Duolingo 077) — no INÍCIO de cada
    // seção, full-width, com "lábio" chunky embaixo. Marca a virada de capítulo.
    private var sectionCards: some View {
        let h = CGFloat(trailItems.count) * Self.rowStride + 40
        return ZStack(alignment: .top) {
            ForEach(0..<Self.tiers.count, id: \.self) { k in
                sectionCard(Self.tiers[k], number: k + 1)
                    .offset(y: k == 0 ? 4 : CGFloat(k * 4) * Self.rowStride - 30)
            }
        }
        .frame(height: h, alignment: .top)
        .allowsHitTesting(false)
    }

    private func sectionCard(_ tier: Tier, number: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SEÇÃO \(number)")
                    .font(.system(size: 11, weight: .heavy)).kerning(1.5)
                    .foregroundStyle(.white.opacity(0.82))
                Text(tier.name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "list.bullet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tier.dark).offset(y: 4)
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tier.mid)
            }
            .shadow(color: .black.opacity(0.20), radius: 6, y: 4)
        )
        .padding(.horizontal, 34)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            grassBase.ignoresSafeArea()
            VStack(spacing: 0) {
            topTools
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        grassField
                        dirtPath
                        sectionCards
                        LazyVStack(spacing: 0) {
                            ForEach(Array(trailItems.enumerated()), id: \.element.id) { idx, item in
                                trailRow(item, rowIndex: idx)
                            }
                        }
                    }
                    .frame(height: CGFloat(trailItems.count) * Self.rowStride + 40)
                    .padding(.top, 78)
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

    // MARK: - Ferramentas de estudo — FIXAS no topo (Rafael 2026-06-18). O centro
    // fica livre só pro mundo (estilo Duolingo). 4 botões chunky flat em linha.
    private var topTools: some View {
        HStack(spacing: 10) {
            topTool("Flashcards", icon: "rectangle.on.rectangle.angled",
                    mid: VitaColors.toolFlashcards, dark: Color(red: 0.29, green: 0.23, blue: 0.63)) { openStudy(.flashcardHome()) }
            topTool("Questões", icon: "checklist",
                    mid: VitaColors.accent, dark: VitaColors.accentDark) { openStudy(.qbank) }
            topTool("Simulados", icon: "doc.text.magnifyingglass",
                    mid: VitaColors.toolSimulados, dark: Color(red: 0.10, green: 0.37, blue: 0.65)) { openStudy(.simuladoHome) }
            topTool("Transcrição", icon: "waveform",
                    mid: VitaColors.toolTranscricao, dark: Color(red: 0.08, green: 0.50, blue: 0.47)) { openStudy(.transcricao) }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4).padding(.bottom, 10)
    }

    private func topTool(_ title: String, icon: String, mid: Color, dark: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(dark).offset(y: 4)
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(mid)
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)))
                    Image(systemName: icon).font(.system(size: 21, weight: .bold)).foregroundStyle(.white)
                }
                .frame(height: 50)
                Text(title).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.16, green: 0.24, blue: 0.10))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TrailPressStyle())
    }

    // MARK: - Trilha

    private func trailRow(_ item: TrailItem, rowIndex: Int) -> some View {
        let dx = CGFloat(sin(Double(rowIndex) * Self.rowFreq)) * Self.rowAmp
        return Group {
            switch item {
            case .stage(let s): stageNode(s)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.rowStride)   // slot fixo → centro alinha com a estrada
        .offset(x: dx)
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

                Text(state == .locked ? "Nível \(stage.maxLevel)" : stage.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state == .locked ? VitaColors.textTertiary : VitaColors.textSecondary)
                    .lineLimit(1)
            }

            if state == .current {
                // Vita AO LADO do nó atual (ref Duolingo 077), não em cima.
                // Halo claro atrás pra ele "saltar" na grama (senão some no fundo).
                mascot
                    .background(Circle().fill(.white.opacity(0.5)).frame(width: 66, height: 66).blur(radius: 13))
                    .offset(x: -60, y: 8)
            }
        }
    }

    // Nó CHUNKY FLAT (ref Duolingo 077): círculo cor da seção + "lábio" mais escuro
    // embaixo (profundidade de botão apertável) + sombra na grama + glifo branco.
    // Sem glossy, sem metal, sem tilt — chapado e alegre como o Duolingo.
    private func coin(stage: Stage, tier: Tier, state: StageState) -> some View {
        let locked = state == .locked
        let size: CGFloat = state == .current ? 78 : 66
        let face: Color = locked ? Color(white: 0.75) : tier.mid
        let lip:  Color = locked ? Color(white: 0.57) : tier.dark
        return ZStack {
            // anel pulsante (nível atual) — convite a tocar
            if state == .current {
                Circle().stroke(tier.mid.opacity(0.40), lineWidth: 4)
                    .frame(width: size + 20, height: size + 20)
                    .scaleEffect(pulse ? 1.08 : 0.95)
            }
            // sombra do botão na grama (aterra — não flutua)
            Ellipse().fill(Color.black.opacity(0.18))
                .frame(width: size * 0.82, height: size * 0.26)
                .offset(y: size * 0.52).blur(radius: 2.5)
            // lábio (base mais escura deslocada = profundidade do botão)
            Circle().fill(lip).frame(width: size, height: size).offset(y: 7)
            // face (cor chapada + leve clareada no topo, sem brilho exagerado)
            Circle().fill(face).frame(width: size, height: size)
                .overlay(
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.20), .clear],
                                                 startPoint: .top, endPoint: .center))
                )
            // glifo branco flat (ref Duolingo)
            Image(systemName: locked ? "lock.fill" : stage.icon)
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(locked ? Color.white.opacity(0.85) : .white)
                .shadow(color: lip.opacity(0.5), radius: 1, y: 1)
            // selo de concluído (check branco em disco escuro)
            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tier.dark)
                    .padding(5)
                    .background(Circle().fill(.white))
                    .offset(x: size * 0.34, y: -size * 0.34)
            }
        }
        .frame(width: size + 22, height: size + 24)
    }

    private var mascot: some View {
        // O Vita REAL — IDÊNTICO ao VitaChat (VitaChatScreen:258) e ao onboarding:
        // OrbMascot, paleta gold, state .awake, grande (olhos + glow dourado, vivo).
        // Na TRILHA tem comportamento próprio: bounceEnabled=false (NÃO fica pulando
        // toda hora — só flutua/pisca/olha, calmo). TODO: saltar de nó em nó ao upar.
        OrbMascot(palette: .vita, state: .awake, size: 58, bounceEnabled: false)
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
        var id: String {
            switch self {
            case .stage(let s): return "stage-\(s.index)"
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

    // 5 SEÇÕES (20 níveis cada) com cores distintas — o mundo muda de cor conforme
    // sobe. Cada seção vira uma "etapa da carreira" médica. (Rafael 2026-06-17)
    private static let tiers: [Tier] = [
        Tier(idx: 0, name: "Calouro", minLevel: 1, maxLevel: 20,
             bright: Color(red: 0.95, green: 0.74, blue: 0.42), mid: Color(red: 0.80, green: 0.58, blue: 0.30), dark: Color(red: 0.42, green: 0.28, blue: 0.12)),
        Tier(idx: 1, name: "Acadêmico", minLevel: 21, maxLevel: 40,
             bright: Color(red: 0.50, green: 0.88, blue: 0.66), mid: Color(red: 0.20, green: 0.64, blue: 0.44), dark: Color(red: 0.06, green: 0.29, blue: 0.20)),
        Tier(idx: 2, name: "Residente", minLevel: 41, maxLevel: 60,
             bright: Color(red: 0.52, green: 0.76, blue: 1.0), mid: Color(red: 0.24, green: 0.52, blue: 0.88), dark: Color(red: 0.07, green: 0.23, blue: 0.50)),
        Tier(idx: 3, name: "Especialista", minLevel: 61, maxLevel: 80,
             bright: Color(red: 0.80, green: 0.64, blue: 1.0), mid: Color(red: 0.56, green: 0.40, blue: 0.88), dark: Color(red: 0.29, green: 0.17, blue: 0.56)),
        Tier(idx: 4, name: "Lenda", minLevel: 81, maxLevel: 100,
             bright: Color(red: 1.0, green: 0.80, blue: 0.52), mid: Color(red: 0.87, green: 0.40, blue: 0.38), dark: Color(red: 0.45, green: 0.12, blue: 0.16)),
    ]

    private static let stages: [Stage] = [
        Stage(index: 1,  name: "Termômetro",   icon: "thermometer.medium", asset: "level-01-thermometer",   minLevel: 1,  maxLevel: 5,   tierIdx: 0),
        Stage(index: 2,  name: "Seringa",      icon: "syringe.fill",       asset: "level-02-syringe",       minLevel: 6,  maxLevel: 10,  tierIdx: 0),
        Stage(index: 3,  name: "Bisturi",      icon: "cross.case.fill",    asset: "level-03-scalpel",       minLevel: 11, maxLevel: 15,  tierIdx: 0),
        Stage(index: 4,  name: "Estetoscópio", icon: "stethoscope",        asset: "level-04-stethoscope",   minLevel: 16, maxLevel: 20,  tierIdx: 0),
        Stage(index: 5,  name: "Máscara",      icon: "facemask.fill",      asset: "level-05-mask",          minLevel: 21, maxLevel: 25,  tierIdx: 1),
        Stage(index: 6,  name: "Microscópio",  icon: "microbe.fill",       asset: "level-06-microscope",    minLevel: 26, maxLevel: 30,  tierIdx: 1),
        Stage(index: 7,  name: "Martelo",      icon: "hammer.fill",        asset: "level-07-reflex-hammer", minLevel: 31, maxLevel: 35,  tierIdx: 1),
        Stage(index: 8,  name: "Desfibrilador",icon: "bolt.heart.fill",    asset: "level-08-defibrillator", minLevel: 36, maxLevel: 40,  tierIdx: 1),
        Stage(index: 9,  name: "DNA",          icon: "waveform.path.ecg",  asset: "level-09-dna",           minLevel: 41, maxLevel: 45,  tierIdx: 2),
        Stage(index: 10, name: "Comprimido",   icon: "pills.fill",         asset: "level-10-pill",          minLevel: 46, maxLevel: 50,  tierIdx: 2),
        Stage(index: 11, name: "Coração",      icon: "heart.fill",         asset: "level-11-heart",         minLevel: 51, maxLevel: 55,  tierIdx: 2),
        Stage(index: 12, name: "Jaleco",       icon: "cross.case.fill",    asset: "level-12-labcoat",       minLevel: 56, maxLevel: 60,  tierIdx: 2),
        Stage(index: 13, name: "Robô Da Vinci",icon: "gearshape.2.fill",   asset: "level-13-davinci-robot", minLevel: 61, maxLevel: 65,  tierIdx: 3),
        Stage(index: 14, name: "Cérebro",      icon: "brain.head.profile", asset: "level-14-brain",         minLevel: 66, maxLevel: 70,  tierIdx: 3),
        Stage(index: 15, name: "Crânio",       icon: "staroflife.fill",    asset: "level-15-skull",         minLevel: 71, maxLevel: 75,  tierIdx: 3),
        Stage(index: 16, name: "Escudo",       icon: "shield.fill",        asset: "level-16-shield",        minLevel: 76, maxLevel: 80,  tierIdx: 3),
        Stage(index: 17, name: "Diploma",      icon: "graduationcap.fill", asset: "level-17-diploma",       minLevel: 81, maxLevel: 85,  tierIdx: 4),
        Stage(index: 18, name: "Caduceu",      icon: "cross.fill",         asset: "level-18-caduceus-staff",minLevel: 86, maxLevel: 90,  tierIdx: 4),
        Stage(index: 19, name: "Coroa",        icon: "crown.fill",         asset: "level-19-crown",         minLevel: 91, maxLevel: 95,  tierIdx: 4),
        Stage(index: 20, name: "Vita",         icon: "rosette",            asset: "level-20-vita-caduceu",  minLevel: 96, maxLevel: 100, tierIdx: 4),
    ]

    private var trailItems: [TrailItem] {
        Self.stages.map { TrailItem.stage($0) }
    }
}

// MARK: - Campo de grama (Canvas) — base verde + folhas determinísticas.
// Hybrid (Rafael 2026-06-18): vetor agora; trocável por textura crafted depois.
private struct GrassField: View {
    let height: CGFloat
    var body: some View {
        Canvas { ctx, size in
            func drawTree(at point: CGPoint, scale: CGFloat, side: CGFloat) {
                let trunk = CGRect(x: point.x - 4 * scale, y: point.y - 4 * scale,
                                   width: 8 * scale, height: 24 * scale)
                let shadow = CGRect(x: point.x - 23 * scale, y: point.y + 15 * scale,
                                    width: 46 * scale, height: 12 * scale)
                let deepLeaf = Color(red: 0.12, green: 0.43, blue: 0.19)
                let midLeaf = Color(red: 0.18, green: 0.58, blue: 0.25)
                let lightLeaf = Color(red: 0.34, green: 0.72, blue: 0.34)

                ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.16)))
                ctx.fill(Path(roundedRect: trunk, cornerRadius: 3 * scale),
                         with: .linearGradient(
                            Gradient(colors: [Color(red: 0.54, green: 0.32, blue: 0.16),
                                              Color(red: 0.34, green: 0.18, blue: 0.08)]),
                            startPoint: CGPoint(x: trunk.midX, y: trunk.minY),
                            endPoint: CGPoint(x: trunk.midX, y: trunk.maxY))
                )

                let crowns: [(CGFloat, CGFloat, CGFloat, Color)] = [
                    (-12, -10, 19, deepLeaf),
                    (  8, -13, 21, midLeaf),
                    ( -1, -27, 23, midLeaf),
                    ( 13, -29, 14, lightLeaf.opacity(0.92)),
                    (-13, -29, 13, lightLeaf.opacity(0.76)),
                ]
                for crown in crowns {
                    let rect = CGRect(
                        x: point.x + (crown.0 * side - crown.2) * scale,
                        y: point.y + (crown.1 - crown.2) * scale,
                        width: crown.2 * 2 * scale,
                        height: crown.2 * 2 * scale
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(crown.3))
                }
            }

            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.52, green: 0.78, blue: 0.40),
                                      Color(red: 0.34, green: 0.62, blue: 0.28)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
            let step: CGFloat = 26
            let cols = Int(size.width / step) + 1
            let rows = Int(size.height / step) + 1
            let g1 = Color(red: 0.29, green: 0.55, blue: 0.23)
            let g2 = Color(red: 0.45, green: 0.73, blue: 0.34)
            let g3 = Color(red: 0.64, green: 0.86, blue: 0.46)

            let treeRows = max(8, Int(size.height / 170))
            for i in 0..<treeRows {
                let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
                let seed = CGFloat((i * 371) % 997) / 997
                let x = side < 0
                    ? 28 + seed * 38
                    : size.width - 28 - seed * 42
                let y = 104 + CGFloat(i) * 156 + CGFloat((i * 53) % 41)
                guard y < size.height - 20 else { continue }
                drawTree(at: CGPoint(x: x, y: y),
                         scale: 0.72 + CGFloat((i * 29) % 31) / 100,
                         side: side)
            }

            for r in 0..<rows {
                for c in 0..<cols {
                    let seed = Double((r * 928_371 + c * 1_299_721) % 9973) / 9973
                    let s2 = Double((r * 113 + c * 977) % 997) / 997
                    let cx = CGFloat(c) * step + CGFloat(seed) * step
                    let cy = CGFloat(r) * step + CGFloat(s2) * step
                    // tufo de grama: 3 folhas quase VERTICAIS (não diagonal = não vira chuva)
                    for k in -1...1 {
                        let bx = cx + CGFloat(k) * 3.4
                        let bh = 10 + CGFloat(seed) * 7 - CGFloat(abs(k)) * 2.5
                        let lean = CGFloat(k) * 2.2 + (CGFloat(s2) - 0.5) * 1.8
                        var blade = Path()
                        blade.move(to: CGPoint(x: bx, y: cy))
                        blade.addQuadCurve(to: CGPoint(x: bx + lean, y: cy - bh),
                                           control: CGPoint(x: bx + lean * 0.5, y: cy - bh * 0.6))
                        let col = seed > 0.66 ? g3 : (seed > 0.33 ? g2 : g1)
                        ctx.stroke(blade, with: .color(col.opacity(0.62)), lineWidth: 2.0)
                    }
                    // florzinha ocasional (vida no campo)
                    if s2 > 0.92 {
                        let fc: Color = seed > 0.5 ? Color(red: 1.0, green: 0.85, blue: 0.32)
                                                   : Color(red: 1.0, green: 0.62, blue: 0.76)
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)),
                                 with: .color(fc.opacity(0.92)))
                    }
                }
            }
        }
        .frame(height: height)
        .drawingGroup()
    }
}

// MARK: - Estrada da trilha — curva sinuosa suave pelos centros dos nós.
// Usa a MESMA fórmula de posição dos nós (sin(i*freq)*amp), então a estrada
// passa exatamente por baixo de cada medalhão.
private struct TrailRoad: Shape {
    let count: Int
    let stride: CGFloat
    let amp: CGFloat
    let freq: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard count > 0 else { return p }
        func pt(_ i: Int) -> CGPoint {
            CGPoint(x: rect.midX + CGFloat(sin(Double(i) * freq)) * amp,
                    y: stride * CGFloat(i) + stride / 2)
        }
        p.move(to: pt(0))
        for i in 1..<count {
            let prev = pt(i - 1)
            let cur = pt(i)
            let midY = (prev.y + cur.y) / 2
            p.addCurve(to: cur,
                       control1: CGPoint(x: prev.x, y: midY),
                       control2: CGPoint(x: cur.x, y: midY))
        }
        return p
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
