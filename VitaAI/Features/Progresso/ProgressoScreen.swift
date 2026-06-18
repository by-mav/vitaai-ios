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

    // MARK: - Estrada sinuosa (atrás dos nós) — volume 3D com luz de cima.
    //
    // Camadas da estrada (fundo→frente), simulando espessura física:
    //   1. Sombra de contato projetada (black ~0.5, deslocada +8pt = chão)
    //   2. Face LATERAL/escura (stroke mais largo, cor escura, deslocada +5pt = espessura)
    //   3. Superfície LIT (stroke colorido por seção — a parte de cima que pega luz)
    //   4. Brilho de luz no topo (highlight branco semi-transparente — luz vinda de cima)
    //   5. Linha central tracejada (indica direção do caminho)
    private var trailRoad: some View {
        let road = TrailRoad(count: trailItems.count, stride: Self.rowStride,
                             amp: Self.rowAmp, freq: Self.rowFreq)
        // Cor POR SEÇÃO (stops travados nas fronteiras de 20 níveis) — cada
        // capítulo tem sua cor sólida, com troca nítida no portão. (Antes era 1
        // gradiente global que virava verde já no topo.)
        let litGrad  = LinearGradient(gradient: Self.sectionStops { $0.mid },  startPoint: .top, endPoint: .bottom)
        let darkGrad = LinearGradient(gradient: Self.sectionStops { $0.dark }, startPoint: .top, endPoint: .bottom)
        return ZStack {
            // 1 — Sombra de contato (a estrada flutua levemente sobre o fundo)
            road.stroke(Color.black.opacity(0.0),
                        style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.50), radius: 12, y: 8)

            // 2 — Face lateral (espessura: a borda de baixo que fica na sombra)
            road.stroke(
                darkGrad,
                style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round)
            )
            .offset(y: 5)

            // 3 — Superfície superior lit (a "mesa" da estrada, cor de seção)
            road.stroke(
                litGrad,
                style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
            )

            // 4 — Brilho especular no topo (luz de cima — só a faixa superior)
            road.stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.06), .clear],
                    startPoint: .top, endPoint: .center
                ),
                style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
            )

            // 5 — Linha central tracejada (crème/âmbar, indica a direção do caminho)
            road.stroke(
                Color(red: 0.98, green: 0.88, blue: 0.56).opacity(0.60),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [3, 13])
            )
        }
    }

    // MARK: - Fundo por capítulo (F3) — tinge sutilmente o starfield por seção,
    // pra cada "mundo" ter sua temperatura sem matar o fundo estrelado.
    private var sectionBackdrop: some View {
        LinearGradient(gradient: Self.sectionStops { $0.dark.opacity(0.30) },
                       startPoint: .top, endPoint: .bottom)
            .frame(height: CGFloat(trailItems.count) * Self.rowStride + 40)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    // MARK: - Portões de capítulo (F2) — a cada 20 níveis, placa 3D marca a virada
    // de seção ("Acadêmico", "Residente"…). A estrada passa por baixo (a peça
    // ocupa espaço sob luz de cima: espessura + especular + rim light + sombra).
    private var sectionGates: some View {
        let h = CGFloat(trailItems.count) * Self.rowStride + 40
        return ZStack(alignment: .top) {
            ForEach(1..<Self.tiers.count, id: \.self) { k in
                sectionGate(Self.tiers[k])
                    .offset(y: CGFloat(k * 4) * Self.rowStride - 22)
            }
        }
        .frame(height: h, alignment: .top)
        .allowsHitTesting(false)
    }

    private func sectionGate(_ tier: Tier) -> some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: 9) {
            Image(systemName: "chevron.up").font(.system(size: 10, weight: .black)).foregroundStyle(tier.bright)
            Text(tier.name.uppercased())
                .font(.system(size: 13, weight: .heavy)).kerning(2.5)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
            Image(systemName: "chevron.up").font(.system(size: 10, weight: .black)).foregroundStyle(tier.bright)
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(
            ZStack {
                shape.fill(tier.dark).offset(y: 4)                       // espessura (base na sombra)
                shape.fill(
                    LinearGradient(colors: [tier.bright.opacity(0.95), tier.mid, tier.dark],
                                   startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: .black.opacity(0.22), radius: 3, x: 0, y: -2))
                )
                shape.fill(LinearGradient(colors: [.white.opacity(0.38), .clear],
                                          startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)                              // especular no topo
                shape.strokeBorder(
                    LinearGradient(colors: [tier.bright.opacity(0.9), tier.dark.opacity(0.3)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1.2)  // rim light
            }
            .shadow(color: .black.opacity(0.45), radius: 10, y: 7)       // sombra de contato
            .shadow(color: tier.mid.opacity(0.40), radius: 16)           // glow da seção
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        sectionBackdrop
                        trailRoad
                        sectionGates
                        LazyVStack(spacing: 0) {
                            ForEach(Array(trailItems.enumerated()), id: \.element.id) { idx, item in
                                trailRow(item, rowIndex: idx)
                            }
                        }
                    }
                    .frame(height: CGFloat(trailItems.count) * Self.rowStride + 40)
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
        .overlay(alignment: .leading) {
            sideTools(left: true).padding(.leading, 6)
        }
        .overlay(alignment: .trailing) {
            sideTools(left: false).padding(.trailing, 6)
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

    // MARK: - Ferramentas nas laterais (2 de cada lado) — libera o centro pra trilha.
    // Esq: Flashcards + Simulados · Dir: Questões + Transcrição. (Rafael 2026-06-17)
    @ViewBuilder
    private func sideTools(left: Bool) -> some View {
        VStack(spacing: 14) {
            if left {
                toolButton("Flashcards", icon: "rectangle.on.rectangle.angled",
                           bright: Color(red: 0.78, green: 0.69, blue: 1.0), mid: VitaColors.toolFlashcards, dark: Color(red: 0.29, green: 0.23, blue: 0.63)) {
                    openStudy(.flashcardHome())
                }
                toolButton("Simulados", icon: "doc.text.magnifyingglass",
                           bright: Color(red: 0.56, green: 0.77, blue: 0.98), mid: VitaColors.toolSimulados, dark: Color(red: 0.10, green: 0.37, blue: 0.65)) {
                    openStudy(.simuladoHome)
                }
            } else {
                toolButton("Questões", icon: "checklist",
                           bright: VitaColors.accentHover, mid: VitaColors.accent, dark: VitaColors.accentDark) {
                    openStudy(.qbank)
                }
                toolButton("Transcrição", icon: "waveform",
                           bright: Color(red: 0.50, green: 0.88, blue: 0.83), mid: VitaColors.toolTranscricao, dark: Color(red: 0.08, green: 0.50, blue: 0.47)) {
                    openStudy(.transcricao)
                }
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
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(VitaColors.textSecondary)
                .lineLimit(1).fixedSize()
        }
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
                // Vita "em pé" EM CIMA do botão do nível atual (centralizado).
                mascot.offset(x: 0, y: -50)
            }
        }
    }

    // Medalhão premium 3D — 7 camadas, UMA fonte de luz fixa de CIMA.
    //
    // Camadas (fundo→frente):
    //   0. Anel pulsante (nível atual)
    //   1. Sombra de contato (contact drop shadow — "chão" embaixo da peça)
    //   2. Aro escuro (base deslocada — a borda inferior na sombra = espessura)
    //   3. Corpo com gradiente LUZ → BASE (top claro → base escura = luz de cima)
    //        — face da imagem 3D oficial para desbloqueado; cofre escuro para locked
    //        — inner shadow sutil no lado escuro (bevel)
    //   4. Destaque especular (arco branco translúcido perto do TOPO + blur)
    //   5. Rim light (stroke só no arco SUPERIOR, bright→clear)
    //   6. Conteúdo (ícone do cadeado ou render oficial) com micro drop-shadow
    //   7. Selo de concluído (badge canto superior direito)
    private func coin(stage: Stage, tier: Tier, state: StageState) -> some View {
        let locked = state == .locked
        let size: CGFloat = state == .current ? 78 : 62
        let radius: CGFloat = size * 0.30
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // Cores do medalhão por estado (dessaturado = cofre; full = tier)
        let bodyTop:  Color = locked ? Color(white: 0.26) : tier.bright.opacity(0.92)
        let bodyMid:  Color = locked ? Color(white: 0.17) : tier.mid
        let bodyBot:  Color = locked ? Color(white: 0.10) : tier.dark

        // Sombra de contato (PixioShadow.contact tokens)
        let contactShadow = PixioShadow.contact(dark: true)
        // Sombra ambiente (glow suave da cor do tier)
        let ambientGlow   = PixioShadow.glow(tier.mid, intensity: state == .current ? 0.45 : 0.22)

        return ZStack {
            // — 0. Anel pulsante (só no nível atual) ———————————————————————
            if state == .current {
                RoundedRectangle(cornerRadius: radius + 7, style: .continuous)
                    .stroke(tier.bright.opacity(0.55), lineWidth: 3.5)
                    .frame(width: size + 20, height: size + 20)
                    .scaleEffect(pulse ? 1.06 : 0.95)
                    .shadow(color: tier.mid.opacity(0.60), radius: 14)
                    .blendMode(.plusLighter)
            }

            // — 1. Sombra de contato: offset embaixo → parece flutuar sobre o chão
            shape
                .fill(Color.black.opacity(0))
                .frame(width: size, height: size)
                .offset(y: 7)
                .shadow(color: contactShadow.color, radius: contactShadow.radius,
                        x: contactShadow.x, y: contactShadow.y + 4)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 12)

            // — 2. Aro escuro (espessura — borda inferior na sombra)
            shape
                .fill(bodyBot.opacity(0.95))
                .frame(width: size, height: size)
                .offset(y: 5)

            // — 3. Corpo do medalhão: gradiente LUZ→BASE simulando luz de cima.
            //   Para desbloqueado a imagem oficial fica por cima deste gradiente.
            //   Inner shadow no lado sombra (bevel sutil).
            ZStack {
                // gradiente direcional (superfície pega luz vinda de cima)
                shape.fill(
                    LinearGradient(
                        colors: [bodyTop, bodyMid, bodyBot],
                        startPoint: .top, endPoint: .bottom
                    )
                    .shadow(.inner(color: .black.opacity(locked ? 0.30 : 0.18),
                                   radius: 4, x: -1, y: -2))
                )

                // face: imagem oficial (desbloqueado) ou cofre escuro (locked)
                if locked {
                    // cofre: radial escuro com inner shadow leve
                    shape.fill(
                        RadialGradient(
                            colors: [Color(white: 0.24), Color(white: 0.10)],
                            center: UnitPoint(x: 0.38, y: 0.30),
                            startRadius: 2, endRadius: size
                        )
                        .shadow(.inner(color: .black.opacity(0.45), radius: 5, x: -2, y: -3))
                    )
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(Color(white: 0.38))
                        .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                } else {
                    // render 3D oficial — clipa na shape do medalhão
                    Image(stage.asset)
                        .resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(shape)
                }
            }
            .frame(width: size, height: size)
            // glow suave da cor do tier (ambient occlusion colorida)
            .shadow(color: ambientGlow.color, radius: ambientGlow.radius,
                    x: ambientGlow.x, y: ambientGlow.y)

            // — 4. Destaque especular: arco branco translúcido perto do TOPO
            //   Ellipse pequena no terço superior, levemente desfocada → reflexo.
            Ellipse()
                .fill(Color.white.opacity(locked ? 0.08 : 0.42))
                .frame(width: size * 0.55, height: size * 0.22)
                .offset(x: 0, y: -(size * 0.26))
                .blur(radius: 3.5)
                .allowsHitTesting(false)
                .blendMode(.plusLighter)
                .frame(width: size, height: size)
                .clipShape(shape)

            // — 5. Rim light: stroke só no arco SUPERIOR (bright→clear top→mid)
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [tier.bright.opacity(locked ? 0.28 : 0.80),
                                 tier.mid.opacity(locked ? 0.10 : 0.35),
                                 .clear],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.8
                )
                .frame(width: size, height: size)
                .allowsHitTesting(false)

            // — 7. Selo de concluído (badge no canto superior direito)
            if state == .completed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                    .foregroundStyle(VitaColors.dataGreen)
                    .background(Circle().fill(Color.white).frame(width: 15, height: 15))
                    .shadow(color: .black.opacity(0.30), radius: 3, y: 1)
                    .offset(x: size * 0.36, y: -size * 0.36)
            }
        }
        .frame(width: size + 22, height: size + 22)
        // inclinação 3D: a trilha inteira vista num ângulo (não exatamente de
        // cima) — dá camada/profundidade de "jogo". Rafael 2026-06-17.
        .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0),
                          anchor: .center, perspective: 0.55)
    }

    private var mascot: some View {
        // O Vita REAL — IDÊNTICO ao VitaChat (VitaChatScreen:258) e ao onboarding:
        // OrbMascot, paleta gold, state .awake, grande (olhos + glow dourado, vivo).
        // Na TRILHA tem comportamento próprio: bounceEnabled=false (NÃO fica pulando
        // toda hora — só flutua/pisca/olha, calmo). TODO: saltar de nó em nó ao upar.
        OrbMascot(palette: .vita, state: .awake, size: 76, bounceEnabled: false)
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
