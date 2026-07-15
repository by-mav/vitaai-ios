import SwiftUI

// QA: flags de debug globais (args de launch). --vita-level=99 força o nível no
// MAPA e no SELO do topo (VitaTopBar via AppRouter) — simulação consistente. Rafael 2026-07-14.
enum VitaDebug {
    static var forcedLevel: Int? {
        for a in ProcessInfo.processInfo.arguments where a.hasPrefix("--vita-level=") {
            return Int(a.dropFirst("--vita-level=".count))
        }
        return nil
    }
    /// QA: qual tier de loja o `--vita-shop-preview` abre (`--vita-shop=0..4`). Default Calouro.
    static var shopTier: Int {
        for a in ProcessInfo.processInfo.arguments where a.hasPrefix("--vita-shop=") {
            return Int(a.dropFirst("--vita-shop=".count)) ?? 0
        }
        return 0
    }
}

// MARK: - HomeScreen — Mapa vivo da carreira médica (gold 3D, estilo Duolingo)
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
// Mantém `HomeScreen()` (sem params) → AppRouter/pbxproj intocados.

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

struct HomeScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var pulse = false
    @State private var hop = false
    @State private var mascotLevel: Int = 1
    @State private var didAutoOpenShop = false   // QA: --vita-shop-preview abre a loja só 1× (evita loop ao voltar)
    @State private var jumpArc: CGFloat = 0
    @State private var jumpStretch: CGFloat = 1
    @State private var trailCelebration: GamificationEventManager.TrailCelebration?
    @State private var showTrailCelebration = false
    @State private var trailCelebrationInFlight = false
    @State private var critters: [TrailCritter] = []
    @State private var demoLevel: Int? = nil   // QA: simula level-up (--vita-levelup-demo)
    // Provador de skins (--vita-skin-demo): 1 item equipado por slot.
    @State private var equipHead: MascotAccessory? = nil
    @State private var equipFace: MascotAccessory? = nil
    @State private var equipNeck: MascotAccessory? = nil
    @State private var equipPalette: MascotPalette = .vita
    @Namespace private var mascotTrail

    // Baús da trilha (Rafael 2026-07-14): estado vem do backend (nível/aberto).
    @StateObject private var skins = SkinStore()
    @State private var chestConfirmLevel: Int?   // baú tocado, aguardando confirmar a chave
    @State private var chestReveal: LootboxResult?  // baú aberto → revelação em tela cheia
    @State private var didAutoChest = false   // QA: --vita-open-chest=N abre 1× (testar sem tap)

    // Onde ficam os baús na trilha (nível de cada um). Espelha CHEST_LEVELS do backend.
    static let chestLevels: Set<Int> = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    /// Nível de baú desta etapa (o topo dela cai num nível de baú), senão nil.
    private func chestLevel(for stage: Stage) -> Int? {
        Self.chestLevels.contains(stage.maxLevel) ? stage.maxLevel : nil
    }

    // QA: --vita-levelup-demo roda em loop a passagem por uma seção (portão abre + Vita atravessa)
    private var demoLevelUp: Bool {
        ProcessInfo.processInfo.arguments.contains("--vita-levelup-demo")
    }

    private var vmProg: ProgressoViewModel { container.progressoViewModel }
    private var dash: DashboardViewModel { container.dashboardViewModel }
    private var gamify: GamificationEventManager { container.gamificationEvents }

    private var userLevel: Int { VitaDebug.forcedLevel ?? demoLevel ?? max(0, gamify.currentLevel) }
    private var flashcardsDue: Int { dash.flashcardsDueTotal }

    private var currentStage: Stage {
        if let stage = Self.stages.first(where: { contains(userLevel, in: $0) }) {
            return stage
        }
        return userLevel > (Self.stages.last?.maxLevel ?? 0) ? Self.stages[Self.stages.count - 1] : Self.stages[0]
    }

    // Geometria da trilha — cada nó ocupa um "slot" de altura fixa (rowStride) e
    // serpenteia em x por sin(i*freq)*amp. A estrada usa a MESMA fórmula → alinha.
    private static let rowStride: CGFloat = 188
    private static let rowAmp: CGFloat = 66
    private static let rowFreq: Double = 0.9
    // The home chrome floats over the map. Keep the first playable node below it,
    // otherwise the scroll is technically at the top while level 1 is hidden.
    private static let trailTopInset: CGFloat = 178
    private static let trailBottomInset: CGFloat = 360

    private var trailContentHeight: CGFloat {
        Self.trailTopInset + CGFloat(trailItems.count) * Self.rowStride + Self.trailBottomInset
    }

    /// Stops travados por seção com HARD-STOPS na posição REAL de cada muralha —
    /// a cor muda EXATAMENTE onde o muro cruza a estrada/grama, não numa fração
    /// uniforme (Rafael 2026-07-05: "a rua não troca exatamente após o portão").
    /// `wallLocalY(k)` = Y da muralha k (fronteira da seção k) em coord LOCAL da
    /// view onde o gradiente é pintado; `height` = altura total dessa view. Cada
    /// view (estrada tem offset trailTopInset; grama não) passa seu próprio mapa.
    private static func sectionStops(_ key: (Tier) -> Color,
                                     wallLocalY: (Int) -> CGFloat,
                                     height: CGFloat) -> Gradient {
        let n = tiers.count
        guard height > 0 else { return Gradient(colors: [key(tiers[0])]) }
        func frac(_ y: CGFloat) -> Double { Double(min(height, max(0, y)) / height) }
        var stops: [Gradient.Stop] = []
        for i in 0..<n {
            let top = i == 0 ? 0.0 : frac(wallLocalY(i))          // fronteira superior da seção i
            let bot = i == n - 1 ? 1.0 : frac(wallLocalY(i + 1))  // fronteira inferior
            stops.append(.init(color: key(tiers[i]), location: top))
            stops.append(.init(color: key(tiers[i]), location: bot))
        }
        return Gradient(stops: stops)
    }

    /// Y local da muralha k DENTRO da estrada (dirtPath tem offset trailTopInset,
    /// então o inset já sai da coord local → muro k = k*4*rowStride).
    private static func roadWallY(_ k: Int) -> CGFloat { CGFloat(k * 4) * rowStride }
    /// Y local da muralha k DENTRO da grama (grassField NÃO tem offset → inclui o inset).
    private static func grassWallY(_ k: Int) -> CGFloat { trailTopInset + CGFloat(k * 4) * rowStride }

    // MARK: - Caminho de TERRA sobre a grama (ref Duolingo, Rafael 2026-06-18).
    // Aterra os nós no mundo (não flutuam). Terra clara em cima + borda escura +
    // sombra na grama + pegadas tracejadas. Sem cor de seção (a terra é neutra).
    private var dirtPath: some View {
        let road = TrailRoad(count: trailItems.count, stride: Self.rowStride,
                             amp: Self.rowAmp, freq: Self.rowFreq)
        // A estrada pega a COR DA SEÇÃO (Rafael 2026-07-05): hard-stops na posição
        // REAL de cada muralha (roadWallY) sobre a altura da estrada → a cor muda
        // exatamente ao cruzar o muro, nunca antes/depois.
        let edgeGrad = LinearGradient(gradient: Self.sectionStops({ $0.dark },
                                                                  wallLocalY: Self.roadWallY,
                                                                  height: trailContentHeight),
                                      startPoint: .top, endPoint: .bottom)
        let surfaceGrad = LinearGradient(gradient: Self.sectionStops({ $0.mid },
                                                                     wallLocalY: Self.roadWallY,
                                                                     height: trailContentHeight),
                                         startPoint: .top, endPoint: .bottom)
        return ZStack {
            // sombra do caminho na grama
            road.stroke(Color.black.opacity(0.14),
                        style: StrokeStyle(lineWidth: 36, lineCap: .round, lineJoin: .round))
                .offset(y: 4)
            // borda escura (cor escura da seção)
            road.stroke(edgeGrad,
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
            // superfície (cor média da seção)
            road.stroke(surfaceGrad,
                        style: StrokeStyle(lineWidth: 27, lineCap: .round, lineJoin: .round))
            // fio de luz no topo da superfície (dá relevo)
            road.stroke(Color.white.opacity(0.14),
                        style: StrokeStyle(lineWidth: 27, lineCap: .round, lineJoin: .round))
                .blendMode(.plusLighter).mask(road.stroke(style: StrokeStyle(lineWidth: 27)).offset(y: -1))
            // centro tracejado
            road.stroke(Color.white.opacity(0.28),
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
            LinearGradient(gradient: Self.sectionStops({ $0.mid.opacity(0.05) },
                                                       wallLocalY: Self.grassWallY, height: h),
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(gradient: Self.sectionStops({ $0.dark.opacity(0.25) },
                                                       wallLocalY: Self.grassWallY, height: h),
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

    // Céu do mundo pela HORA DO CELULAR (WorldClock): sol + céu claro de dia,
    // lua + estrelas de noite. Fica ATRÁS do mundo (não lava prédios nem colide
    // com a UI). "Aspecto de sol", leve — Rafael 2026-07-14.
    @ViewBuilder private var dayNightSky: some View {
        GeometryReader { geo in
            let night = WorldClock.isNight
            let sx: [CGFloat] = [0.12, 0.28, 0.44, 0.60, 0.70, 0.34, 0.52, 0.20]
            let sy: [CGFloat] = [0.05, 0.09, 0.04, 0.11, 0.06, 0.14, 0.16, 0.13]
            ZStack(alignment: .top) {
                // tinta do céu no topo, some pra baixo
                LinearGradient(
                    colors: night
                        ? [Color(red: 0.10, green: 0.12, blue: 0.26).opacity(0.75), .clear]  // ds-allow: ceu dia/noite (WorldClock)
                        : [Color(red: 0.42, green: 0.64, blue: 0.95).opacity(0.70), .clear],  // ds-allow: ceu dia/noite (WorldClock)
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.42))
                // brilho do sol (dia) / lua (noite) no canto superior direito
                RadialGradient(
                    colors: night
                        ? [Color(red: 0.88, green: 0.90, blue: 1.0).opacity(0.45), .clear]  // ds-allow: ceu dia/noite (WorldClock)
                        : [Color(red: 1.0, green: 0.92, blue: 0.60).opacity(0.75), .clear],  // ds-allow: ceu dia/noite (WorldClock)
                    center: UnitPoint(x: 0.82, y: 0.06), startRadius: 2, endRadius: geo.size.width * 0.55)
                // estrelas (só de noite)
                if night {
                    ForEach(0..<8, id: \.self) { i in
                        Circle().fill(.white.opacity(0.8))
                            .frame(width: i % 3 == 0 ? 3.5 : 2.2, height: i % 3 == 0 ? 3.5 : 2.2)
                            .position(x: geo.size.width * sx[i], y: geo.size.height * sy[i])
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }



    // Nível em que cada casa desbloqueia (por fase/loja). Casa travada mostra
    // cadeado + "Desbloqueie no nível X" e não é clicável. Rafael 2026-07-14.
    // Desbloqueio dos prédios PROPORCIONAL 1→100 (Rafael 2026-07-14): 0/25/50/75/100.
    // No nv99 só o Instituto (100) fica trancado — o aluno está na casa ANTERIOR ao auge.
    private static func houseUnlock(_ l: Landmark) -> Int {
        switch l.shopTier ?? 0 {
        case 0: return 0     // Cursinho
        case 1: return 25    // Faculdade
        case 2: return 50    // Clínica-Escola
        case 3: return 75    // Hospital Universitário
        default: return 100  // Instituto de Especialidades = auge/endgame no nível 100
        }
    }

    // Cada seção da jornada tem SEU prédio (medicina: cursinho -> faculdade ->
    // clínica-escola -> hospital universitário -> instituto). Rafael 2026-07-14.
    private static func houseKind(_ l: Landmark) -> HouseKind {
        switch l.shopTier ?? 0 {
        case 0: return .cursinho
        case 1: return .faculdade
        case 2: return .clinicaEscola
        case 3: return .hospital
        default: return .instituto
        }
    }

    private var worldLandmarks: some View {
        let h = Self.trailTopInset + CGFloat(trailItems.count) * Self.rowStride + 140
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // (estradas casa→trilha REMOVIDAS — Rafael 2026-07-14: ficaram estranhas)
                ForEach(Self.landmarks) { landmark in
                    let unlock = Self.houseUnlock(landmark)
                    let unlocked = userLevel >= unlock
                    Semi3DHouse(kind: Self.houseKind(landmark), open: unlocked, level: unlock)
                        .frame(width: 210, height: 210)
                        .transaction { $0.animation = nil }   // estático (mata o bob do ScrollView)
                        .overlay(alignment: .center) {
                            if !unlocked {
                                VStack(spacing: 5) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 22, weight: .black))  // ds-allow: badge de cadeado + preview de debug
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.6), radius: 4)
                                    Text("Desbloqueie no nível \(unlock)")
                                        .font(.system(size: 10.5, weight: .bold))  // ds-allow: badge de cadeado + preview de debug
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.black.opacity(0.62)))
                                }
                                .offset(y: 8)
                            }
                        }
                        .scaleEffect(landmark.scale)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard unlocked, let tier = landmark.shopTier else { return }
                            router.navigate(to: .skinAppearance(shopTier: tier))
                        }
                        .position(
                            x: landmark.side == .leading ? geo.size.width * 0.20 : geo.size.width * 0.80,
                            y: Self.trailTopInset + (landmark.row * Self.rowStride) - 60
                        )
                }
            }
        }
        .frame(height: h)
    }

    // MARK: - Body

    // QA (Rafael 2026-07-14): --vita-house-preview mostra as casas-marco semi-3D
    // GRANDES (aberta + trancada) pra iterar a arte sem o mundo em volta. Remover
    // quando integrar no MedicalWorldLandmark.
    private var housePreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--vita-house-preview")
    }

    private var housePreviewView: some View {
        let kinds: [(HouseKind, Int)] = [(.cursinho, 7), (.faculdade, 28), (.clinicaEscola, 48), (.hospital, 68), (.instituto, 98)]
        return ZStack {
            LinearGradient(colors: [TrailWorld.fieldTop, TrailWorld.fieldBottom],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            dayNightSky
            ScrollView {
                VStack(spacing: 10) {
                    Text("As 5 casas-marco semi-3D").font(.system(size: 15, weight: .bold))  // ds-allow: badge de cadeado + preview de debug
                        .foregroundStyle(TrailWorld.tier0Bright).padding(.top, 8)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(0..<kinds.count, id: \.self) { i in
                            VStack(spacing: 2) {
                                Semi3DHouse(kind: kinds[i].0, open: true, level: kinds[i].1).frame(height: 158)
                                Text("\(kinds[i].0.label) · nv \(kinds[i].1)")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.72))  // ds-allow: badge de cadeado + preview de debug
                            }
                        }
                        VStack(spacing: 2) {
                            Semi3DHouse(kind: .clinicaEscola, open: false, level: 48).frame(height: 158)
                            Text("trancada (exemplo)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))  // ds-allow: badge de cadeado + preview de debug
                        }
                    }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 12)
            }
        }
    }

    var body: some View {
        if skinDemo { skinTryOn }
        else if housePreview { housePreviewView }
        else { worldBody }
    }

    // QA: --vita-shop-preview dispara a navegação REAL pra loja (tela cheia, igual ao toque no prédio).
    private var shopPreview: Bool { ProcessInfo.processInfo.arguments.contains("--vita-shop-preview") }

    private var worldBody: some View {
        ZStack {
            grassBase.ignoresSafeArea()
            dayNightSky
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
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
                    .onAppear {
                        if demoLevelUp { runLevelUpDemo(proxy) }
                        else {
                            // Abre JÁ na posição do nível atual (Duolingo-style) — Rafael 2026-07-14
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                proxy.scrollTo("stage-\(currentStage.index)", anchor: .center)
                            }
                        }
                    }
                    }
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
            if shopPreview && !didAutoOpenShop {   // QA: abre a loja 1× só (não re-navega ao voltar)
                didAutoOpenShop = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    router.navigate(to: .skinAppearance(shopTier: VitaDebug.shopTier))   // QA: --vita-shop=N
                }
            }
            // QA: abre a tela de disciplinas (unificada) pra testar sem tap.
            if ProcessInfo.processInfo.arguments.contains("--vita-open-disciplinas"), !didAutoOpenShop {
                didAutoOpenShop = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    router.navigate(to: .faculdadeDisciplinas)
                }
            }
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
        .task {
            await skins.load(api: container.api)
            // QA: abre o baú do nível N automaticamente (testar o fluxo sem tap).
            if !didAutoChest, chestReveal == nil,
               let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--vita-open-chest=") }),
               let lvl = Int(arg.dropFirst("--vita-open-chest=".count)) {
                didAutoChest = true
                if let won = await skins.openChest(level: lvl, api: container.api) {
                    chestReveal = won
                }
            }
        }
        // Confirmar a chave antes de abrir o baú.
        .confirmationDialog(
            "Abrir baú?",
            isPresented: Binding(
                get: { chestConfirmLevel != nil },
                set: { if !$0 { chestConfirmLevel = nil } }
            ),
            presenting: chestConfirmLevel
        ) { lvl in
            Button("Abrir com chave · \(skins.keyPrice) moedas") {
                Task {
                    if let won = await skins.openChest(level: lvl, api: container.api) {
                        chestReveal = won
                    }
                    chestConfirmLevel = nil
                }
            }
            Button("Agora não", role: .cancel) { chestConfirmLevel = nil }
        } message: { _ in
            Text("A chave custa \(skins.keyPrice) moedas. Você tem \(skins.balance).")
        }
        // Revelação do baú em tela cheia (mesma cerimônia da skin).
        .fullScreenCover(item: $chestReveal) { reveal in
            LootboxRevealView(
                result: reveal,
                onEquip: { equipWonChest(reveal); chestReveal = nil },
                onClose: { chestReveal = nil }
            )
        }
        .alert("Ops", isPresented: Binding(
            get: { skins.errorMessage != nil },
            set: { if !$0 { skins.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { skins.errorMessage = nil }
        } message: {
            Text(skins.errorMessage ?? "")
        }
    }

    /// Equipa a skin ganha no baú, preservando os outros slots.
    private func equipWonChest(_ reveal: LootboxResult) {
        let won = reveal.won
        Task {
            await skins.equip(
                head: won.slot == "head" ? won.id : skins.equippedId(slot: "head"),
                face: won.slot == "face" ? won.id : skins.equippedId(slot: "face"),
                neck: won.slot == "neck" ? won.id : skins.equippedId(slot: "neck"),
                palette: skins.equippedId(slot: "palette"),
                api: container.api
            )
            await appData.refreshProfileNow()   // Vita muda em TODAS as telas na hora
        }
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
                        .frame(width: geo.size.width, height: 132)
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

    // QA: --vita-skin-demo mostra o Vita REAL (OrbMascot) com skins ancoradas,
    // pra provar que acessório no orb não fica tosco. Prototype 2026-07-05.
    private var skinDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("--vita-skin-demo")
    }

    // PROVADOR de skins (QA, --vita-skin-demo) — 1 Vita grande + galeria lateral.
    // Só 1 orb ANIMADO (o grande); os thumbs são estáticos (animated:false) pra
    // não afundar o FPS. Toca no item → equipa/tira; 1 por categoria.
    private var skinTryOn: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HStack(alignment: .center, spacing: 6) {
                // ESQUERDA — o Vita grande, INTEIRO e centralizado, montando o look.
                VStack(spacing: 12) {
                    OrbMascot(palette: equipPalette,
                              size: 116,
                              accessories: [equipNeck, equipHead, equipFace].compactMap { $0 },
                              animated: true, nameTag: "Rafael", bounceEnabled: false, bob: false)
                    if equipHead != nil || equipFace != nil || equipNeck != nil || equipPalette != .vita {
                        Button {
                            equipHead = nil; equipFace = nil; equipNeck = nil; equipPalette = .vita
                        } label: {
                            Text("Limpar")
                                .font(.system(size: 12, weight: .semibold))  // ds-allow: QA
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 16).padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.10)))
                        }
                    }
                }
                .frame(width: 158)
                .frame(maxHeight: .infinity)

                // DIREITA — os itens pra provar, em coluna rolável (2 colunas).
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        tryOnCategory("Cabeça", MascotAccessory.allCases.filter { $0.slot == "Cabeça" }, equipHead) { tapEquip(&equipHead, $0) }
                        tryOnCategory("Rosto",  MascotAccessory.allCases.filter { $0.slot == "Rosto" }, equipFace) { tapEquip(&equipFace, $0) }
                        tryOnCategory("Pescoço", MascotAccessory.allCases.filter { $0.slot == "Pescoço" }, equipNeck) { tapEquip(&equipNeck, $0) }
                        tryOnColors()
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 12).padding(.top, 4)
                }
            }
            .padding(.top, 96)
            .padding(.bottom, 128)
        }
    }

    private func tapEquip(_ slot: inout MascotAccessory?, _ item: MascotAccessory) {
        slot = (slot == item) ? nil : item
    }

    private func tryOnCategory(_ title: String, _ items: [MascotAccessory], _ selected: MascotAccessory?, _ tap: @escaping (MascotAccessory) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))  // ds-allow: QA
                .foregroundColor(.white.opacity(0.5))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 14) {
                ForEach(items, id: \.self) { item in
                    tryOnCell(AnyView(OrbMascot(palette: .vita, size: 30, accessories: [item], animated: false)),
                              item.label, selected == item) { tap(item) }
                }
            }
        }
    }

    private func tryOnColors() -> some View {
        let colors: [(MascotPalette, String)] = [
            (.vita, "Ouro"), (.emerald, "Esmeralda"), (.sapphire, "Safira"),
            (.ruby, "Rubi"), (.amethyst, "Ametista")
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("CORES")
                .font(.system(size: 11, weight: .heavy))  // ds-allow: QA
                .foregroundColor(.white.opacity(0.5))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 14) {
                ForEach(0..<colors.count, id: \.self) { i in
                    tryOnCell(AnyView(OrbMascot(palette: colors[i].0, size: 30, accessories: [], animated: false)),
                              colors[i].1, equipPalette == colors[i].0) { equipPalette = colors[i].0 }
                }
            }
        }
    }

    private func tryOnCell(_ orb: AnyView, _ label: String, _ selected: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                orb.frame(width: 46, height: 46).drawingGroup().drawingGroup()
                Text(label)
                    .font(.system(size: 8, weight: .semibold))  // ds-allow: QA
                    .foregroundColor(.white.opacity(selected ? 0.95 : 0.5)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.white.opacity(0.14) : Color.clear))  // ds-allow: QA
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1))  // ds-allow: QA
        }
        .buttonStyle(.plain)
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
                let chestOpenable: Bool = {
                    guard let cl = chestLevel(for: stage), let ch = skins.chest(level: cl) else { return false }
                    return ch.unlocked && !ch.claimed
                }()
                Button(action: {
                    if chestOpenable, let cl = chestLevel(for: stage) {
                        chestConfirmLevel = cl
                    } else {
                        tapStage(state)
                    }
                }) {
                    coin(stage: stage, tier: tier, state: state)
                }
                .buttonStyle(TrailPressStyle())
                .disabled(state != .current && !chestOpenable)

                stageCaption(stage, state: state)
            }

            if contains(mascotLevel, in: stage) {
                mascot
                    .matchedGeometryEffect(id: "vita-trail-mascot", in: mascotTrail)
                    .background(Circle().fill(.white.opacity(0.24)).frame(width: 64, height: 64))
                    .scaleEffect(x: 2 - jumpStretch, y: jumpStretch, anchor: .bottom)
                    .offset(y: -64 + (hop ? -5 : 0) + jumpArc)
                    .zIndex(4)
                    // Tocar no Vita da home abre o guarda-roupa COMPLETO (inventário +
                    // tudo comprável). Os prédios abrem a loja filtrada por fase (Rafael 2026-07-09).
                    .contentShape(Circle())
                    .onTapGesture { router.navigate(to: .skinAppearance(shopTier: nil)) }
            }
        }
        .zIndex(state == .current ? 3 : 1)
        .animation(.spring(response: 0.72, dampingFraction: 0.78), value: mascotLevel)
    }

    private func stageCaption(_ stage: Stage, state: StageState) -> some View {
        VStack(spacing: 0) {
            Text(levelCaption(for: stage, state: state))
                .font(.system(size: 11, weight: .heavy))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .foregroundStyle(state == .locked ? Color.white.opacity(0.62) : Color.white.opacity(0.92))
                .lineLimit(1)
            Text(stage.name)
                .font(.system(size: 9, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
            // Glifo: a cada 10 níveis, um BAÚ no lugar do cadeado/ícone — cinza
            // (bloqueado) ou dourado aceso (nível alcançado = abrível). Rafael 2026-07-14.
            if let cl = chestLevel(for: stage), let ch = skins.chest(level: cl), !ch.claimed {
                TreasureChestView(open: false, accent: .clear, width: size * 0.66)
                    .grayscale(ch.unlocked ? 0 : 1)
                    .opacity(ch.unlocked ? 1 : 0.7)
                    .shadow(color: ch.unlocked ? Color(red: 1, green: 0.82, blue: 0.35).opacity(0.7) : .clear,  // ds-allow: baú na trilha (arte gamificada) — visual signature
                            radius: ch.unlocked ? 9 : 0)
            } else {
                Image(systemName: locked ? "lock.fill" : stage.icon)
                    .font(.system(size: size * 0.40, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .foregroundStyle(locked ? Color.white.opacity(0.85) : .white)
            }
            // selo de concluído (check branco em disco escuro)
            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
        VitaMascotEquipped(state: .awake, size: 58, bounceEnabled: false)
    }

    // MARK: - Estado + ações

    /// Pula o bonequinho de no em no: agacha+estica na decolagem, desliza pelo arco
    /// (matchedGeometry move quando mascotLevel troca de no) e aterrissa quicando.
    // MARK: - Demo da passagem de seção (grava o portão abrindo + Vita atravessando)
    private func runLevelUpDemo(_ proxy: ScrollViewProxy) {
        demoLevel = 19
        mascotLevel = 19
        func cycle() {
            // estado inicial: portão da seção 2 FECHADO, Vita no último nó da seção 1
            demoLevel = 19
            mascotLevel = 19
            withAnimation(.easeInOut(duration: 0.7)) { proxy.scrollTo("stage-5", anchor: .center) }
            // sobe de nível: portão ABRE
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.85)) { demoLevel = 20 }
                // Vita atravessa o portão aberto (hopMascot já espera o portão)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hopMascot(to: 20) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { cycle() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { cycle() }
    }

    private func hopMascot(to newLevel: Int) {
        guard newLevel != mascotLevel else { return }
        // Atravessou uma fronteira de seção? Espera o portão abrir (0.8s) antes de
        // o Vita passar (Rafael 2026-07-05: "o vita espera o portão abrir e atravessa").
        let from = mascotLevel
        let crossed = Self.tiers.contains { $0.minLevel > 0 && from < $0.minLevel && newLevel >= $0.minLevel }
        if crossed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { self.doHop(to: newLevel) }
        } else {
            doHop(to: newLevel)
        }
    }

    private func doHop(to newLevel: Int) {
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
        // Fase (tier 0-4) cuja LOJA este prédio abre ao ser tocado. nil = só decoração.
        var shopTier: Int? = nil
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
                        .font(.system(size: 16, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: VitaColors.accent.opacity(pulse ? 0.44 : 0.18), radius: pulse ? 16 : 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(event.xpAwarded) XP")
                        .font(.system(size: 19, weight: .black, design: .rounded))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .foregroundStyle(VitaColors.accentLight)
                        .monospacedDigit()
                    Text(event.toLevel > event.fromLevel ? "Vita avançou para o nível \(event.toLevel)" : "\(event.source.label) concluído")
                        .font(.system(size: 11, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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

                RoundedRectangle(cornerRadius: 8, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .stroke(Color.white.opacity(0.48), lineWidth: 1)
                    )
                    .offset(y: 3)

                Circle()
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 8, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -17)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .fill(idx == 1 ? Color.white.opacity(0.68) : TrailWorld.windowGlow.opacity(0.74))
                            .frame(width: 12, height: 14)
                    }
                }
                .offset(y: 7)

                RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.wood.opacity(0.78))
                    .frame(width: 18, height: 24)
                    .offset(y: 25)

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .frame(width: 86, height: 5)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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

                RoundedRectangle(cornerRadius: 9, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                            RoundedRectangle(cornerRadius: 2, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                                .fill(TrailWorld.wood.opacity(0.58))
                                .frame(width: 12, height: 5)
                        }
                        .opacity(idx == 2 ? 1 : 0.92)
                    }
                }
                .offset(y: 3)

                RoundedRectangle(cornerRadius: 3, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.wood.opacity(0.80))
                    .frame(width: 22, height: 25)
                    .offset(y: 24)

                RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.wood.opacity(0.78))
                    .frame(width: 108, height: 8)
                    .offset(y: 39)

                Circle()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 11, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -36)
            }
        }

        private var healthPost: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 6, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                    RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .fill(TrailWorld.windowGlow.opacity(0.62))
                        .frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .fill(TrailWorld.windowDim.opacity(0.62))
                        .frame(width: 20, height: 26)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .fill(TrailWorld.windowGlow.opacity(0.62))
                        .frame(width: 18, height: 18)
                }
                .offset(y: 10)

                Image(systemName: "cross.fill")
                    .font(.system(size: 18, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .foregroundStyle(TrailWorld.crossRed)
                    .offset(y: -5)

                RoundedRectangle(cornerRadius: 3, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.wood.opacity(0.66))
                    .frame(width: 96, height: 7)
                    .offset(y: 34)
            }
        }

        private var majorHospital: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.stoneWing)
                    .frame(width: 38, height: 62)
                    .offset(x: -42, y: 10)
                RoundedRectangle(cornerRadius: 10, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.stoneWing)
                    .frame(width: 38, height: 62)
                    .offset(x: 42, y: 10)

                RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        .font(.system(size: 23, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .foregroundStyle(TrailWorld.crossRed)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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

                RoundedRectangle(cornerRadius: 5, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.wood.opacity(0.76))
                    .frame(width: 122, height: 9)
                    .offset(y: 53)

                Circle()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("H")
                            .font(.system(size: 15, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .foregroundStyle(TrailWorld.signTint)
                    )
                    .offset(y: -50)
            }
        }

        private var hospitalWindow: some View {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .fill(TrailWorld.windowGlow.opacity(0.52))
                .frame(width: 10, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.5)
                )
        }

        private var ambulance: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .stroke(Color.white.opacity(0.54), lineWidth: 1)
                    )
                RoundedRectangle(cornerRadius: 5, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .fill(TrailWorld.windowGlow.opacity(0.62))
                    .frame(width: 22, height: 13)
                    .offset(x: 18, y: -5)
                Image(systemName: "cross.fill")
                    .font(.system(size: 13, weight: .black))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .stroke(Color.white.opacity(0.46), lineWidth: 1)
                    )
                Image(systemName: "testtube.2")
                    .font(.system(size: 25, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
                        RoundedRectangle(cornerRadius: 16, style: .continuous)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            .stroke(Color.white.opacity(0.44), lineWidth: 1)
                    )
                Image(systemName: "stethoscope")
                    .font(.system(size: 25, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .foregroundStyle(Color.white.opacity(0.92))
                    .offset(y: -2)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
        // shopTier 0-4 = a loja da fase (Calouro/Acadêmico/Residente/Especialista/Lenda).
        Landmark(id: "sec1-school",     kind: .school,        side: .leading,  row: 2,  scale: 1.02, opacity: 0.95, shopTier: 0),
        Landmark(id: "sec2-university", kind: .university,    side: .trailing, row: 6,  scale: 1.02, opacity: 0.93, shopTier: 1),
        Landmark(id: "sec3-healthpost", kind: .healthPost,    side: .leading,  row: 10, scale: 1.00, opacity: 0.92, shopTier: 2),
        Landmark(id: "sec4-hospital",   kind: .majorHospital, side: .trailing, row: 14, scale: 1.00, opacity: 0.92, shopTier: 3),
        Landmark(id: "sec5-clinic",     kind: .clinic,        side: .leading,  row: 18, scale: 0.98, opacity: 0.90, shopTier: 4),
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
                ctx.fill(Path(roundedRect: trunk, cornerRadius: 3 * scale),  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
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
    let tier: HomeScreen.Tier
    let number: Int
    var isOpen: Bool = false

    private let wallY: CGFloat = 66   // centro vertical da muralha no componente

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gap: CGFloat = 50
            ZStack {
                gate(gap: gap)                 // ATRÁS do muro: desliza e some atrás dele
                rampart(width: w, gap: gap)
                pillar(at: archX - gap)
                pillar(at: archX + gap)
                wallInscription(width: w, gap: gap)   // texto GRAVADO na pedra
            }
            .animation(.easeInOut(duration: 0.85), value: isOpen)
        }
    }

    // MARK: muralha ALTA na cor da seção (pedra + ameias no topo)
    private func rampart(width w: CGFloat, gap: CGFloat) -> some View {
        // Muralha em DOIS segmentos com um VÃO no meio (onde fica o portão) —
        // assim, portão aberto = a estrada aparece pelo vão, não mais parede
        // atrás (Rafael 2026-07-05).
        ZStack {
            wallSegment(x0: 0, x1: max(0, archX - gap))
            wallSegment(x0: min(w, archX + gap), x1: w)
        }
    }

    private func wallSegment(x0: CGFloat, x1: CGFloat) -> some View {
        let len = max(0, x1 - x0)
        let bodyH: CGFloat = 42
        let merlons = max(0, Int((len - 4) / 25))   // ameias que cabem no segmento
        return ZStack(alignment: .top) {
            HStack(spacing: 10) {
                ForEach(0..<merlons, id: \.self) { _ in
                    UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                        .fill(LinearGradient(colors: [tier.mid, tier.dark],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 15, height: 14)
                }
            }
            .frame(width: len)
            .offset(y: -10)
            Rectangle()
                .fill(LinearGradient(colors: [tier.mid.opacity(0.92), tier.dark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: len, height: bodyH)
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
        .frame(width: len, alignment: .top)
        .position(x: x0 + len / 2, y: wallY)
        .shadow(color: .black.opacity(0.42), radius: 7, y: 6)
    }

    // MARK: nome GRAVADO na pedra do muro (sem card) — no maior segmento, ao lado do portão.
    private func wallInscription(width w: CGFloat, gap: CGFloat) -> some View {
        // maior segmento = lado oposto ao portão
        let leftLen = max(0, archX - gap)
        let rightLen = max(0, w - (archX + gap))
        let onLeft = leftLen >= rightLen
        let segLen = onLeft ? leftLen : rightLen
        let cx = onLeft ? leftLen / 2 : (archX + gap) + rightLen / 2
        // Lettering de monumento: marfim quente ENTALHADO na pedra (sombra escura
        // em cima = recesso, luz fraca embaixo = aresta iluminada). Lê em qualquer
        // cor de seção; sem o ouro que abafava no verde (Rafael 2026-07-05).
        return Text("SEÇÃO \(number) · \(tier.name.uppercased())")
            .font(.system(size: 11, weight: .black)).kerning(0.5) // ds-allow: inscrição gravada na muralha (arte), não UI
            .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.85))   // marfim quente // ds-allow: inscrição gravada na muralha (arte), não UI
            .shadow(color: .black.opacity(0.55), radius: 0, y: 1.2)       // recesso (entalhe)
            .shadow(color: .white.opacity(0.12), radius: 0, y: -0.6)      // aresta iluminada
            .frame(width: max(40, segLen - 12))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .position(x: cx, y: wallY)
    }

    // MARK: portão (2 batentes que DESLIZAM pro lado e somem atrás do muro)
    private func gate(gap: CGFloat) -> some View {
        ZStack {
            doorLeaf(width: gap, isLeft: true,  centerX: archX - gap / 2)
            doorLeaf(width: gap, isLeft: false, centerX: archX + gap / 2)
        }
    }

    private func doorLeaf(width: CGFloat, isLeft: Bool, centerX: CGFloat) -> some View {
        return RoundedRectangle(cornerRadius: 3, style: .continuous) // ds-allow: arte do portão da fortaleza, não UI
            .fill(LinearGradient(colors: [TrailWorld.wood, TrailWorld.stoneBottom],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: 34)
            .overlay(  // tábuas verticais (madeira)
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(Color.black.opacity(0.12)).frame(width: 0.8)
                        Spacer()
                    }
                }.padding(.horizontal, 4)
            )
            .overlay(  // reforço na cor da seção
                VStack(spacing: 10) {
                    Capsule().fill(tier.bright.opacity(0.7)).frame(height: 2)
                    Capsule().fill(tier.bright.opacity(0.7)).frame(height: 2)
                }
                .padding(.horizontal, 5)
            )
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous) // ds-allow: arte do portão da fortaleza, não UI
                .strokeBorder(tier.bright.opacity(0.30), lineWidth: 0.6))
            .overlay(  // argola na borda que se encontra no meio (fechado)
                Circle().fill(TrailWorld.windowGlow)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: TrailWorld.windowGlow.opacity(0.8), radius: 2)
                    .position(x: isLeft ? width - 4 : 4, y: 17)
            )
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            // DESLIZA pro lado (pro pilar) e some atrás do muro
            .offset(x: isOpen ? (isLeft ? -width : width) : 0)
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

// MARK: - SkinAppearanceScreen — tela "Aparência" (guarda-roupa de skins).
// Modelo HÍBRIDO (Rafael 2026-07-09), server-authoritative via SkinStore (/api/skins):
// acessório = nível ABRE + moeda COMPRA; cor = grátis por JORNADA (desbloqueia por
// nível). Reproduz o mock aprovado: Vita + pedestal de luz à esquerda; itens em cards
// à direita (check no equipado, cadeado+"Nível X" no travado, preço no comprável);
// ficha (nome · raridade · descrição) + botões Remover/Equipar/Comprar. 4 abas.
// O backend é a verdade: nível/preço/posse/trava vêm de lá; a UI só reflete e obedece.
struct SkinAppearanceScreen: View {
    /// nil = guarda-roupa COMPLETO (aberto tocando no Vita: inventário + tudo comprável).
    /// 0-4 = LOJA de uma fase (aberta tocando num prédio da trilha): mostra só os itens
    /// cujo nível de desbloqueio cai na faixa daquele tier.
    var shopTier: Int? = nil

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router
    @StateObject private var store = SkinStore()

    // Fase (tier) da loja: nome + faixa de nível + ambiente (arte de fundo) + atendente
    // (um Vita temático que "atende" a loja) + fala roteirizada. Índice = shopTier.
    // Espelha os TIERS do gamification e os 5 prédios da trilha.
    private struct TierShop {
        let name: String
        let range: ClosedRange<Int>
        let asset: String            // arte de fundo do ambiente (Assets.xcassets)
        let greeting: String         // fala do atendente
        let attendant: [MascotAccessory] // como o Vita-atendente se veste
    }
    private static let tiers: [TierShop] = [
        .init(name: "Calouro", range: 1...20, asset: "loja-escola",
              greeting: "E aí, calouro! Bora te montar pro primeiro dia. Dá uma olhada 👀",
              attendant: [.gradCap, .glassesRect]),   // atendente = PROFESSOR (capelo + óculos sérios) — Rafael 2026-07-14
        .init(name: "Acadêmico", range: 21...40, asset: "loja-faculdade",
              greeting: "Subiu de nível, hein? Chegou coisa nova na faculdade.",
              attendant: [.labCoat]),
        .init(name: "Residente", range: 41...60, asset: "loja-posto",
              greeting: "Plantonista raiz merece um visual à altura. Escolhe aí.",
              attendant: [.stethoscope]),
        .init(name: "Especialista", range: 61...80, asset: "loja-hospital",
              greeting: "Especialista na área… temos peças à altura do seu nome.",
              attendant: [.headMirror]),
        .init(name: "Lenda", range: 81...99, asset: "loja-clinica",
              greeting: "Poucos chegam aqui. Vista-se como a lenda que você é.",
              attendant: [.laurel]),
    ]
    private var shopTierInfo: TierShop? {
        guard let t = shopTier, Self.tiers.indices.contains(t) else { return nil }
        return Self.tiers[t]
    }

    // Aba da UI (PT-BR) ↔ slot do backend (EN). "Corpo" = slot `neck` no backend (Rafael 2026-07-14).
    private enum Slot: String, CaseIterable, Identifiable {
        case head = "Cabeça", face = "Rosto", neck = "Corpo", color = "Cor"
        var id: String { rawValue }
        var api: String {
            switch self {
            case .head: return "head"
            case .face: return "face"
            case .neck: return "neck"
            case .color: return "palette"
            }
        }
        var icon: String {
            switch self {
            case .head: return "crown.fill"
            case .face: return "eyeglasses"
            case .neck: return "stethoscope"
            case .color: return "paintpalette.fill"
            }
        }
    }

    // Flavor text local por id (o backend só manda nome/raridade/nível — a descrição
    // é charme da UI). Sem entrada = sem descrição (degrada limpo).
    private static let descById: [String: String] = [
        "bouffantCap": "Confortável e charmosa.\nPerfeita para dias tranquilos.",
        "beanie": "Gorro quentinho de inverno.\nPra virar a noite estudando.",
        "gradCap": "Capelo de formatura.\nO sonho tá logo ali.",
        "headMirror": "Refletor de testa.\nModo investigação clínica.",
        "laurel": "Coroa de louros.\nHonra acadêmica.",
        "capybaraHat": "Chapéu de capivara.\nO easter egg dourado.",
        "crown": "Coroa.\nTopo do ranking: Lenda.",
        "glassesRound": "Óculos redondos discretos.\nAr de quem lê muito.",
        "glassesRect": "Armação reta e séria.\nModo foco total.",
        "surgicalMask": "Máscara cirúrgica.\nPronto pro plantão.",
        "monocle": "Monóculo refinado.\nUm toque de nobreza.",
        "sunglasses": "Óculos de sol aviador.\nEstilo de quem já rodou.",
        "stethoscope": "Estetoscópio no pescoço.\nO clássico da medicina.",
        "labCoat": "Gola de jaleco branco.\nDr(a). Vita a postos.",
        "scarf": "Cachecol aconchegante.\nEstilo sem esforço.",
        "bowTie": "Gravata-borboleta.\nDefenda a tese com classe.",
        "goldMedal": "Medalha de ouro.\nCampeão dos estudos.",
        "vita": "A cor inicial do Vita.\nO ouro de todo começo.",
        "emerald": "Verde de quem avançou.\nRecompensa de jornada.",
        "sapphire": "Azul de quem persiste.\nRecompensa de jornada.",
        "amethyst": "Roxo de quem domina.\nRecompensa de jornada.",
        "ruby": "Vermelho de lenda.\nRecompensa de jornada.",
    ]

    private let gold = Color(red: 0.91, green: 0.72, blue: 0.29)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
    private let inkOnGold = Color(red: 0.20, green: 0.15, blue: 0.03)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature

    @State private var slot: Slot = .head
    // Preview (o que o usuário selecionou mas ainda não equipou): slotApi -> id.
    @State private var selectedId: [String: String] = [:]
    // Caixa Misteriosa: quando != nil, mostra o overlay de revelação da skin ganha.
    @State private var lootboxReveal: LootboxResult?
    @State private var didAutoBox = false   // QA: --vita-open-lootbox abre a caixa 1× (testar sem tap)

    // MARK: - Derivados do store

    private var itemsForSlot: [SkinStoreItem] {
        let all = store.items(slot: slot.api)
        // ACUMULADO: a loja da fase mostra tudo desbloqueado ATÉ o teto do tier (não
        // só a fatia) — assim Acadêmico/Residente/Lenda não ficam vazias. Rafael 2026-07-14.
        guard let range = shopTierInfo?.range else { return all }
        return all.filter { $0.unlockLevel <= range.upperBound }
    }

    /// Cadeado do item. Em PROD usa a verdade do backend (`it.locked`, calculado com
    /// `levelForXp` da conta). Em QA (`--vita-level=N`) recalcula contra o nível
    /// simulado pra a loja bater com o mapa/badge — prod fica INTOCADO. Rafael 2026-07-14.
    private func isLocked(_ it: SkinStoreItem) -> Bool {
        if it.owned { return false }
        if let lv = VitaDebug.forcedLevel { return lv < it.unlockLevel }
        return it.locked
    }

    /// Item em foco no slot atual (dentro do que está VISÍVEL na aba/fase): o selecionado,
    /// senão o equipado se ele pertence à fase, senão o primeiro item da aba.
    private var focusItem: SkinStoreItem? {
        let pool = itemsForSlot
        if let sel = selectedId[slot.api], let it = pool.first(where: { $0.id == sel }) { return it }
        if let eqId = store.equippedId(slot: slot.api), let it = pool.first(where: { $0.id == eqId }) { return it }
        return pool.first
    }

    private func chosenId(_ slotApi: String) -> String? {
        selectedId[slotApi] ?? store.equippedId(slot: slotApi)
    }

    private func isEquipped(_ it: SkinStoreItem) -> Bool {
        store.equippedId(slot: it.slot) == it.id
    }

    private var previewAccessories: [MascotAccessory] {
        ["neck", "head", "face"].compactMap { s in
            guard let id = chosenId(s) else { return nil }
            return MascotAccessory(rawValue: id)
        }
    }

    private var previewPalette: MascotPalette { palette(for: chosenId("palette")) }

    private func palette(for id: String?) -> MascotPalette {
        switch id {
        case "emerald": return .emerald
        case "sapphire": return .sapphire
        case "ruby": return .ruby
        case "amethyst": return .amethyst
        default: return .vita
        }
    }

    private func rarityLabel(_ r: String) -> String {
        switch r {
        case "legendary": return "Lendária"
        case "rare": return "Rara"
        case "epic": return "Épica"
        default: return "Comum"
        }
    }
    private func rarityColor(_ r: String) -> Color {
        switch r {
        case "legendary": return Color(red: 1.0, green: 0.82, blue: 0.32)  // ds-allow: raridade lendária da loja
        case "rare": return Color(red: 0.42, green: 0.68, blue: 0.98)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
        case "epic": return Color(red: 0.80, green: 0.56, blue: 0.98)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
        default: return Color(red: 0.36, green: 0.84, blue: 0.64)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            if store.catalog.isEmpty {
                ProgressView().tint(gold)
            } else {
                VStack(spacing: 0) {
                    header
                    // NPC/saudação e card da Caixa saíram da loja — os baús vão pro
                    // mapa (abertos com chave). Rafael 2026-07-14.
                    tabsBar
                    HStack(alignment: .top, spacing: 12) {
                        leftPane
                        rightList.frame(width: 88)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 26)   // puxa os cards da direita pra dentro (não vazam)
                    .padding(.top, 6)
                    // Limpa a TabBar (overlay ~92pt): ficha (descricao) e os cards
                    // de baixo nao ficam mais escondidos atras da barra. Rafael 2026-07-13.
                    .padding(.bottom, 92)
                }
            }
        }
        // Caixa Misteriosa: revelação em TELA CHEIA (cobre a TabBar também).
        .fullScreenCover(item: $lootboxReveal) { reveal in
            LootboxRevealView(
                result: reveal,
                onEquip: { equipWonSkin(reveal); lootboxReveal = nil },
                onClose: { lootboxReveal = nil }
            )
        }
        .task {
            await store.load(api: container.api)
            // QA: abre a Caixa 1× automaticamente pra testar o reveal sem tap.
            if ProcessInfo.processInfo.arguments.contains("--vita-open-lootbox"),
               !didAutoBox, lootboxReveal == nil {
                didAutoBox = true
                if let won = await store.openLootbox(api: container.api) {
                    withAnimation(.easeInOut(duration: 0.2)) { lootboxReveal = won }
                }
            }
            // QA: reveal FAKE (sem backend) só pra ver a arte do baú por raridade.
            if ProcessInfo.processInfo.arguments.contains("--vita-fake-reveal"),
               !didAutoBox, lootboxReveal == nil {
                didAutoBox = true
                let fid = ProcessInfo.processInfo.arguments
                    .first(where: { $0.hasPrefix("--vita-fake-skin=") })
                    .map { String($0.dropFirst("--vita-fake-skin=".count)) } ?? "halo"
                if let it = store.item(id: fid) {
                    lootboxReveal = LootboxResult(
                        won: .init(id: it.id, slot: it.slot, name: it.name, rarity: it.rarity, unlockLevel: it.unlockLevel),
                        price: 150, balance: store.balance
                    )
                }
            }
        }
        .alert("Ops", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // Fundo: ambiente imersivo na loja (arte + escurecimento pra UI ler), ou o
    // palco preto+dourado no guarda-roupa completo.
    @ViewBuilder private var background: some View {
        if let shop = shopTierInfo {
            Image(shop.asset)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.58), .black.opacity(0.5), .black.opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [gold.opacity(0.26), .clear],
                           center: UnitPoint(x: 0.32, y: 0.46),
                           startRadius: 6, endRadius: 330)
                .ignoresSafeArea()
        }
    }

    // Atendente da loja: um Vita temático + balão com a fala roteirizada da fase.
    private func attendantBubble(_ shop: TierShop) -> some View {
        HStack(alignment: .top, spacing: 10) {
            OrbMascot(palette: .vita, size: 46, accessories: shop.attendant,
                      animated: false, bounceEnabled: false, bob: false)
            Text(shop.greeting)
                .font(.system(size: 13, weight: .medium))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.5)))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.3), lineWidth: 1))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - Header (voltar · título · saldo)

    private var header: some View {
        HStack(spacing: 10) {
            Button { router.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            Text(shopTierInfo.map { "Loja · \($0.name)" } ?? "Aparência")
                .font(.system(size: 22, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .foregroundColor(.white)
            Spacer()
            // Na loja: atalho pro guarda-roupa completo (o inventário junto).
            if shopTier != nil {
                Button { router.navigate(to: .skinAppearance(shopTier: nil)) } label: {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 14, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
            }
            // Saldo de moeda (mérito).
            HStack(spacing: 5) {
                CoinIcon(size: 15)
                Text("\(store.balance)")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.4)))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: - Caixa Misteriosa (reveal reusado; os baús vivem no mapa, em HomeScreen)

    /// Equipa a skin ganha na caixa, preservando os outros slots equipados.
    private func equipWonSkin(_ reveal: LootboxResult) {
        let won = reveal.won
        Task {
            await store.equip(
                head: won.slot == "head" ? won.id : store.equippedId(slot: "head"),
                face: won.slot == "face" ? won.id : store.equippedId(slot: "face"),
                neck: won.slot == "neck" ? won.id : store.equippedId(slot: "neck"),
                palette: store.equippedId(slot: "palette"),
                api: container.api
            )
            await appData.refreshProfileNow()   // Vita muda em TODAS as telas na hora
        }
    }

    // MARK: - Abas

    private var tabsBar: some View {
        HStack(spacing: 10) {
            ForEach(Slot.allCases) { s in
                Button { withAnimation(.easeInOut(duration: 0.18)) { slot = s } } label: {
                    VStack(spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon).font(.system(size: 13, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                            Text(s.rawValue).font(.system(size: 14, weight: slot == s ? .semibold : .regular))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                                .lineLimit(1).fixedSize()
                        }
                        .foregroundColor(slot == s ? gold : Color.white.opacity(0.45))
                        Rectangle()
                            .fill(slot == s ? gold : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    // MARK: - Painel esquerdo (Vita no pedestal + ficha/botões)

    private var leftPane: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 6)
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [gold.opacity(0.5), .clear], center: .center, startRadius: 2, endRadius: 90))
                    .frame(width: 150, height: 60).blur(radius: 8).offset(y: 86)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                Ellipse()
                    .stroke(gold.opacity(0.85), lineWidth: 3)
                    .frame(width: 128, height: 38).blur(radius: 0.6).offset(y: 86)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                OrbMascot(palette: previewPalette, size: 148, accessories: previewAccessories, animated: false, bounceEnabled: false, bob: false)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 12)
            fichaAndButtons
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var fichaAndButtons: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let it = focusItem {
                Text(it.name)
                    .font(.system(size: 24, weight: .bold)).foregroundColor(.white)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .lineLimit(1).minimumScaleFactor(0.7)   // nome nunca empurra a largura (evita vazar a lateral)
                HStack(spacing: 6) {
                    Text(slot == .color ? "Cor" : rarityLabel(it.rarity))
                        .foregroundColor(slot == .color ? Color.white.opacity(0.5) : rarityColor(it.rarity))
                    Text("·").foregroundColor(Color.white.opacity(0.35))
                    Text(slot == .color ? "Jornada" : "Nível \(it.unlockLevel)")
                        .foregroundColor(gold)
                }
                .font(.system(size: 14, weight: .medium))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                if let d = Self.descById[it.id] {
                    Text(d)
                        .font(.system(size: 14)).foregroundColor(Color.white.opacity(0.55))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Escolha um item")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.6))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
            }

            actionButtons
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)         // margem de segurança: nome/raridade nunca colam na borda esquerda
        .padding(.bottom, 10)
    }

    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 12) {
            // Remover (desequipa o slot atual) — só faz sentido se há algo equipado nele.
            Button { removeSlot() } label: {
                Text("Remover")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
            }
            .disabled(store.equippedId(slot: slot.api) == nil || store.isMutating)
            .opacity(store.equippedId(slot: slot.api) == nil ? 0.4 : 1)

            primaryButton
        }
    }

    /// Botão principal muda conforme o estado do item em foco:
    /// equipado → "Equipado ✓" · possuído → "Equipar" · travado → "Nível X" (cadeado)
    /// · comprável → "Comprar 💰preço".
    @ViewBuilder private var primaryButton: some View {
        let it = focusItem
        let equippedNow = it.map(isEquipped) ?? false
        let canEquip = (it?.owned ?? false) && !equippedNow
        let canBuy = it != nil && !it!.owned && !isLocked(it!) && it!.slot != "palette"
        let locked = it.map(isLocked) ?? false

        Button {
            if canBuy { buySelected() } else if canEquip { equipSelected() }
        } label: {
            HStack(spacing: 6) {
                if locked && !(it?.owned ?? false) {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    Text("Nível \(it?.unlockLevel ?? 0)")
                } else if canBuy {
                    CoinIcon(size: 13)
                    Text("Comprar \(it?.price ?? 0)")
                } else if equippedNow {
                    Text("Equipado ✓")
                } else {
                    Text("Equipar")
                }
            }
            .font(.system(size: 15, weight: .bold)).foregroundColor(inkOnGold)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(gold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
        }
        .disabled((!canBuy && !canEquip) || store.isMutating)
        .opacity((!canBuy && !canEquip) ? 0.5 : 1)
    }

    // MARK: - Lista de cards (direita)

    private var rightList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if itemsForSlot.isEmpty {
                    // Loja de fase sem itens deste slot (conteúdo por época — faltam desenhar).
                    Text("Nada nesta\nfase ainda")
                        .font(.system(size: 12, weight: .medium))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 40)
                } else {
                    ForEach(itemsForSlot) { item in itemCard(item) }
                }
            }
            .padding(.vertical, 2).padding(.bottom, 24)
        }
    }

    private func itemCard(_ item: SkinStoreItem) -> some View {
        let isSel = chosenId(slot.api) == item.id
        let showLock = isLocked(item)
        let orb: OrbMascot = slot == .color
            ? OrbMascot(palette: palette(for: item.id), size: 40, accessories: [], animated: false)
            : OrbMascot(palette: .vita, size: 40, accessories: MascotAccessory(rawValue: item.id).map { [$0] } ?? [], animated: false)
        return Button {
            // Não deixa selecionar o que está travado (nada a fazer com ele).
            guard !showLock else { return }
            selectedId[slot.api] = item.id
        } label: {
            cardBody(orb: orb, item: item, isSel: isSel, showLock: showLock)
        }
        .buttonStyle(.plain)
    }

    private func cardBody(orb: OrbMascot, item: SkinStoreItem, isSel: Bool, showLock: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.4))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                .overlay(RoundedRectangle(cornerRadius: 18)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .stroke(isSel ? gold : Color.white.opacity(0.12), lineWidth: isSel ? 2 : 1))
            VStack(spacing: 4) {
                orb.frame(width: 50, height: 50).drawingGroup().opacity(showLock ? 0.4 : 1)
                if showLock {
                    Text("Nível \(item.unlockLevel)")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(gold.opacity(0.85))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                } else if !item.owned && item.slot != "palette" {
                    // Comprável: mostra o preço.
                    HStack(spacing: 3) {
                        CoinIcon(size: 10)
                        Text("\(item.price)").font(.system(size: 10, weight: .semibold))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    }
                    .foregroundColor(gold.opacity(0.9))
                }
            }
            .padding(.vertical, 10).frame(maxWidth: .infinity)

            if showLock {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.8))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .padding(6).background(Circle().fill(Color.black.opacity(0.55))).padding(8)
            } else if isEquipped(item) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy)).foregroundColor(inkOnGold)  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .padding(5).background(Circle().fill(gold)).padding(8)
            } else if item.owned {
                // Possuído (equipável) mas não equipado agora — selinho discreto.
                Image(systemName: "circle.fill")
                    .font(.system(size: 7)).foregroundColor(gold.opacity(0.5))  // ds-allow: arte gamificada (trilha 3D + loja de skins) — visual signature
                    .padding(9)
            }
        }
        .frame(height: 84)
    }

    // MARK: - Ações (server-authoritative via store)

    /// Monta o estado COMPLETO equipado trocando só o slot atual pelo id dado (nil = tira).
    private func equipState(setting id: String?) -> (String?, String?, String?, String?) {
        var head = store.equipped.head
        var face = store.equipped.face
        var neck = store.equipped.neck
        var palette = store.equipped.palette
        switch slot.api {
        case "head": head = id
        case "face": face = id
        case "neck": neck = id
        case "palette": palette = id
        default: break
        }
        return (head, face, neck, palette)
    }

    private func equipSelected() {
        guard let it = focusItem, it.owned else { return }
        let (h, f, n, p) = equipState(setting: it.id)
        Task {
            let ok = await store.equip(head: h, face: f, neck: n, palette: p, api: container.api)
            if ok { selectedId[slot.api] = nil; await appData.refreshProfileNow() }
        }
    }

    private func removeSlot() {
        let (h, f, n, p) = equipState(setting: nil)
        Task {
            let ok = await store.equip(head: h, face: f, neck: n, palette: p, api: container.api)
            if ok { selectedId[slot.api] = nil; await appData.refreshProfileNow() }
        }
    }

    private func buySelected() {
        guard let it = focusItem, !it.owned, !isLocked(it) else { return }
        Task { await store.buy(id: it.id, api: container.api) }
    }
}
