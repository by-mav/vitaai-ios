import SwiftUI

// MARK: - Semi3DHouse — casa-marco da trilha (Home) em vista 3/4, animável.
//
// Rafael 2026-07-14: as "casas" dos marcos (nível 7/28/48/68/98) redesenhadas
// semi-3D — parede lateral (profundidade) + luz do topo-esquerda + telhado de
// 2 águas + fumaça + porta que ABRE (aberta) ou fica trancada (cadeado). Tudo
// desenhado em Canvas pra poder animar a porta/janelas por nível. Cores 100%
// de TrailWorld (mesma família do mundo noturno dourado).
//
// Tradução fiel do mockup SVG (600x520). O Canvas desenha em coords lógicas
// 600x520 e escala uniforme pro frame.

// A jornada médica (ref Rafael 2026-07-14, conceito ChatGPT):
// Casa/Cursinho -> Faculdade -> Clínica-Escola -> Hospital Universitário ->
// Instituto de Especialidades (o auge). Cada estágio é um degrau real da formação.
enum HouseKind {
    case cursinho, faculdade, clinicaEscola, hospital, instituto

    var label: String {
        switch self {
        case .cursinho: return "Cursinho"
        case .faculdade: return "Faculdade"
        case .clinicaEscola: return "Clínica-Escola"
        case .hospital: return "Hospital Universitário"
        case .instituto: return "Instituto de Especialidades"
        }
    }
}

enum VehicleSprite { case car, ambulance }

// Relógio do mundo: dia/noite pela HORA DO CELULAR (>=18h ou <6h = noite).
// Args de debug pra eu testar cada estado no simulador.
enum WorldClock {
    static var isNight: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--vita-force-day") { return false }
        if args.contains("--vita-force-night") { return true }
        let h = Calendar.current.component(.hour, from: Date())
        return h < 6 || h >= 18
    }
}

struct Semi3DHouse: View {
    var kind: HouseKind = .cursinho
    /// true = alcançada (aberta, acesa). false = trancada (apagada, cadeado).
    var open: Bool = true
    var level: Int = 7

