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

struct VitaHomeGrassBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                TrailWorld.fieldTop,
                TrailWorld.fieldBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var pulse = false
    @State private var hop = false
    @State private var mascotLevel: Int = 1
    @State private var jumpArc: CGFloat = 0
    @State private var jumpStretch: CGFloat = 1
    @State private var trailCelebration: GamificationEventManager.TrailCelebration?
    @State private var showTrailCelebration = false
    @State private var trailCelebrationInFlight = false
    @State private var critters: [TrailCritter] = []
    @Namespace private var mascotTrail

    private var vmProg: ProgressoViewModel { container.progressoViewModel }
    private var dash: DashboardViewModel { container.dashboardViewModel }
    private var gamify: GamificationEventManager { container.gamificationEvents }

    private var userLevel: Int { max(0, gamify.currentLevel) }
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    private var currentStage: Stage {
        if let stage = Self.stages.first(where: { contains(userLevel, in: $0) }) {
            return stage
        }
        return userLevel > (Self.stages.last?.maxLevel ?? 0) ? Self.stages[Self.stages.count - 1] : Self.stages[0]
    }

    // Geometria da trilha — cada nó ocupa um "slot" de altura fixa (rowStride) e
    // serpenteia em x por sin(i*freq)*amp. A estrada usa a MESMA fórmula → alinha.
    private static let rowStride: CGFloat = 136
    private static let rowAmp: CGFloat = 60
    private static let rowFreq: Double = 0.9
    // The home chrome floats over the map. Keep the first playable node below it,
    // otherwise the scroll is technically at the top while level 1 is hidden.
    private static let trailTopInset: CGFloat = 178
    private static let trailBottomInset: CGFloat = 360

    private var trailContentHeight: CGFloat {
        Self.trailTopInset + CGFloat(trailItems.count) * Self.rowStride + Self.trailBottomInset
    }

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
                .offset(y: 4)
            // terra — borda escura (espessura)
            road.stroke(TrailWorld.roadEdge,
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
            // terra — topo claro (a superfície batida)
            road.stroke(TrailWorld.roadSurface,
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
        let h = Self.trailTopInset + CGFloat(trailItems.count) * Self.rowStride + 200
        return ZStack {
            // Vento: fase contínua anima o lean das folhas e o sway das copas
            // (12fps — sutil, o campo respira sem virar videogame).
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
                GrassField(height: h, phase: tl.date.timeIntervalSinceReferenceDate)
            }
            LinearGradient(gradient: Self.sectionStops { $0.mid.opacity(0.05) },
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(gradient: Self.sectionStops { $0.dark.opacity(0.25) },
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(height: h)
        .allowsHitTesting(false)
    }

    // Verde base do mundo — preenche a tela inteira atrás de tudo (mata o dark/
    // estrelado do shell). A grama detalhada (folhas) scrolla por cima em grassField.
    private var grassBase: some View {
        VitaHomeGrassBackdrop()
    }



    private var worldLandmarks: some View {
        let h = Self.trailTopInset + CGFloat(trailItems.count) * Self.rowStride + 140
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Self.landmarks) { landmark in
                    MedicalWorldLandmark(kind: landmark.kind)
                        .scaleEffect(landmark.scale)
                        .opacity(landmark.opacity)
                        .position(
                            x: landmark.side == .leading
                                ? geo.size.width * 0.15
                                : geo.size.width * 0.85,
                            y: Self.trailTopInset + (landmark.row * Self.rowStride)
                        )
                }
            }
        }
        .frame(height: h)
        .allowsHitTesting(false)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            grassBase.ignoresSafeArea()
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        trailMapContent
                            .frame(width: geo.size.width, alignment: .top)
                            .onAppear {
                                UserDefaults.standard.removeObject(forKey: "vita.trail.lastSeenLevel")
                                mascotLevel = userLevel
                            }
                            .task {
                                await vmProg.loadIfNeeded()
                                await dash.loadDashboard()
                                ScreenLoadContext.finish(for: "Progresso")
                                if let stats = try? await container.api.getGamificationStats() {
                                    gamify.updateFromStats(stats)
                                }
                                if !trailCelebrationInFlight {
                                    mascotLevel = userLevel
                                }
                            }
                            .onChange(of: userLevel) { _, newLevel in
                                // Nunca reposiciona o scroll enquanto o usuario
                                // explora o mapa. O nivel muda o estado visual
                                // da trilha; celebracoes animam o mascote sem
                                // sequestrar o gesto manual.
                                hopMascot(to: newLevel)
                            }
                    }
                    .scrollContentBackground(.hidden)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            if showTrailCelebration, let trailCelebration {
                TrailXpCelebrationPill(event: trailCelebration)
                    .padding(.top, 104)
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .onAppear {
            if !pulse {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
            if !hop {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { hop = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                triggerPendingTrailCelebration()
            }
        }
        .onChange(of: router.currentPath.count) { _, count in
            if count == 0 && router.selectedTab == .home {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    triggerPendingTrailCelebration()
                }
            }
        }
        .trackScreen("Progresso")
    }

    private var trailMapContent: some View {
        ZStack(alignment: .top) {
            grassField
            worldLandmarks
            dirtPath
                .offset(y: Self.trailTopInset)
            critterLayer
            sectionWalls
                .offset(y: Self.trailTopInset)
            VStack(spacing: 0) {
                ForEach(Array(trailItems.enumerated()), id: \.element.id) { idx, item in
                    trailRow(item, rowIndex: idx)
                }
            }
            .padding(.top, Self.trailTopInset)
        }
        .frame(height: trailContentHeight, alignment: .top)
        .task { await critterSpawnLoop() }
    }

    // MARK: - Muralha de seção (Rafael 2026-07-03: transição FÍSICA entre mundos)
    // Sebe escura atravessa o mapa na fronteira de cada seção; a estrada passa
    // por um vão entre dois pilares de pedra com lampiões acesos. O banner de
    // joia da seção continua por cima (é a placa do portal).
    private var sectionWalls: some View {
        let h = CGFloat(trailItems.count) * Self.rowStride + 40
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<Self.tiers.count, id: \.self) { k in
                    let i = Double(k * 4) - 0.5
                    let archX = geo.size.width / 2 + CGFloat(sin(i * Self.rowFreq)) * Self.rowAmp
                    // Portão aberto = já alcançou este mundo. Seção 1 (minLevel 0) sempre aberta.
                    let unlocked = gatesForceOpen || userLevel >= Self.tiers[k].minLevel
                    TrailSectionWall(archX: archX, tier: Self.tiers[k], number: k + 1, isOpen: unlocked)
                        .frame(width: geo.size.width, height: 112)
                        .position(x: geo.size.width / 2,
                                  // ponto médio entre o último nó da seção anterior e o
                                  // primeiro desta (nós são centralizados +rowStride/2 no slot).
                                  y: CGFloat(k * 4) * Self.rowStride)
                }
            }
        }
        .frame(height: h, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Bichinhos (Rafael 2026-07-03: vida aleatória no mapa + easter egg)
    // Spawner de verdade aleatório: intervalo, espécie, altura, direção, escala e
    // velocidade sorteados — nunca parece script. Capivara dourada = raridade.
    // QA: --vita-critter-storm spawna rapido e no topo (provar sem esperar sorte)
    private var critterStorm: Bool {
        ProcessInfo.processInfo.arguments.contains("--vita-critter-storm")
    }

    // QA: --vita-gates-open força todos os portões abertos (provar a animação sem
    // precisar de um user de nível alto).
    private var gatesForceOpen: Bool {
        ProcessInfo.processInfo.arguments.contains("--vita-gates-open")
    }

    private func critterSpawnLoop() async {
        while !Task.isCancelled {
            let wait = critterStorm ? 6 : Double.random(in: 180...420)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled, critters.isEmpty else { continue }
            // So capivara no chao — o trio de vagalumes VOAVA e incomodava
            // (Rafael 2026-07-03: "nao aguento mais esses bixo voando").
            let kind: TrailCritter.Kind = .capivara
            // y = SEMPRE no vão ENTRE fileiras de nós (nunca por cima de moeda,
            // banner ou muralha — muralhas vivem nos vãos múltiplos de 4).
            // 65% nos primeiros vãos (banda onde o mapa descansa); resto em
            // qualquer vão — uniforme em 3300pt era invisível na prática.
            let gapsTop = [1, 2, 3]
            let gapsAll = (1..<trailItems.count).filter { !$0.isMultiple(of: 4) }
            let gap = (critterStorm || Double.random(in: 0..<1) < 0.65)
                ? gapsTop.randomElement()!
                : gapsAll.randomElement()!
            let y = Self.trailTopInset + CGFloat(gap) * Self.rowStride
                + CGFloat.random(in: -14...14)
            let critter = TrailCritter(
                kind: kind,
                golden: kind == .capivara && Double.random(in: 0..<1) < 0.05,
                y: y,
                leftToRight: Bool.random(),
                duration: Double.random(in: 100...150),
                scale: CGFloat.random(in: 0.62...0.85)
            )
            critters.append(critter)
            if critterStorm { print("[critter] spawn \(critter.kind) y=\(Int(critter.y)) golden=\(critter.golden) n=\(critters.count)") }
            let id = critter.id
            DispatchQueue.main.asyncAfter(deadline: .now() + critter.duration + 1.5) {
                critters.removeAll { $0.id == id }
            }
        }
    }

    private var critterLayer: some View {
        GeometryReader { geo in
            ForEach(critters) { critter in
                TrailCritterView(critter: critter, width: geo.size.width)
            }
        }
        .frame(height: trailContentHeight)
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
            VStack(spacing: 4) {
                Button(action: { tapStage(state) }) {
                    coin(stage: stage, tier: tier, state: state)
                }
                .buttonStyle(TrailPressStyle())
                .disabled(state != .current)

                stageCaption(stage, state: state)
            }

            if contains(mascotLevel, in: stage) {
                mascot
                    .matchedGeometryEffect(id: "vita-trail-mascot", in: mascotTrail)
                    .background(Circle().fill(.white.opacity(0.24)).frame(width: 64, height: 64))
                    .scaleEffect(x: 2 - jumpStretch, y: jumpStretch, anchor: .bottom)
                    .offset(y: -64 + (hop ? -5 : 0) + jumpArc)
                    .zIndex(4)
            }
        }
        .zIndex(state == .current ? 3 : 1)
        .animation(.spring(response: 0.72, dampingFraction: 0.78), value: mascotLevel)
    }

    private func stageCaption(_ stage: Stage, state: StageState) -> some View {
        VStack(spacing: 0) {
            Text(levelCaption(for: stage, state: state))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(state == .locked ? Color.white.opacity(0.62) : Color.white.opacity(0.92))
                .lineLimit(1)
            Text(stage.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(state == .locked ? Color.white.opacity(0.44) : Color.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 118)
    }

    private func levelCaption(for stage: Stage, state: StageState) -> String {
        if state == .current {
            return "Nível \(userLevel)"
        }
        return stage.minLevel == stage.maxLevel
            ? "Nível \(stage.minLevel)"
            : "Níveis \(stage.minLevel)-\(stage.maxLevel)"
    }

    // Nó CHUNKY FLAT (ref Duolingo 077): círculo cor da seção + "lábio" mais escuro
    // embaixo (profundidade de botão apertável) + sombra na grama + glifo branco.
    // Sem glossy, sem metal, sem tilt — chapado e alegre como o Duolingo.
    private func coin(stage: Stage, tier: Tier, state: StageState) -> some View {
        let locked = state == .locked
        let size: CGFloat = state == .current ? 78 : 66
        let face: Color = locked ? Color(white: 0.62) : tier.mid
        let lip:  Color = locked ? Color(white: 0.45) : tier.dark
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
                .offset(y: size * 0.52)
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

    /// Pula o bonequinho de no em no: agacha+estica na decolagem, desliza pelo arco
    /// (matchedGeometry move quando mascotLevel troca de no) e aterrissa quicando.
    private func hopMascot(to newLevel: Int) {
        guard newLevel != mascotLevel else { return }
        PixioHaptics.tap()
        withAnimation(.easeOut(duration: 0.22)) {
            jumpArc = -46
            jumpStretch = 1.14
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            mascotLevel = newLevel
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) {
                jumpArc = 0
                jumpStretch = 1.0
            }
        }
    }

    private func triggerPendingTrailCelebration() {
        guard let event = gamify.consumePendingTrailCelebration() else { return }
        trailCelebration = event
        trailCelebrationInFlight = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showTrailCelebration = true
        }

        if event.toLevel > event.fromLevel {
            mascotLevel = event.fromLevel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                hopMascot(to: event.toLevel)
            }
        } else {
            PixioHaptics.confirm()
            withAnimation(.easeOut(duration: 0.22)) { jumpArc = -22 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.56)) { jumpArc = 0 }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.easeInOut(duration: 0.28)) {
                showTrailCelebration = false
            }
            trailCelebrationInFlight = false
        }
    }

    private func stageState(_ stage: Stage) -> StageState {
        if contains(userLevel, in: stage) { return .current }
        if userLevel >= stage.maxLevel { return .completed }
        return .locked
    }

    private func contains(_ level: Int, in stage: Stage) -> Bool {
        let isLast = stage.index == Self.stages.last?.index
        return level >= stage.minLevel && (isLast ? level <= stage.maxLevel : level < stage.maxLevel)
    }

    private func tapStage(_ state: StageState) {
        guard state == .current else { return }
        if flashcardsDue > 0 { openStudy(.flashcardHome()) } else { openStudy(.qbank) }
    }

    private func openStudy(_ route: Route) {
        PixioHaptics.tap()
        withAnimation(.easeInOut(duration: 0.24)) {
            router.navigate(to: route)
        }
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

    fileprivate struct Tier {
        let idx: Int
        let name: String
        let minLevel: Int
        let maxLevel: Int
        let bright: Color
        let mid: Color
        let dark: Color
    }

    private enum LandmarkSide {
        case leading
        case trailing
    }

    private enum LandmarkKind {
        case school
        case university
        case healthPost
        case majorHospital
        case ambulance
        case lab
        case clinic
    }

    private struct Landmark: Identifiable {
        let id: String
        let kind: LandmarkKind
        let side: LandmarkSide
        let row: CGFloat
        let scale: CGFloat
        let opacity: Double
    }

    private struct TrailXpCelebrationPill: View {
        let event: GamificationEventManager.TrailCelebration
        @State private var pulse = false

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    VitaColors.accentLight.opacity(0.62),
                                    VitaColors.accent.opacity(0.24),
                                    .clear
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 36
                            )
                        )
                    Image(systemName: event.toLevel > event.fromLevel ? "sparkles" : "bolt.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: VitaColors.accent.opacity(pulse ? 0.44 : 0.18), radius: pulse ? 16 : 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(event.xpAwarded) XP")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(VitaColors.accentLight)
                        .monospacedDigit()
                    Text(event.toLevel > event.fromLevel ? "Vita avançou para o nível \(event.toLevel)" : "\(event.source.label) concluído")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    VitaColors.accent.opacity(0.16),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.8))
            )
            .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private struct MedicalWorldLandmark: View {
        let kind: LandmarkKind

        private var footprint: CGSize {
            switch kind {
            case .majorHospital:
                return CGSize(width: 134, height: 112)
            case .school, .university:
                return CGSize(width: 116, height: 102)
            case .healthPost:
                return CGSize(width: 108, height: 92)
            case .ambulance, .lab, .clinic:
                return CGSize(width: 92, height: 82)
            }
        }

        var body: some View {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: footprint.width * 0.78, height: 16)
                    .offset(y: footprint.height * 0.38)

                switch kind {
                case .school:
                    school
                case .university:
                    university
                case .healthPost:
                    healthPost
                case .majorHospital:
                    majorHospital
                case .ambulance:
                    ambulance
                case .lab:
                    lab
                case .clinic:
                    clinic
                }
            }
            .frame(width: footprint.width, height: footprint.height)
        }

        private var school: some View {
            ZStack {
                LandmarkRoof()
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.roofTop,
                                TrailWorld.roofBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 96, height: 34)
                    .offset(y: -38)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.48), lineWidth: 1)
                    )
                    .offset(y: 3)

                Circle()
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -17)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(idx == 1 ? Color.white.opacity(0.68) : TrailWorld.windowGlow.opacity(0.74))
                            .frame(width: 12, height: 14)
                    }
                }
                .offset(y: 7)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(TrailWorld.wood.opacity(0.78))
                    .frame(width: 18, height: 24)
                    .offset(y: 25)

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .frame(width: 86, height: 5)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .frame(width: 74, height: 5)
                }
                .foregroundStyle(TrailWorld.wood.opacity(0.72))
                .offset(y: 44)

                Capsule()
                    .fill(TrailWorld.wood.opacity(0.80))
                    .frame(width: 4, height: 38)
                    .offset(x: -42, y: -24)
                LandmarkFlag()
                    .fill(TrailWorld.flag)
                    .frame(width: 24, height: 17)
                    .offset(x: -29, y: -37)
            }
        }

        private var university: some View {
            ZStack {
                LandmarkRoof()
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.roofTop,
                                TrailWorld.roofBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 106, height: 32)
                    .offset(y: -40)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 98, height: 54)
                    .offset(y: -2)

                HStack(spacing: 7) {
                    ForEach(0..<5, id: \.self) { idx in
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(Color.white.opacity(0.74))
                                .frame(width: 8, height: 37)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(TrailWorld.wood.opacity(0.58))
                                .frame(width: 12, height: 5)
                        }
                        .opacity(idx == 2 ? 1 : 0.92)
                    }
                }
                .offset(y: 3)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(TrailWorld.wood.opacity(0.80))
                    .frame(width: 22, height: 25)
                    .offset(y: 24)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(TrailWorld.wood.opacity(0.78))
                    .frame(width: 108, height: 8)
                    .offset(y: 39)

                Circle()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -36)
            }
        }

        private var healthPost: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.roofTop,
                                TrailWorld.roofBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 98, height: 18)
                    .offset(y: -31)

                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 4, height: 14)
                    }
                }
                .offset(y: -31)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TrailWorld.windowGlow.opacity(0.62))
                        .frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TrailWorld.windowDim.opacity(0.62))
                        .frame(width: 20, height: 26)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TrailWorld.windowGlow.opacity(0.62))
                        .frame(width: 18, height: 18)
                }
                .offset(y: 10)

                Image(systemName: "cross.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(TrailWorld.crossRed)
                    .offset(y: -5)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(TrailWorld.wood.opacity(0.66))
                    .frame(width: 96, height: 7)
                    .offset(y: 34)
            }
        }

        private var majorHospital: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(TrailWorld.stoneWing)
                    .frame(width: 38, height: 62)
                    .offset(x: -42, y: 10)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(TrailWorld.stoneWing)
                    .frame(width: 38, height: 62)
                    .offset(x: 42, y: 10)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.52), lineWidth: 1)
                    )

                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { _ in hospitalWindow }
                    }
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { _ in hospitalWindow }
                    }
                    Image(systemName: "cross.fill")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(TrailWorld.crossRed)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TrailWorld.wood.opacity(0.64))
                        .frame(width: 24, height: 20)
                }
                .offset(y: 1)

                HStack(spacing: 48) {
                    VStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { _ in hospitalWindow }
                    }
                    VStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { _ in hospitalWindow }
                    }
                }
                .offset(y: 6)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(TrailWorld.wood.opacity(0.76))
                    .frame(width: 122, height: 9)
                    .offset(y: 53)

                Circle()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("H")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -50)
            }
        }

        private var hospitalWindow: some View {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(TrailWorld.windowGlow.opacity(0.52))
                .frame(width: 10, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.5)
                )
        }

        private var ambulance: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                TrailWorld.vanShade
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 76, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.54), lineWidth: 1)
                    )
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(TrailWorld.windowGlow.opacity(0.62))
                    .frame(width: 22, height: 13)
                    .offset(x: 18, y: -5)
                Image(systemName: "cross.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(TrailWorld.crossRed)
                    .offset(x: -16, y: -4)
                HStack(spacing: 39) {
                    Circle().fill(TrailWorld.wheel).frame(width: 13, height: 13)
                    Circle().fill(TrailWorld.wheel).frame(width: 13, height: 13)
                }
                .offset(y: 18)
            }
            .rotationEffect(.degrees(-4))
        }

        private var lab: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.46), lineWidth: 1)
                    )
                Image(systemName: "testtube.2")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .offset(y: -4)
                HStack(spacing: 5) {
                    Circle().fill(TrailWorld.vialGreen).frame(width: 7, height: 7)
                    Circle().fill(TrailWorld.vialAmber).frame(width: 7, height: 7)
                    Circle().fill(TrailWorld.vialBlue).frame(width: 7, height: 7)
                }
                .offset(y: 20)
            }
        }

        private var clinic: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrailWorld.stoneTop,
                                TrailWorld.stoneBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.44), lineWidth: 1)
                    )
                Image(systemName: "stethoscope")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .offset(y: -2)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TrailWorld.crossRed)
                    .offset(x: 18, y: -18)
            }
        }
    }

    private struct LandmarkFlag: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.74))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    private struct LandmarkRoof: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    // 5 SEÇÕES (20 níveis cada) com cores distintas. Cada seção começa num gate
    // múltiplo de 20; dentro dela, os nós avançam em blocos de 5 níveis.
    private static let tiers: [Tier] = [
        Tier(idx: 0, name: "Vestibulando", minLevel: 0, maxLevel: 20,
             bright: TrailWorld.tier0Bright, mid: TrailWorld.tier0Mid, dark: TrailWorld.tier0Dark),
        Tier(idx: 1, name: "Acadêmico", minLevel: 20, maxLevel: 40,
             bright: TrailWorld.tier1Bright, mid: TrailWorld.tier1Mid, dark: TrailWorld.tier1Dark),
        Tier(idx: 2, name: "Clínico", minLevel: 40, maxLevel: 60,
             bright: TrailWorld.tier2Bright, mid: TrailWorld.tier2Mid, dark: TrailWorld.tier2Dark),
        Tier(idx: 3, name: "Internato", minLevel: 60, maxLevel: 80,
             bright: TrailWorld.tier3Bright, mid: TrailWorld.tier3Mid, dark: TrailWorld.tier3Dark),
        Tier(idx: 4, name: "Lenda", minLevel: 80, maxLevel: 100,
             bright: TrailWorld.tier4Bright, mid: TrailWorld.tier4Mid, dark: TrailWorld.tier4Dark),
    ]

    private static let stages: [Stage] = [
        Stage(index: 1,  name: "Termômetro",   icon: "thermometer.medium", asset: "level-01-thermometer",   minLevel: 0,  maxLevel: 5,   tierIdx: 0),
        Stage(index: 2,  name: "Seringa",      icon: "syringe.fill",       asset: "level-02-syringe",       minLevel: 5,  maxLevel: 10,  tierIdx: 0),
        Stage(index: 3,  name: "Bisturi",      icon: "cross.case.fill",    asset: "level-03-scalpel",       minLevel: 10, maxLevel: 15,  tierIdx: 0),
        Stage(index: 4,  name: "Estetoscópio", icon: "stethoscope",        asset: "level-04-stethoscope",   minLevel: 15, maxLevel: 20,  tierIdx: 0),
        Stage(index: 5,  name: "Máscara",      icon: "facemask.fill",      asset: "level-05-mask",          minLevel: 20, maxLevel: 25,  tierIdx: 1),
        Stage(index: 6,  name: "Microscópio",  icon: "microbe.fill",       asset: "level-06-microscope",    minLevel: 25, maxLevel: 30,  tierIdx: 1),
        Stage(index: 7,  name: "Martelo",      icon: "hammer.fill",        asset: "level-07-reflex-hammer", minLevel: 30, maxLevel: 35,  tierIdx: 1),
        Stage(index: 8,  name: "Desfibrilador",icon: "bolt.heart.fill",    asset: "level-08-defibrillator", minLevel: 35, maxLevel: 40,  tierIdx: 1),
        Stage(index: 9,  name: "DNA",          icon: "waveform.path.ecg",  asset: "level-09-dna",           minLevel: 40, maxLevel: 45,  tierIdx: 2),
        Stage(index: 10, name: "Comprimido",   icon: "pills.fill",         asset: "level-10-pill",          minLevel: 45, maxLevel: 50,  tierIdx: 2),
        Stage(index: 11, name: "Coração",      icon: "heart.fill",         asset: "level-11-heart",         minLevel: 50, maxLevel: 55,  tierIdx: 2),
        Stage(index: 12, name: "Jaleco",       icon: "cross.case.fill",    asset: "level-12-labcoat",       minLevel: 55, maxLevel: 60,  tierIdx: 2),
        Stage(index: 13, name: "Robô Da Vinci",icon: "gearshape.2.fill",   asset: "level-13-davinci-robot", minLevel: 60, maxLevel: 65,  tierIdx: 3),
        Stage(index: 14, name: "Cérebro",      icon: "brain.head.profile", asset: "level-14-brain",         minLevel: 65, maxLevel: 70,  tierIdx: 3),
        Stage(index: 15, name: "Crânio",       icon: "staroflife.fill",    asset: "level-15-skull",         minLevel: 70, maxLevel: 75,  tierIdx: 3),
        Stage(index: 16, name: "Escudo",       icon: "shield.fill",        asset: "level-16-shield",        minLevel: 75, maxLevel: 80,  tierIdx: 3),
        Stage(index: 17, name: "Diploma",      icon: "graduationcap.fill", asset: "level-17-diploma",       minLevel: 80, maxLevel: 85,  tierIdx: 4),
        Stage(index: 18, name: "Caduceu",      icon: "cross.fill",         asset: "level-18-caduceus-staff",minLevel: 85, maxLevel: 90,  tierIdx: 4),
        Stage(index: 19, name: "Coroa",        icon: "crown.fill",         asset: "level-19-crown",         minLevel: 90, maxLevel: 95,  tierIdx: 4),
        Stage(index: 20, name: "Vita",         icon: "rosette",            asset: "level-20-vita-caduceu",  minLevel: 95, maxLevel: 100, tierIdx: 4),
    ]

    private static let landmarks: [Landmark] = [
        // 1 casa por SEÇÃO, no MEIO dela (linha k*4+2) — longe do banner (em k*4)
        // e do próximo (k*4+4). Antes: 8 casas, 2 na seção 1 e algumas ATRÁS do
        // banner (Rafael 2026-07-05). Temática por fase da carreira.
        Landmark(id: "sec1-school",     kind: .school,        side: .leading,  row: 2,  scale: 1.02, opacity: 0.95),
        Landmark(id: "sec2-university", kind: .university,    side: .trailing, row: 6,  scale: 1.02, opacity: 0.93),
        Landmark(id: "sec3-healthpost", kind: .healthPost,    side: .leading,  row: 10, scale: 1.00, opacity: 0.92),
        Landmark(id: "sec4-hospital",   kind: .majorHospital, side: .trailing, row: 14, scale: 1.00, opacity: 0.92),
        Landmark(id: "sec5-clinic",     kind: .clinic,        side: .leading,  row: 18, scale: 0.98, opacity: 0.90),
    ]

    private var trailItems: [TrailItem] {
        Self.stages.map { TrailItem.stage($0) }
    }
}

// MARK: - Campo de grama (Canvas) — base verde + folhas determinísticas.
// Hybrid (Rafael 2026-06-18): vetor agora; trocável por textura crafted depois.
private struct GrassField: View {
    let height: CGFloat
    var phase: Double = 0
    var body: some View {
        Canvas { ctx, size in
            func drawTree(at point: CGPoint, scale: CGFloat, side: CGFloat, sway: CGFloat) {
                let trunk = CGRect(x: point.x - 4 * scale, y: point.y - 4 * scale,
                                   width: 8 * scale, height: 24 * scale)
                let shadow = CGRect(x: point.x - 23 * scale, y: point.y + 15 * scale,
                                    width: 46 * scale, height: 12 * scale)
                let deepLeaf = TrailWorld.canopyDeep
                let midLeaf = TrailWorld.canopyMid
                let lightLeaf = TrailWorld.canopyLight

                ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.16)))
                ctx.fill(Path(roundedRect: trunk, cornerRadius: 3 * scale),
                         with: .linearGradient(
                            Gradient(colors: [TrailWorld.trunkTop,
                                              TrailWorld.trunkBottom]),
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
                for (ci, crown) in crowns.enumerated() {
                    let rect = CGRect(
                        x: point.x + (crown.0 * side - crown.2) * scale + sway * (1 + CGFloat(ci) * 0.25),
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
                    Gradient(colors: [TrailWorld.meadowTop,
                                      TrailWorld.meadowBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
            let step: CGFloat = 46
            let cols = Int(size.width / step) + 1
            let rows = Int(size.height / step) + 1
            let g1 = TrailWorld.tuftDeep
            let g2 = TrailWorld.tuftMid
            let g3 = TrailWorld.tuftLight

            let treeRows = max(5, Int(size.height / 360))
            for i in 0..<treeRows {
                let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
                let seed = CGFloat((i * 371) % 997) / 997
                let x = side < 0
                    ? 28 + seed * 38
                    : size.width - 28 - seed * 42
                let y = 104 + CGFloat(i) * 330 + CGFloat((i * 53) % 61)
                guard y < size.height - 20 else { continue }
                drawTree(at: CGPoint(x: x, y: y),
                         scale: 0.72 + CGFloat((i * 29) % 31) / 100,
                         side: side,
                         sway: CGFloat(sin(phase * 0.9 + Double(i) * 1.7)) * 1.6)
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
                        let wind = CGFloat(sin(phase * 1.5 + Double(cx) * 0.045 + Double(cy) * 0.018)) * 1.7
                        let lean = CGFloat(k) * 2.2 + (CGFloat(s2) - 0.5) * 1.8 + wind
                        var blade = Path()
                        blade.move(to: CGPoint(x: bx, y: cy))
                        blade.addQuadCurve(to: CGPoint(x: bx + lean, y: cy - bh),
                                           control: CGPoint(x: bx + lean * 0.5, y: cy - bh * 0.6))
                        let col = seed > 0.66 ? g3 : (seed > 0.33 ? g2 : g1)
                        ctx.stroke(blade, with: .color(col.opacity(0.62)), lineWidth: 2.0)
                    }
                    // florzinha ocasional (vida no campo)
                    if s2 > 0.92 {
                        let fc: Color = seed > 0.5 ? TrailWorld.fireflyGold
                                                   : TrailWorld.fireflyWarm
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)),
                                 with: .color(fc.opacity(0.92)))
                    }
                }
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
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

// MARK: - Muralha de seção — sebe noturna + pilares de pedra com lampiões.
// A estrada passa pelo vão (archX vem da MESMA fórmula senoidal da trilha).

private struct TrailSectionWall: View {
    let archX: CGFloat
    let tier: ProgressoScreen.Tier
    let number: Int
    var isOpen: Bool = false

    private let wallY: CGFloat = 66   // centro vertical da muralha no componente

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gap: CGFloat = 50
            ZStack {
                rampart(width: w)
                gate(gap: gap)
                pillar(at: archX - gap)
                pillar(at: archX + gap)
                signPlate(width: w)
            }
            .animation(.easeInOut(duration: 0.85), value: isOpen)
        }
    }

    // MARK: muralha ALTA na cor da seção (pedra + ameias no topo)
    private func rampart(width w: CGFloat) -> some View {
        let bodyH: CGFloat = 42
        return ZStack(alignment: .top) {
            // ameias (crenellations) — dá a altura de fortaleza
            HStack(spacing: 10) {
                ForEach(0..<max(3, Int(w / 26)), id: \.self) { _ in
                    UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                        .fill(LinearGradient(colors: [tier.mid, tier.dark],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 15, height: 14)
                }
            }
            .frame(width: w)
            .offset(y: -10)
            // corpo da muralha (cor da seção = atmosfera)
            Rectangle()
                .fill(LinearGradient(colors: [tier.mid.opacity(0.92), tier.dark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: w, height: bodyH)
                .overlay(alignment: .top) {
                    Rectangle().fill(tier.bright.opacity(0.45)).frame(height: 1.4)
                }
                .overlay(  // juntas de pedra
                    VStack(spacing: 13) {
                        Rectangle().fill(Color.black.opacity(0.16)).frame(height: 1)
                        Rectangle().fill(Color.black.opacity(0.16)).frame(height: 1)
                    }
                    .padding(.top, 12)
                )
        }
        .frame(width: w, alignment: .top)
        .position(x: w / 2, y: wallY)
        .shadow(color: .black.opacity(0.42), radius: 7, y: 6)
    }

    // MARK: placa de PEDRA com o nome GRAVADO (substitui o banner roxo)
    private func signPlate(width w: CGFloat) -> some View {
        let plateX = min(max(archX, 96), w - 96)
        return VStack(spacing: 1) {
            Text("SEÇÃO \(number)")
                .font(.system(size: 8, weight: .black)).kerning(1.5) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                .foregroundStyle(tier.bright.opacity(0.92))
            Text(tier.name.uppercased())
                .font(.system(size: 13, weight: .black)).kerning(0.4) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 0, y: 1)   // gravado (letterpress)
            Text("Níveis \(tier.minLevel)–\(tier.maxLevel)")
                .font(.system(size: 8, weight: .bold)) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .padding(.horizontal, 13).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                .fill(LinearGradient(colors: [tier.dark, Color.black.opacity(0.9)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                    .strokeBorder(tier.bright.opacity(0.45), lineWidth: 0.8))
        )
        .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
        .position(x: plateX, y: 16)
    }

    // MARK: portão (2 batentes que giram nas dobradiças; abre quando desbloqueia)
    private func gate(gap: CGFloat) -> some View {
        ZStack {
            doorLeaf(width: gap, openAngle: -104, anchor: .leading,  centerX: archX - gap / 2)
            doorLeaf(width: gap, openAngle: 104,  anchor: .trailing, centerX: archX + gap / 2)
        }
    }

    private func doorLeaf(width: CGFloat, openAngle: Double, anchor: UnitPoint, centerX: CGFloat) -> some View {
        let freeEdgeTrailing = anchor == .leading
        return RoundedRectangle(cornerRadius: 3, style: .continuous) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
            .fill(LinearGradient(colors: [TrailWorld.wood, TrailWorld.stoneBottom],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: 34)
            .overlay(  // bandas na cor da seção
                VStack(spacing: 10) {
                    Capsule().fill(tier.bright.opacity(0.7)).frame(height: 2)
                    Capsule().fill(tier.bright.opacity(0.7)).frame(height: 2)
                }
                .padding(.horizontal, 5)
            )
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous) // ds-allow: arte do mundo do jogo (placa/portão da fortaleza), não chrome de UI
                .strokeBorder(tier.bright.opacity(0.30), lineWidth: 0.6))
            .overlay(  // argola na borda livre (encontro do meio quando fechado)
                Circle().fill(TrailWorld.windowGlow)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: TrailWorld.windowGlow.opacity(0.8), radius: 2)
                    .position(x: freeEdgeTrailing ? width - 4 : 4, y: 17)
            )
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            .rotationEffect(.degrees(isOpen ? openAngle : 0), anchor: anchor)
            .position(x: centerX, y: wallY)
    }

    // MARK: pilares com lampião aceso
    private func pillar(at x: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [tier.mid, tier.dark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 15, height: 54)
            Circle().fill(TrailWorld.windowGlow).frame(width: 8, height: 8)
                .shadow(color: TrailWorld.windowGlow.opacity(0.85), radius: 7)
                .offset(y: -30)
        }
        .position(x: x, y: wallY - 5)
    }
}

// MARK: - Bichinhos do mundo (Rafael 2026-07-03) — vida aleatória + easter egg.
// Silhuetas noturnas vetoriais; capivara DOURADA é rara (~5% das capivaras) e
// responde ao toque com brilho + haptic. Tudo sorteado no spawner: nunca script.

struct TrailCritter: Identifiable {
    enum Kind { case capivara }
    let id = UUID()
    let kind: Kind
    let golden: Bool
    let y: CGFloat
    let leftToRight: Bool
    let duration: Double
    let scale: CGFloat
}

private struct TrailCritterView: View {
    let critter: TrailCritter
    let width: CGFloat

    @State private var t: CGFloat = 0
    @State private var sparkle = false

    var body: some View {
        let startX: CGFloat = critter.leftToRight ? -70 : width + 70
        let endX: CGFloat   = critter.leftToRight ? width + 70 : -70

        critterShape
            .scaleEffect(x: critter.leftToRight ? 1 : -1, y: 1)
            .scaleEffect(critter.scale)
            // SEM bob/repeatForever nenhum (Rafael 2026-07-03: qualquer
            // oscilacao lia como bicho tremendo/voando; corpo parado
            // deslizando devagar = calmo e vivo o suficiente).
            .overlay(alignment: .top) {
                if sparkle {
                    Image(systemName: "sparkles")
                        .font(.system(size: critter.golden ? 22 : 14, weight: .bold)) // ds-allow: tamanho de arte do mundo (sparkle do bicho), nao tipografia de UI
                        .foregroundStyle(TrailWorld.fireflyGold)
                        .offset(y: -26)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            // travessia: linear LENTA, escopada no `t`
            .position(x: startX + (endX - startX) * t, y: critter.y)
            .animation(.linear(duration: critter.duration), value: t)
            .onAppear { t = 1 }
            .onTapGesture {
                guard !sparkle else { return }
                if critter.golden { PixioHaptics.confirm() } else { PixioHaptics.tap() }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { sparkle = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeOut(duration: 0.3)) { sparkle = false }
                }
            }
    }

    @ViewBuilder private var critterShape: some View {
        capivara
    }

    // Capivara: silhueta rechonchuda + rim light; dourada quando rara.
    private var capivara: some View {
        let body: Color = critter.golden ? VitaColors.emblemMid : TrailWorld.critterBody
        let top: Color  = critter.golden ? VitaColors.emblemBright : TrailWorld.critterBelly
        return ZStack {
            // sombra no chão
            Ellipse().fill(Color.black.opacity(0.22))
                .frame(width: 34, height: 7).offset(y: 14)
            // pernas
            HStack(spacing: 14) {
                Capsule().fill(body).frame(width: 4.5, height: 9)
                Capsule().fill(body).frame(width: 4.5, height: 9)
            }
            .offset(y: 10)
            // corpo
            RoundedRectangle(cornerRadius: 11, style: .continuous) // ds-allow: corpo organico da capivara (arte), nao raio de card
                .fill(LinearGradient(colors: [top, body], startPoint: .top, endPoint: .bottom))
                .frame(width: 36, height: 20)
            // cabeça (focinho quadrado de capivara)
            UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 5,
                                   bottomTrailingRadius: 8, topTrailingRadius: 9)
                .fill(LinearGradient(colors: [top, body], startPoint: .top, endPoint: .bottom))
                .frame(width: 17, height: 14)
                .offset(x: 20, y: -6)
            // orelha
            Circle().fill(body).frame(width: 5, height: 5).offset(x: 15, y: -13)
            // olho
            Circle().fill(critter.golden ? TrailWorld.fireflyWarm : Color.white.opacity(0.75))
                .frame(width: 2.5, height: 2.5).offset(x: 22, y: -8)
        }
        .shadow(color: critter.golden ? TrailWorld.fireflyGold.opacity(0.55) : .clear, radius: 9)
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