    var body: some View {
        ZStack {
            // PRÉDIO: Canvas ESTÁTICO e isolado (fora do TimelineView) — nunca é
            // reavaliado por frame, então NÃO volta o bob que a gente matou.
            Canvas { ctx, size in
                let s = min(size.width / 600, size.height / 520)
                ctx.translateBy(x: (size.width - 600 * s) / 2, y: (size.height - 520 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                draw(&ctx, t: 0)
            }
            .drawingGroup()

            // VEÍCULO: camada viva e SEPARADA. Faz uma viagem rara (sai e volta) e
            // fica parado o resto do tempo. Só ISTO anima — o prédio fica imóvel.
            if let v = vehicleSprite {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        let s = min(size.width / 600, size.height / 520)
                        ctx.translateBy(x: (size.width - 600 * s) / 2, y: (size.height - 520 * s) / 2)
                        ctx.scaleBy(x: s, y: s)
                        let now = tl.date.timeIntervalSinceReferenceDate
                        let isAmb = (v == .ambulance)
                        // ESPORÁDICO: uma saída a cada ~3.5min, carro e ambulância bem separados
                        let u = tripU(now, stagger: isAmb ? 105 : 0, dur: isAmb ? 8 : 6)
                        drawVehicle(&ctx, v, u: u, t: now)
                        if v == .car { drawChimneySmoke(&ctx, t: now) }   // fumaça da chaminé do Cursinho
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .accessibilityLabel("Casa \(kind.label), nível \(level), \(open ? "aberta" : "trancada")")
    }

    // Só Cursinho (carro) e Hospital (ambulância) têm veículo vivo.
    private var vehicleSprite: VehicleSprite? {
        guard open else { return nil }
        switch kind {
        case .cursinho: return .car
        case .hospital: return .ambulance
        default: return nil
        }
    }

    // Progresso 0→1 durante a viagem (janela `dur`); -1 = parado (resto do tempo,
    // ~1x/min). Derivado do relógio do TimelineView (anima liso, sem withAnimation).
    private func tripU(_ t: TimeInterval, stagger: Double, dur: Double) -> CGFloat {
        let period = 210.0   // ~3.5min entre saídas (bem esporádico, só pra dar vida)
        let local = (t + stagger).truncatingRemainder(dividingBy: period)
        guard local >= 0, local < dur else { return -1 }
        return CGFloat(local / dur)
    }

    private func drawVehicle(_ ctx: inout GraphicsContext, _ v: VehicleSprite, u: CGFloat, t: TimeInterval) {
        switch v {
        case .car:
            // sai da garagem, VIRA pro lado e vai embora pela ESQUERDA (no chão, não afunda); volta e entra.
            if u < 0 { drawGarageDoor(&ctx, openAmount: 0); return }   // guardado, porta fechada
            let leaving = u < 0.5
            let dx: CGFloat = leaving ? -(u * 2) * 300 : -(1 - u) * 2 * 300      // 0 → -300 (lateral) → 0
            let dy: CGFloat = 16 * min(1, u * 8) * min(1, (1 - u) * 8)           // desce só um tico ao sair
            var moved = ctx
            moved.translateBy(x: dx, y: dy)
            if leaving && u > 0.12 {   // indo pra esquerda = vira pra esquerda (flip no centro do carro ~x108)
                moved.translateBy(x: 108, y: 0); moved.scaleBy(x: -1, y: 1); moved.translateBy(x: -108, y: 0)
            }
            drawCarBody(&moved)
            drawGarageDoor(&ctx, openAmount: min(1, min(u, 1 - u) * 8))   // abre ao sair, fecha ao voltar
        case .ambulance:
            if u < 0 { drawAmbulanceBody(&ctx, blink: nil); return }   // parada, virada pra direita
            // ANDA de verdade: acelera pra direita e SAI da tela; volta virada pra esquerda
            let dist: CGFloat = 340
            let goingRight = u < 0.5
            let dx = goingRight ? (u * 2) * dist : (1 - u) * 2 * dist   // 0→dist→0
            var moved = ctx
            moved.translateBy(x: dx, y: 0)
            if !goingRight {   // vira pro lado certo na volta (flip no centro do sprite ~x494)
                moved.translateBy(x: 494, y: 0); moved.scaleBy(x: -1, y: 1); moved.translateBy(x: -494, y: 0)
            }
            drawAmbulanceBody(&moved, blink: sirenBlink(t))
        }
    }

    // sirene pisca ~3x/s alternando vermelho/teal (só quando a ambulância sai)
    private func sirenBlink(_ t: TimeInterval) -> Bool { t.truncatingRemainder(dividingBy: 0.6) < 0.3 }

    // Fumaça subindo da chaminé do Cursinho (camada viva — sobe sem travar o prédio).
    private func drawChimneySmoke(_ ctx: inout GraphicsContext, t: TimeInterval) {
        for i in 0..<4 {
            let f = Double(i)
            let rise = CGFloat((t * 15 + f * 17).truncatingRemainder(dividingBy: 68))   // 0..68, puffs defasados
            let drift = CGFloat(sin(t * 0.7 + f * 1.6)) * (4 + rise * 0.12)
            let y = 146 - rise                     // parte do topo da chaminé e sobe
            let grow = 13 + rise * 0.30
            let op = max(0.0, 0.30 * (1 - rise / 68))
            ctx.fill(Path(ellipseIn: CGRect(x: 329 + drift - grow / 2, y: y - grow / 2, width: grow, height: grow)),
                     with: .color(Color(red: 0.74, green: 0.70, blue: 0.62).opacity(op)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }
    }

    // porta basculante da garagem, na camada viva: fechada oculta o carro; sobe (enrola) ao abrir
    private func drawGarageDoor(_ ctx: inout GraphicsContext, openAmount: CGFloat) {
        let g = open ? 1.0 : 0.5
        let h = 42 * (1 - max(0, min(1, openAmount)))
        if h > 1.5 {
            ctx.fill(Path(roundedRect: CGRect(x: 58, y: 434, width: 100, height: h), cornerRadius: 2), with: .color(Color(red:0.22,green:0.18,blue:0.12).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            let n = max(1, Int(h / 9))
            for i in 1..<(n + 1) {
                ctx.stroke(Path { p in p.move(to: P(60, 434 + CGFloat(i) * 9)); p.addLine(to: P(156, 434 + CGFloat(i) * 9)) }, with: .color(.black.opacity(0.25 * g)), lineWidth: 1)
            }
        }
        ctx.stroke(Path(CGRect(x: 58, y: 434, width: 100, height: 42)), with: .color(Color(red:0.20,green:0.15,blue:0.10).opacity(g)), lineWidth: 2)   // moldura do vão  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    // MARK: helpers de cor (TrailWorld)
    private var frontTop: Color { open ? TrailWorld.stoneTop : dim(TrailWorld.stoneTop) }
    private var frontBot: Color { open ? TrailWorld.stoneBottom : dim(TrailWorld.stoneBottom) }
    private var sideTop: Color { open ? TrailWorld.stoneWing : dim(TrailWorld.stoneWing) }
    private var sideBot: Color { Color(red: 0.11, green: 0.088, blue: 0.062) }  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    private var roofTop: Color { open ? TrailWorld.roofTop : dim(TrailWorld.roofTop) }
    private var roofBot: Color { open ? TrailWorld.roofBottom : dim(TrailWorld.roofBottom) }
    private func dim(_ c: Color) -> Color { c.opacity(0.55) }

    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }; p.closeSubpath()
        return p
    }
    private func lg(_ a: Color, _ b: Color, _ p0: CGPoint, _ p1: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [a, b]), startPoint: p0, endPoint: p1)
    }

    // MARK: desenho
    private func draw(_ ctx: inout GraphicsContext, t: TimeInterval) {
        // cada prédio é desenhado como ELE MESMO
        if kind == .faculdade { drawUniversity(&ctx); return }
        if kind == .clinicaEscola { drawClinicaEscola(&ctx); return }
        if kind == .hospital { drawHospital(&ctx); return }
        if kind == .instituto { drawInstituto(&ctx); return }
        // sombra de contato
        ctx.fill(Path(ellipseIn: CGRect(x: 85, y: 456, width: 430, height: 34)), with: .color(.black.opacity(0.34)))

        // caminho de ouro até a porta
        ctx.fill(poly([P(252,520),P(348,520),P(330,432),P(270,432)]), with: .color(TrailWorld.roadEdge))
        ctx.fill(poly([P(266,520),P(334,520),P(322,432),P(278,432)]), with: .color(TrailWorld.roadSurface))

        // poça de luz da porta (só aberta)
        if open {
            ctx.fill(Path(ellipseIn: CGRect(x: 172, y: 396, width: 256, height: 112)),
                     with: .radialGradient(Gradient(colors: [Color(red:1,green:0.86,blue:0.55).opacity(0.62), .clear]),  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                                           center: P(300,404), startRadius: 2, endRadius: 142))
        }

        // parede lateral (sombra)
        ctx.fill(poly([P(372,250),P(446,214),P(446,428),P(372,462)]), with: lg(sideTop, sideBot, P(372,214), P(446,462)))

        // janela lateral
        drawWindow(&ctx, poly: [P(398,300),P(424,287),P(424,330),P(398,342)], t: t, phase: 0.5)

        // parede frontal (iluminada)
        ctx.fill(poly([P(156,250),P(372,250),P(372,462),P(156,462)]), with: lg(frontTop, frontBot, P(156,250), P(220,462)))
        // aresta de luz na quina esquerda
        ctx.fill(poly([P(156,250),P(161,250),P(161,462),P(156,462)]), with: .color(Color(red:0.48,green:0.39,blue:0.29).opacity(open ? 0.7 : 0.3)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // telhados
        ctx.fill(poly([P(264,150),P(336,120),P(470,206),P(372,250)]), with: lg(roofBot, Color(red:0.16,green:0.11,blue:0.06), P(264,120), P(470,250)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(132,256),P(264,150),P(396,256)]), with: lg(roofTop, roofBot, P(132,150), P(264,256)))
        // rim light dourado na cumeeira + beiral (luz do topo-esquerda pegando a aresta)
        if open {
            var ridge = Path(); ridge.move(to: P(132,256)); ridge.addLine(to: P(264,150)); ridge.addLine(to: P(336,120))
            ctx.stroke(ridge, with: .color(TrailWorld.tier0Bright.opacity(0.55)), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
            ctx.stroke(ridge, with: .color(Color(red:1,green:0.93,blue:0.72)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            // topo da parede frontal pegando luz
            ctx.stroke(Path { p in p.move(to: P(158,252)); p.addLine(to: P(370,252)) },
                       with: .color(TrailWorld.tier0Bright.opacity(0.35)), lineWidth: 2)
        }
        ctx.stroke(Path { p in p.move(to: P(132,256)); p.addLine(to: P(396,256)) }, with: .color(Color(red:0.35,green:0.26,blue:0.15)), lineWidth: 4)  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // chaminé (a FUMAÇA é animada na camada viva — drawChimneySmoke, não trava o prédio)
        ctx.fill(Path(CGRect(x: 314, y: 146, width: 30, height: 52)), with: .color(Color(red:0.34,green:0.24,blue:0.15)))   // corpo do tijolo  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 310, y: 142, width: 38, height: 9)), with: .color(Color(red:0.42,green:0.30,blue:0.18)))    // beiral/topo  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // janelas frontais (2 normais)
        drawWindow(&ctx, poly: [P(188,292),P(238,292),P(238,350),P(188,350)], t: t, phase: 0.0)
        drawWindow(&ctx, poly: [P(290,292),P(340,292),P(340,350),P(290,350)], t: t, phase: 0.9)

        // PORTA
        if open {
            // clarão do vão
            ctx.fill(Path(roundedRect: CGRect(x: 266, y: 372, width: 56, height: 90), cornerRadius: 4),
                     with: .radialGradient(Gradient(colors: [Color(red:1,green:0.95,blue:0.8), TrailWorld.windowGlow, TrailWorld.wood]),  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                                           center: P(294,420), startRadius: 2, endRadius: 66))
            // núcleo quente forte
            ctx.fill(Path(roundedRect: CGRect(x: 280, y: 396, width: 28, height: 62), cornerRadius: 3),
                     with: .color(Color(red:1,green:0.92,blue:0.74).opacity(0.9)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            // folha aberta pra fora + aresta iluminada
            ctx.fill(poly([P(266,372),P(244,360),P(244,458),P(266,462)]), with: .color(TrailWorld.wood))
            ctx.stroke(Path { p in p.move(to: P(266,372)); p.addLine(to: P(266,462)) },
                       with: .color(TrailWorld.windowGlow.opacity(0.8)), lineWidth: 2)
        } else {
            ctx.fill(Path(roundedRect: CGRect(x: 266, y: 372, width: 56, height: 90), cornerRadius: 4), with: .color(TrailWorld.wood))
            ctx.stroke(Path { p in p.move(to: P(294,372)); p.addLine(to: P(294,462)) }, with: .color(.black.opacity(0.3)), lineWidth: 2)
            // cadeado: arco (shackle) + corpo
            let lock = Color(red: 0.42, green: 0.35, blue: 0.27)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            ctx.stroke(Path(ellipseIn: CGRect(x: 288, y: 398, width: 12, height: 14)), with: .color(lock), lineWidth: 2.5)
            ctx.fill(Path(roundedRect: CGRect(x: 283, y: 406, width: 22, height: 16), cornerRadius: 3), with: .color(lock))
        }
        ctx.stroke(Path(roundedRect: CGRect(x: 262, y: 368, width: 64, height: 94), cornerRadius: 5), with: .color(Color(red:0.23,green:0.16,blue:0.09)), lineWidth: 4)  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // acentos por tema — a IDENTIDADE de cada prédio vem da arquitetura,
        // não de um ícone flutuante (Rafael 2026-07-14).
        drawAccents(&ctx)
    }

    // Janela grande do Cursinho: dá pra ver alguém estudando (estante, mesa,
    // luminária, aluno debruçado no livro). Recortada na janela.
    private func drawStudyRoomWindow(_ ctx: inout GraphicsContext, t: TimeInterval) {
        let frame = CGRect(x: 182, y: 286, width: 162, height: 80)
        let win = Path(roundedRect: frame, cornerRadius: 6)
        if open {
            ctx.fill(win, with: .linearGradient(Gradient(colors: [Color(red:1,green:0.87,blue:0.62), Color(red:0.82,green:0.57,blue:0.28)]),  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                                                startPoint: P(frame.minX, frame.minY), endPoint: P(frame.minX, frame.maxY)))
            ctx.drawLayer { l in
                l.clip(to: win)
                // chão do quarto
                l.fill(Path(CGRect(x: frame.minX, y: frame.maxY - 14, width: frame.width, height: 14)), with: .color(Color(red:0.52,green:0.34,blue:0.17)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                // estante à esquerda
                l.fill(Path(CGRect(x: frame.minX + 9, y: frame.minY + 14, width: 22, height: 44)), with: .color(Color(red:0.40,green:0.27,blue:0.14)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                for r in 0..<3 {
                    l.fill(Path(CGRect(x: frame.minX + 11, y: frame.minY + 18 + CGFloat(r)*13, width: 18, height: 3)), with: .color(Color(red:0.92,green:0.72,blue:0.42)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                }
                // mesa
                l.fill(Path(CGRect(x: frame.midX - 10, y: frame.maxY - 30, width: 82, height: 7)), with: .color(Color(red:0.44,green:0.29,blue:0.15)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                // luminária: cone de luz + cúpula
                let lampX = frame.maxX - 22
                l.fill(poly([P(lampX-12, frame.maxY-29),P(lampX+12, frame.maxY-29),P(lampX+7, frame.maxY-48),P(lampX-7, frame.maxY-48)]),
                       with: .color(Color(red:1,green:0.93,blue:0.72).opacity(0.55)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                l.fill(Path(ellipseIn: CGRect(x: lampX-9, y: frame.maxY-54, width: 18, height: 9)), with: .color(Color(red:0.78,green:0.66,blue:0.45)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                // aluno debruçado no livro
                let hx = frame.midX + 6
                l.fill(Path(ellipseIn: CGRect(x: hx-7, y: frame.maxY-46, width: 14, height: 14)), with: .color(Color(red:0.28,green:0.20,blue:0.15)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                l.fill(poly([P(hx-12, frame.maxY-24),P(hx+12, frame.maxY-24),P(hx+9, frame.maxY-38),P(hx-5, frame.maxY-39)]), with: .color(Color(red:0.34,green:0.30,blue:0.46)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                // livro aberto na mesa
                l.fill(poly([P(hx+6, frame.maxY-30),P(hx+28, frame.maxY-32),P(hx+28, frame.maxY-25),P(hx+6, frame.maxY-23)]), with: .color(Color(red:0.95,green:0.92,blue:0.85)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            }
        } else {
            ctx.fill(win, with: .color(Color(red:0.16,green:0.13,blue:0.09)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }
        ctx.stroke(win, with: .color(Color(red:0.16,green:0.11,blue:0.07)), lineWidth: 3)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    private func drawAccents(_ ctx: inout GraphicsContext) {
        // (bandeira REMOVIDA — Rafael 2026-07-14)
        // garagem (estática) — o CARRO é desenhado na camada viva (drawCarBody)
        drawGarage(&ctx)
    }

    private func drawGarage(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.5
        // garagem MAIOR (cabe o carro) — a PORTA é desenhada na camada viva (drawGarageDoor)
        ctx.fill(poly([P(46,426),P(106,392),P(166,426)]), with: .color(Color(red:0.38,green:0.28,blue:0.16).opacity(g)))       // telhado  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 52, y: 426, width: 112, height: 50)), with: .color(Color(red:0.31,green:0.25,blue:0.17).opacity(g)))   // parede  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 58, y: 434, width: 100, height: 42)), with: .color(Color(red:0.09,green:0.07,blue:0.05).opacity(g)))    // vão escuro (carro fica dentro)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    // carrinho teal — desenhado na CAMADA VIVA (sai da garagem de vez em quando)
    private func drawCarBody(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.5
        let body = Color(red: 0.30, green: 0.62, blue: 0.66)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(ellipseIn: CGRect(x: 62, y: 476, width: 92, height: 12)), with: .color(.black.opacity(0.26 * g)))                  // sombra viaja junto
        ctx.fill(Path(roundedRect: CGRect(x: 82, y: 440, width: 50, height: 22), cornerRadius: 8), with: .color(body.opacity(g)))       // cabine
        ctx.fill(Path(roundedRect: CGRect(x: 60, y: 454, width: 96, height: 24), cornerRadius: 9), with: .color(body.opacity(g)))       // corpo
        ctx.fill(Path(roundedRect: CGRect(x: 90, y: 444, width: 38, height: 14), cornerRadius: 4), with: .color(TrailWorld.windowGlow.opacity(0.75 * g)))  // vidro
        ctx.fill(Path(ellipseIn: CGRect(x: 70, y: 470, width: 22, height: 22)), with: .color(TrailWorld.wheel))    // roda
        ctx.fill(Path(ellipseIn: CGRect(x: 124, y: 470, width: 22, height: 22)), with: .color(TrailWorld.wheel))   // roda
        ctx.fill(Path(ellipseIn: CGRect(x: 75, y: 475, width: 12, height: 12)), with: .color(Color(red:0.5,green:0.5,blue:0.5)))        // calota  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(ellipseIn: CGRect(x: 129, y: 475, width: 12, height: 12)), with: .color(Color(red:0.5,green:0.5,blue:0.5)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 152, y: 460, width: 9, height: 9)), with: .color(Color(red:1,green:0.9,blue:0.6))) }  // farol  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    // MARK: - FACULDADE (tijolo + ardósia + pórtico com colunas/arcos + janelas em arco)
    // Referência isométrica do Rafael, na luz quente/noturna do mundo. 2026-07-14.
    private func drawUniversity(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.55
        ctx.fill(Path(ellipseIn: CGRect(x: 88, y: 452, width: 440, height: 36)), with: .color(.black.opacity(0.34)))

        // tijolo — prédio GRANDE de 2 andares. lateral (sombra) + frontal (luz)
        let bfA = Color(red: 0.55, green: 0.33, blue: 0.26).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let bfB = Color(red: 0.36, green: 0.21, blue: 0.16).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let bsA = Color(red: 0.36, green: 0.21, blue: 0.16).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let bsB = Color(red: 0.23, green: 0.13, blue: 0.10).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(408,254),P(476,220),P(476,444),P(408,452)]), with: lg(bsA, bsB, P(408,220), P(476,452)))
        ctx.fill(Path(CGRect(x: 120, y: 254, width: 288, height: 198)), with: lg(bfA, bfB, P(120,254), P(180,452)))
        ctx.fill(Path(CGRect(x: 120, y: 254, width: 5, height: 198)), with: .color(Color(red:0.66,green:0.42,blue:0.32).opacity(g * 0.8)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // cornija de topo + faixa entre os 2 andares
        let cream = Color(red: 0.80, green: 0.72, blue: 0.58).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 112, y: 246, width: 304, height: 12)), with: .color(cream))
        ctx.fill(poly([P(408,254),P(476,220),P(484,214),P(416,248)]), with: .color(cream.opacity(0.85)))
        ctx.fill(Path(CGRect(x: 120, y: 350, width: 288, height: 7)), with: .color(cream.opacity(0.7)))

        // telhado de ardósia (hip) + rim dourado
        let sfA = Color(red: 0.46, green: 0.46, blue: 0.53).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let sfB = Color(red: 0.28, green: 0.28, blue: 0.35).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let ssA = Color(red: 0.30, green: 0.30, blue: 0.37).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let ssB = Color(red: 0.19, green: 0.19, blue: 0.25).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(110,248),P(178,180),P(360,180),P(416,248)]), with: lg(sfA, sfB, P(110,180), P(110,248)))
        ctx.fill(poly([P(416,248),P(360,180),P(440,150),P(500,214)]), with: lg(ssA, ssB, P(360,150), P(500,248)))
        if open {
            var ridge = Path(); ridge.move(to: P(110,248)); ridge.addLine(to: P(178,180)); ridge.addLine(to: P(360,180)); ridge.addLine(to: P(440,150))
            ctx.stroke(ridge, with: .color(TrailWorld.tier0Bright.opacity(0.55)), style: StrokeStyle(lineWidth: 2.8, lineJoin: .round))
        }

        // 2 ANDARES de janelas em arco (esq + dir do pórtico)
        for y in [CGFloat(266), 362] {
            for x in [CGFloat(136), 170] { archWindow(&ctx, x: x, y: y, w: 24, h: 68) }
            for x in [CGFloat(352), 384] { archWindow(&ctx, x: x, y: y, w: 22, h: 68) }
        }

        // ==== PÓRTICO ROBUSTO (projeta, 2 andares de altura) ====
        ctx.fill(poly([P(208,340),P(288,300),P(368,340)]), with: .color(cream))                 // frontão maior
        ctx.fill(Path(CGRect(x: 210, y: 338, width: 156, height: 12)), with: .color(cream.opacity(0.92)))  // entablamento
        let col = Color(red: 0.80, green: 0.72, blue: 0.58).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let colSh = Color(red: 0.56, green: 0.50, blue: 0.39).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        for cx in [CGFloat(216), 252, 320, 356] {
            ctx.fill(Path(roundedRect: CGRect(x: cx, y: 350, width: 18, height: 100), cornerRadius: 5), with: lg(col, colSh, P(cx,350), P(cx+18,450)))
            ctx.fill(Path(roundedRect: CGRect(x: cx-3, y: 346, width: 24, height: 8), cornerRadius: 2), with: .color(col))  // capitel
        }
        ctx.stroke(Path { p in p.addArc(center: P(295,380), radius: 26, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }, with: .color(cream), lineWidth: 4)
        // entrada grande iluminada
        if open {
            ctx.fill(Path(roundedRect: CGRect(x: 272, y: 384, width: 46, height: 66), cornerRadius: 5),
                     with: .radialGradient(Gradient(colors: [Color(red:1,green:0.94,blue:0.74), TrailWorld.windowGlow, TrailWorld.wood]), center: P(295,418), startRadius: 2, endRadius: 52))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        } else {
            ctx.fill(Path(roundedRect: CGRect(x: 272, y: 384, width: 46, height: 66), cornerRadius: 5), with: .color(TrailWorld.wood))
        }
        // escadaria larga
        ctx.fill(Path(roundedRect: CGRect(x: 236, y: 446, width: 118, height: 8), cornerRadius: 2), with: .color(cream.opacity(0.85)))
        ctx.fill(Path(roundedRect: CGRect(x: 220, y: 454, width: 150, height: 9), cornerRadius: 2), with: .color(cream.opacity(0.78)))

        if !open {
            let lock = Color(red: 0.42, green: 0.35, blue: 0.27)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            ctx.stroke(Path(ellipseIn: CGRect(x: 287, y: 400, width: 16, height: 18)), with: .color(lock), lineWidth: 3)
            ctx.fill(Path(roundedRect: CGRect(x: 281, y: 412, width: 28, height: 20), cornerRadius: 3), with: .color(lock))
        }
    }

    private func archWindow(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        var f = Path()
        f.move(to: P(x, y + w / 2))
        f.addArc(center: P(x + w / 2, y + w / 2), radius: w / 2, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        f.addLine(to: P(x + w, y + h))
        f.addLine(to: P(x, y + h))
        f.closeSubpath()
        if open {
            ctx.fill(f, with: .linearGradient(Gradient(colors: [Color(red:1,green:0.9,blue:0.66), Color(red:0.82,green:0.58,blue:0.28)]), startPoint: P(x, y), endPoint: P(x, y + h)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        } else {
            ctx.fill(f, with: .color(Color(red:0.16,green:0.13,blue:0.09)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }
        ctx.stroke(f, with: .color(Color(red:0.80,green:0.72,blue:0.58).opacity(open ? 1 : 0.5)), lineWidth: 2.5)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.stroke(Path { p in p.move(to: P(x + w / 2, y + w / 2)); p.addLine(to: P(x + w / 2, y + h)) }, with: .color(Color(red:0.12,green:0.09,blue:0.06)), lineWidth: 1.4)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    // MARK: - CLÍNICA-ESCOLA: prédio clínico com cruz verde, telhado 2 águas,
    // acento teal (clínico), marquise e rampa de acessibilidade. Rafael 2026-07-14.
    private func drawClinicaEscola(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.55
        ctx.fill(Path(ellipseIn: CGRect(x: 90, y: 452, width: 430, height: 34)), with: .color(.black.opacity(0.34)))

        // paredes claras/creme + lateral em sombra
        let wfA = Color(red: 0.62, green: 0.58, blue: 0.50).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wfB = Color(red: 0.42, green: 0.39, blue: 0.33).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wsA = Color(red: 0.40, green: 0.37, blue: 0.31).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wsB = Color(red: 0.26, green: 0.24, blue: 0.20).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(410,332),P(468,302),P(468,440),P(410,452)]), with: lg(wsA, wsB, P(410,302), P(468,452)))
        ctx.fill(Path(CGRect(x: 132, y: 332, width: 278, height: 120)), with: lg(wfA, wfB, P(132,332), P(180,452)))
        ctx.fill(Path(CGRect(x: 132, y: 332, width: 5, height: 120)), with: .color(Color(red:0.72,green:0.68,blue:0.58).opacity(g * 0.8)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // telhado baixo de 2 águas (hip) — posto TEM telhado agora (Rafael 2026-07-14)
        let rFA = Color(red: 0.40, green: 0.33, blue: 0.24).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let rFB = Color(red: 0.27, green: 0.22, blue: 0.16).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let rSA = Color(red: 0.27, green: 0.22, blue: 0.16).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let rSB = Color(red: 0.17, green: 0.14, blue: 0.10).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(108,338),P(166,276),P(384,276),P(438,338)]), with: lg(rFA, rFB, P(108,276), P(108,338)))
        ctx.fill(poly([P(438,338),P(384,276),P(456,250),P(500,312)]), with: lg(rSA, rSB, P(384,250), P(500,338)))
        ctx.fill(Path(CGRect(x: 108, y: 332, width: 330, height: 6)), with: .color(Color(red:0.72,green:0.68,blue:0.58).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        // faixa creme discreta (sem verde/teal aleatório — Rafael 2026-07-14)
        ctx.fill(Path(CGRect(x: 132, y: 338, width: 278, height: 6)), with: .color(Color(red:0.80,green:0.74,blue:0.60).opacity(g * 0.8)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        // CRUZ vermelha acesa (cor médica normal — Rafael 2026-07-14)
        let cross = open ? TrailWorld.crossRed : dim(TrailWorld.crossRed)
        if open {
            ctx.fill(Path(ellipseIn: CGRect(x: 150, y: 352, width: 60, height: 60)), with: .radialGradient(Gradient(colors:[TrailWorld.crossRed.opacity(0.35), .clear]), center: P(180,382), startRadius:1, endRadius:34))
        }
        ctx.fill(Path(roundedRect: CGRect(x: 172, y: 358, width: 16, height: 48), cornerRadius: 3), with: .color(cross))
        ctx.fill(Path(roundedRect: CGRect(x: 156, y: 374, width: 48, height: 16), cornerRadius: 3), with: .color(cross))

        // janelas horizontais acesas (direita)
        for x in [CGFloat(300), 348] {
            let r = CGRect(x: x, y: 362, width: 38, height: 30)
            if open {
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .linearGradient(Gradient(colors:[Color(red:1,green:0.9,blue:0.66),Color(red:0.82,green:0.58,blue:0.28)]), startPoint: P(x,362), endPoint: P(x,392)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            } else {
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(Color(red:0.16,green:0.13,blue:0.09)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            }
            ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(Color(red:0.72,green:0.68,blue:0.58).opacity(open ? 1 : 0.5)), lineWidth: 2)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }

        // (marquise verde REMOVIDA — Rafael 2026-07-14: deixa só a porta)
        // porta central iluminada
        if open {
            ctx.fill(Path(roundedRect: CGRect(x: 252, y: 414, width: 44, height: 38), cornerRadius: 4), with: .radialGradient(Gradient(colors:[Color(red:1,green:0.92,blue:0.72), TrailWorld.windowGlow.opacity(0.7), .clear]), center: P(274,434), startRadius:2, endRadius:36))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        } else {
            ctx.fill(Path(roundedRect: CGRect(x: 252, y: 414, width: 44, height: 38), cornerRadius: 4), with: .color(TrailWorld.wood))
        }
        // RAMPA de acessibilidade (esquerda) + corrimão
        ctx.fill(poly([P(150,452),P(252,452),P(252,440),P(206,440)]), with: .color(Color(red:0.50,green:0.47,blue:0.40).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.stroke(Path { p in p.move(to: P(154,446)); p.addLine(to: P(210,434)) }, with: .color(Color(red:0.70,green:0.66,blue:0.56).opacity(g)), lineWidth: 2.5)  // ds-allow: arte do mundo (predios semi-3D em Canvas)

        if !open {
            let lock = Color(red: 0.42, green: 0.35, blue: 0.27)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            ctx.stroke(Path(ellipseIn: CGRect(x: 266, y: 420, width: 14, height: 16)), with: .color(lock), lineWidth: 3)
            ctx.fill(Path(roundedRect: CGRect(x: 261, y: 430, width: 24, height: 18), cornerRadius: 3), with: .color(lock))
        }
    }

    // MARK: - HOSPITAL: torre alta, grade de janelas, cruz grande, entrada de EMERGÊNCIA.
    private func drawHospital(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.55
        ctx.fill(Path(ellipseIn: CGRect(x: 100, y: 452, width: 400, height: 34)), with: .color(.black.opacity(0.34)))
        // brilho ambiente premium
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 128, y: 168, width: 344, height: 320)), with: .radialGradient(Gradient(colors:[TrailWorld.windowGlow.opacity(0.10), .clear]), center: P(280,300), startRadius: 20, endRadius: 210)) }
        // torre warm-white premium + lateral
        let wfA = Color(red: 0.66, green: 0.63, blue: 0.58).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wfB = Color(red: 0.44, green: 0.42, blue: 0.38).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wsA = Color(red: 0.42, green: 0.40, blue: 0.36).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let wsB = Color(red: 0.27, green: 0.26, blue: 0.23).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(360,214),P(432,182),P(432,444),P(360,452)]), with: lg(wsA, wsB, P(360,182), P(432,452)))
        ctx.fill(Path(roundedRect: CGRect(x: 160, y: 214, width: 200, height: 238), cornerRadius: 8), with: lg(wfA, wfB, P(160,214), P(200,452)))
        // coroa moderna com acento teal (clínico)
        let accent = open ? TrailWorld.tier2Bright : dim(TrailWorld.tier2Bright)
        ctx.fill(Path(roundedRect: CGRect(x: 152, y: 200, width: 216, height: 16), cornerRadius: 4), with: .color(Color(red:0.32,green:0.31,blue:0.29).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 160, y: 216, width: 200, height: 4)), with: .color(accent.opacity(0.75)))
        // FACHADA DE VIDRO: bandas horizontais brilhando (moderno, não grade)
        for row in 0..<5 {
            let y = 236 + CGFloat(row) * 40
            let band = CGRect(x: 172, y: y, width: 176, height: 26)
            if open {
                ctx.fill(Path(roundedRect: band, cornerRadius: 4), with: .linearGradient(Gradient(colors:[Color(red:1,green:0.92,blue:0.72), Color(red:0.55,green:0.70,blue:0.80)]), startPoint: P(172,y), endPoint: P(348,y+26)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            } else {
                ctx.fill(Path(roundedRect: band, cornerRadius: 4), with: .color(Color(red:0.20,green:0.20,blue:0.22).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            }
            for m in 1..<5 { ctx.stroke(Path { p in p.move(to: P(172 + CGFloat(m)*35, y)); p.addLine(to: P(172 + CGFloat(m)*35, y+26)) }, with: .color(Color(red:0.32,green:0.31,blue:0.29).opacity(g*0.7)), lineWidth: 1.2) }  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }
        // FAROL vermelho no mastro, no topo (assinatura do Hospital Universitário — ref #4)
        let cross = open ? TrailWorld.crossRed : dim(TrailWorld.crossRed)
        ctx.stroke(Path { p in p.move(to: P(260,200)); p.addLine(to: P(260,164)) }, with: .color(Color(red:0.34,green:0.33,blue:0.31).opacity(g)), lineWidth: 3)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 246, y: 146, width: 28, height: 28)), with: .radialGradient(Gradient(colors:[TrailWorld.crossRed.opacity(0.85), .clear]), center: P(260,160), startRadius:1, endRadius:22)) }
        ctx.fill(Path(ellipseIn: CGRect(x: 253, y: 153, width: 14, height: 14)), with: .color(cross))
        // CRUZ-emblema (logo do hospital) numa placa, destacada da vidraça
        ctx.fill(Path(roundedRect: CGRect(x: 228, y: 236, width: 64, height: 60), cornerRadius: 8), with: .color(Color(red:0.22,green:0.26,blue:0.28).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 230, y: 238, width: 60, height: 56)), with: .radialGradient(Gradient(colors:[TrailWorld.crossRed.opacity(0.35), .clear]), center: P(260,266), startRadius:1, endRadius:30)) }
        ctx.fill(Path(roundedRect: CGRect(x: 252, y: 244, width: 16, height: 44), cornerRadius: 3), with: .color(cross))
        ctx.fill(Path(roundedRect: CGRect(x: 238, y: 258, width: 44, height: 16), cornerRadius: 3), with: .color(cross))
        // entrada moderna: marquise de vidro (teal) + porta ampla iluminada
        ctx.fill(Path(roundedRect: CGRect(x: 214, y: 412, width: 92, height: 10), cornerRadius: 3), with: .color(accent.opacity(0.85)))
        if open {
            ctx.fill(Path(roundedRect: CGRect(x: 234, y: 422, width: 56, height: 30), cornerRadius: 5), with: .radialGradient(Gradient(colors:[Color(red:1,green:0.94,blue:0.76), TrailWorld.windowGlow.opacity(0.7), .clear]), center: P(262,440), startRadius:2, endRadius:44))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        } else {
            ctx.fill(Path(roundedRect: CGRect(x: 234, y: 422, width: 56, height: 30), cornerRadius: 5), with: .color(TrailWorld.wood))
            let lock = Color(red: 0.42, green: 0.35, blue: 0.27)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            ctx.stroke(Path(ellipseIn: CGRect(x: 254, y: 300, width: 16, height: 18)), with: .color(lock), lineWidth: 3)
            ctx.fill(Path(roundedRect: CGRect(x: 248, y: 312, width: 28, height: 20), cornerRadius: 3), with: .color(lock))
        }
    }

    // ambulância — desenhada na CAMADA VIVA (sai do hospital de vez em quando)
    private func drawAmbulanceBody(_ ctx: inout GraphicsContext, blink: Bool?) {
        let g = open ? 1.0 : 0.5
        ctx.fill(Path(ellipseIn: CGRect(x: 446, y: 476, width: 100, height: 14)), with: .color(.black.opacity(0.28 * g)))
        let bodyC = Color(red: 0.90, green: 0.88, blue: 0.82).opacity(g)   // branco quente  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let bodySh = Color(red: 0.70, green: 0.68, blue: 0.62).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        // caixa (traseira) + cabine mais baixa à frente (direita)
        ctx.fill(Path(roundedRect: CGRect(x: 448, y: 446, width: 66, height: 32), cornerRadius: 6), with: lg(bodyC, bodySh, P(448,446), P(448,478)))
        ctx.fill(Path(roundedRect: CGRect(x: 510, y: 456, width: 32, height: 22), cornerRadius: 6), with: lg(bodyC, bodySh, P(510,456), P(510,478)))
        // para-brisa aceso
        ctx.fill(Path(roundedRect: CGRect(x: 520, y: 459, width: 18, height: 13), cornerRadius: 3), with: .color(open ? TrailWorld.windowGlow.opacity(0.8) : Color(red:0.16,green:0.13,blue:0.09)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        // faixa + cruz vermelha no painel
        let red = open ? TrailWorld.crossRed : dim(TrailWorld.crossRed)
        ctx.fill(Path(CGRect(x: 448, y: 462, width: 62, height: 5)), with: .color(red.opacity(0.9)))
        ctx.fill(Path(roundedRect: CGRect(x: 472, y: 450, width: 8, height: 22), cornerRadius: 2), with: .color(red))
        ctx.fill(Path(roundedRect: CGRect(x: 465, y: 457, width: 22, height: 8), cornerRadius: 2), with: .color(red))
        // sirene no teto — pisca vermelho/teal quando em movimento (blink != nil)
        ctx.fill(Path(roundedRect: CGRect(x: 466, y: 440, width: 28, height: 7), cornerRadius: 2), with: .color(Color(red:0.30,green:0.28,blue:0.26).opacity(g)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let redOn = blink == true, tealOn = blink == false
        if redOn { ctx.fill(Path(ellipseIn: CGRect(x: 466, y: 434, width: 16, height: 16)), with: .radialGradient(Gradient(colors:[TrailWorld.crossRed.opacity(0.95), .clear]), center: P(474,442), startRadius:1, endRadius:15)) }
        ctx.fill(Path(ellipseIn: CGRect(x: 470, y: 439, width: 8, height: 8)), with: .color(redOn ? TrailWorld.crossRed : TrailWorld.crossRed.opacity(0.3 * g)))
        if tealOn { ctx.fill(Path(ellipseIn: CGRect(x: 478, y: 434, width: 16, height: 16)), with: .radialGradient(Gradient(colors:[TrailWorld.tier2Bright.opacity(0.95), .clear]), center: P(486,442), startRadius:1, endRadius:15)) }
        ctx.fill(Path(ellipseIn: CGRect(x: 482, y: 439, width: 8, height: 8)), with: .color(tealOn ? TrailWorld.tier2Bright : TrailWorld.tier2Bright.opacity(0.3 * g)))
        // rodas + calotas
        ctx.fill(Path(ellipseIn: CGRect(x: 458, y: 470, width: 22, height: 22)), with: .color(TrailWorld.wheel))
        ctx.fill(Path(ellipseIn: CGRect(x: 512, y: 470, width: 22, height: 22)), with: .color(TrailWorld.wheel))
        ctx.fill(Path(ellipseIn: CGRect(x: 463, y: 475, width: 12, height: 12)), with: .color(Color(red:0.5,green:0.5,blue:0.5)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(ellipseIn: CGRect(x: 517, y: 475, width: 12, height: 12)), with: .color(Color(red:0.5,green:0.5,blue:0.5)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }

    // MARK: - INSTITUTO DE ESPECIALIDADES: o auge — cúpula dourada com gomos,
    // pórtico com colunas + emblema de louro, fonte na frente. Rafael 2026-07-14.
    private func drawInstituto(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.55
        ctx.fill(Path(ellipseIn: CGRect(x: 90, y: 452, width: 430, height: 36)), with: .color(.black.opacity(0.34)))
        let sfA = Color(red: 0.50, green: 0.44, blue: 0.34).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let sfB = Color(red: 0.34, green: 0.29, blue: 0.22).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let ssA = Color(red: 0.32, green: 0.28, blue: 0.21).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let ssB = Color(red: 0.20, green: 0.17, blue: 0.13).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 150, y: 128, width: 300, height: 344)), with: .radialGradient(Gradient(colors:[TrailWorld.tier0Bright.opacity(0.12), .clear]), center: P(282,300), startRadius: 20, endRadius: 200)) }
        ctx.fill(poly([P(404,306),P(468,276),P(468,444),P(404,452)]), with: lg(ssA, ssB, P(404,276), P(468,452)))
        ctx.fill(Path(CGRect(x: 132, y: 306, width: 272, height: 146)), with: lg(sfA, sfB, P(132,306), P(190,452)))
        let gold = open ? TrailWorld.tier0Bright : dim(TrailWorld.tier0Bright)
        let goldMid = open ? TrailWorld.tier0Mid : dim(TrailWorld.tier0Mid)
        ctx.fill(Path(CGRect(x: 124, y: 300, width: 288, height: 10)), with: .color(gold.opacity(0.9)))   // cornija dourada
        // tambor (drum) com colunas
        ctx.fill(Path(CGRect(x: 236, y: 236, width: 92, height: 66)), with: lg(sfA, sfB, P(236,236), P(236,302)))
        for cx in stride(from: CGFloat(244), through: 316, by: 18) {
            ctx.stroke(Path { p in p.move(to: P(cx, 244)); p.addLine(to: P(cx, 298)) }, with: .color(gold.opacity(0.5)), lineWidth: 2)
        }
        // CÚPULA hemisférica dourada grande e clara + reflexo
        var dome = Path()
        dome.move(to: P(230, 238)); dome.addCurve(to: P(334, 238), control1: P(238, 156), control2: P(326, 156)); dome.closeSubpath()
        ctx.fill(dome, with: .linearGradient(Gradient(colors:[Color(red:1,green:0.86,blue:0.5), gold, goldMid]), startPoint: P(250,168), endPoint: P(320,238)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open { ctx.fill(Path(ellipseIn: CGRect(x: 258, y: 182, width: 20, height: 30)), with: .color(Color(red:1,green:0.97,blue:0.85).opacity(0.5))) }  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        // gomos (nervuras) da cúpula — dá volume clássico (ref #5)
        for rx in [CGFloat(240), 258, 282, 306, 324] {
            var rib = Path(); rib.move(to: P(rx, 236)); rib.addQuadCurve(to: P(282, 170), control: P((rx + 282) / 2, 184))
            ctx.stroke(rib, with: .color(goldMid.opacity(0.5)), lineWidth: 1.6)
        }
        ctx.fill(Path(CGRect(x: 226, y: 233, width: 112, height: 6)), with: .color(gold.opacity(0.9)))   // anel na base
        // lanternim + finial dourado
        ctx.fill(Path(roundedRect: CGRect(x: 274, y: 150, width: 16, height: 18), cornerRadius: 3), with: .color(gold))
        ctx.fill(poly([P(282,132),P(291,148),P(282,164),P(273,148)]), with: .color(open ? Color(red:1,green:0.92,blue:0.62) : dim(gold)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        // janelas altas em arco
        for x in [CGFloat(148), 186, 344, 382] { archWindow(&ctx, x: x, y: 320, w: 24, h: 74) }
        // PÓRTICO grandioso: frontão + emblema de louro + 4 colunas + entrada iluminada
        let col = Color(red: 0.80, green: 0.73, blue: 0.58).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        let colSh = Color(red: 0.56, green: 0.50, blue: 0.39).opacity(g)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(poly([P(222,344),P(284,316),P(346,344)]), with: .color(gold.opacity(0.92)))   // frontão triangular
        drawLaurel(&ctx, center: P(284,336), color: open ? Color(red:0.34,green:0.26,blue:0.10) : dim(goldMid))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(CGRect(x: 226, y: 344, width: 116, height: 10)), with: .color(gold.opacity(0.9)))
        for cx in [CGFloat(234), 268, 306, 340] {
            ctx.fill(Path(roundedRect: CGRect(x: cx, y: 354, width: 14, height: 92), cornerRadius: 4), with: lg(col, colSh, P(cx,354), P(cx+14,446)))
        }
        if open {
            ctx.fill(Path(roundedRect: CGRect(x: 268, y: 376, width: 48, height: 70), cornerRadius: 5), with: .radialGradient(Gradient(colors:[Color(red:1,green:0.95,blue:0.78), TrailWorld.windowGlow, TrailWorld.wood]), center: P(292,414), startRadius:2, endRadius:54))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        } else {
            ctx.fill(Path(roundedRect: CGRect(x: 268, y: 376, width: 48, height: 70), cornerRadius: 5), with: .color(TrailWorld.wood))
        }
        ctx.fill(Path(roundedRect: CGRect(x: 232, y: 446, width: 120, height: 8), cornerRadius: 2), with: .color(col.opacity(0.85)))
        // fonte na frente (assinatura do Instituto — ref #5)
        drawFountain(&ctx)
        if !open {
            let lock = Color(red: 0.42, green: 0.35, blue: 0.27)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
            ctx.stroke(Path(ellipseIn: CGRect(x: 284, y: 392, width: 16, height: 18)), with: .color(lock), lineWidth: 3)
            ctx.fill(Path(roundedRect: CGRect(x: 278, y: 404, width: 28, height: 20), cornerRadius: 3), with: .color(lock))
        }
    }

    private func drawLaurel(_ ctx: inout GraphicsContext, center c: CGPoint, color: Color) {
        for side in [CGFloat(-1), 1] {
            var branch = Path()
            branch.move(to: P(c.x, c.y + 9))
            branch.addQuadCurve(to: P(c.x + side * 15, c.y - 9), control: P(c.x + side * 18, c.y + 3))
            ctx.stroke(branch, with: .color(color), lineWidth: 2)
            for k in 0..<3 {
                let f = CGFloat(k)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + side * (5 + f * 4.5) - 2.5, y: c.y + 5 - f * 6 - 3.5, width: 6, height: 8)), with: .color(color))
            }
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2.5, y: c.y - 12, width: 5, height: 5)), with: .color(color))
    }

    private func drawFountain(_ ctx: inout GraphicsContext) {
        let g = open ? 1.0 : 0.5
        let water = open ? TrailWorld.tier2Bright : dim(TrailWorld.tier2Bright)
        ctx.fill(Path(ellipseIn: CGRect(x: 248, y: 470, width: 88, height: 26)), with: .color(Color(red:0.32,green:0.29,blue:0.24).opacity(g)))   // bacia  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.fill(Path(ellipseIn: CGRect(x: 256, y: 474, width: 72, height: 18)), with: .color(water.opacity(0.5)))                                  // água
        ctx.fill(Path(roundedRect: CGRect(x: 288, y: 456, width: 8, height: 22), cornerRadius: 3), with: .color(Color(red:0.36,green:0.32,blue:0.26).opacity(g)))  // pilar  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        if open {
            ctx.stroke(Path { p in p.move(to: P(292,458)); p.addQuadCurve(to: P(274,480), control: P(278,450)) }, with: .color(water.opacity(0.75)), lineWidth: 2.4)
            ctx.stroke(Path { p in p.move(to: P(292,458)); p.addQuadCurve(to: P(310,480), control: P(306,450)) }, with: .color(water.opacity(0.75)), lineWidth: 2.4)
            ctx.fill(Path(ellipseIn: CGRect(x: 286, y: 450, width: 12, height: 8)), with: .color(water.opacity(0.7)))
        }
    }

    private func drawWindow(_ ctx: inout GraphicsContext, poly pts: [CGPoint], t: TimeInterval, phase: Double) {
        let path = poly(pts)
        let xs = pts.map { $0.x }, ys = pts.map { $0.y }
        let cx = xs.reduce(0,+) / CGFloat(pts.count)
        let cy = ys.reduce(0,+) / CGFloat(pts.count)
        if open {
            let flicker = 0.82 + 0.18 * sin(t * 2.2 + phase * 6)
            ctx.fill(path, with: .radialGradient(Gradient(colors: [Color(red:1,green:0.94,blue:0.81), TrailWorld.windowGlow, Color(red:0.79,green:0.56,blue:0.24)]),  // ds-allow: arte do mundo (predios semi-3D em Canvas)
                                                 center: P(cx, cy - 4), startRadius: 2, endRadius: 42))
            ctx.fill(path, with: .color(TrailWorld.windowGlow.opacity(0.14 * flicker)))
        } else {
            ctx.fill(path, with: .color(Color(red:0.16,green:0.13,blue:0.09)))  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        }
        // divisórias (cruzeta), recortadas na janela
        let muntin = Color(red: 0.12, green: 0.086, blue: 0.055)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
        ctx.drawLayer { l in
            l.clip(to: path)
            l.stroke(Path { p in p.move(to: P(cx, ys.min()! - 2)); p.addLine(to: P(cx, ys.max()! + 2)) }, with: .color(muntin), lineWidth: 2.4)
            l.stroke(Path { p in p.move(to: P(xs.min()! - 2, cy)); p.addLine(to: P(xs.max()! + 2, cy)) }, with: .color(muntin), lineWidth: 2.4)
        }
        ctx.stroke(path, with: .color(Color(red:0.14,green:0.10,blue:0.067)), lineWidth: 2.5)  // ds-allow: arte do mundo (predios semi-3D em Canvas)
    }
}
