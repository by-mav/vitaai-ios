import SwiftUI

// MARK: - TrailMissionSign — a placa de missões da trilha (Home)
//
// Rafael 2026-07-16: "uma placa no centro de cada fase, com o Vita de NPC do
// lado; clica e abre o popout das missões do dia". Uma placa por fase (5 no
// total, a cada 1/10 dos níveis), no lado OPOSTO à casa-marco daquela fase.
//
// Arte no mesmo vocabulário do mundo (Semi3DHouse/TrailWorld): tábua de
// madeira em vista 3/4 sob a luz dourada de cima — dois postes, tábua com
// veio, moldura entalhada, bisel iluminado no topo-esquerda, sombra no chão.
// Placa da fase ATUAL fica acesa (lanterna + brilho + selo de pendentes);
// as outras ficam apagadas (madeira fria, sem lanterna).
//
// Desenhada em Canvas em coords lógicas 300x300 e escalada pro frame — mesmo
// padrão da Semi3DHouse (estático, não re-avalia por frame).

struct TrailMissionSign: View {
    /// Fase (0-4) desta placa — só a da fase atual do aluno fica acesa.
    var lit: Bool = false
    /// Missões prontas pra resgatar (selo pulsante no topo). 0 = sem selo.
    var pendingCount: Int = 0

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let s = min(size.width / 300, size.height / 300)
                ctx.translateBy(x: (size.width - 300 * s) / 2, y: (size.height - 300 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                draw(&ctx)
            }
            .transaction { $0.animation = nil }   // estático (igual Semi3DHouse)

            // Ancorado na quina da tábua (a tábua ocupa o miolo do canvas, não
            // o frame inteiro) — proporcional pro selo acompanhar o tamanho.
            GeometryReader { geo in
                if pendingCount > 0 {
                    pendingSeal
                        .position(x: geo.size.width * 0.80, y: geo.size.height * 0.20)
                }
            }
        }
    }

    // MARK: selo "tem recompensa pra pegar" — o chamariz da placa
    private var pendingSeal: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [TrailWorld.fireflyWarm, TrailWorld.fireflyGold, TrailWorld.roadEdge],
                        center: .topLeading, startRadius: 1, endRadius: 20
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(TrailWorld.wood, lineWidth: 1.5))
                .shadow(color: TrailWorld.fireflyGold.opacity(0.7), radius: 9)
            Text("\(pendingCount)")
                .font(.system(size: 15, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(TrailWorld.fieldBottom)
        }
        .modifier(SealPulse())
    }

    // MARK: - Desenho da placa (coords lógicas 300x300, chão em y=250)

    private func draw(_ ctx: inout GraphicsContext) {
        let wood = lit ? TrailWorld.wood : TrailWorld.wood.opacity(0.62)
        let plankTop = lit ? TrailWorld.roofTop : TrailWorld.stoneWing
        let plankBottom = lit ? TrailWorld.roofBottom : TrailWorld.stoneBottom

        groundShadow(&ctx)
        posts(&ctx, wood: wood)
        plank(&ctx, top: plankTop, bottom: plankBottom)
        carvedText(&ctx)
        if lit { lantern(&ctx) }
    }

    /// Sombra elíptica no chão — ancora a placa no campo (luz vem de cima).
    private func groundShadow(_ ctx: inout GraphicsContext) {
        ctx.fill(
            Path(ellipseIn: CGRect(x: 96, y: 242, width: 108, height: 18)),
            with: .color(.black.opacity(lit ? 0.34 : 0.24))
        )
    }

    /// Dois postes com face frontal + lateral (a lateral dá a profundidade 3/4).
    private func posts(_ ctx: inout GraphicsContext, wood: Color) {
        for x in [CGFloat(106), CGFloat(178)] {
            // face lateral (mais escura — está de costas pra luz)
            var side = Path()
            side.move(to: CGPoint(x: x + 14, y: 96))
            side.addLine(to: CGPoint(x: x + 20, y: 92))
            side.addLine(to: CGPoint(x: x + 20, y: 244))
            side.addLine(to: CGPoint(x: x + 14, y: 250))
            side.closeSubpath()
            ctx.fill(side, with: .color(wood.opacity(0.55)))

            // face frontal + veio da madeira
            let front = Path(CGRect(x: x, y: 96, width: 14, height: 154))
            ctx.fill(
                front,
                with: .linearGradient(
                    Gradient(colors: [wood, wood.opacity(0.72)]),
                    startPoint: CGPoint(x: x, y: 96), endPoint: CGPoint(x: x + 14, y: 96)
                )
            )
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: x + 5, y: 112))
                    p.addLine(to: CGPoint(x: x + 5, y: 238))
                },
                with: .color(.black.opacity(0.16)), lineWidth: 1
            )
            // bisel de luz na quina viva (topo-esquerda)
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: x + 0.6, y: 98))
                    p.addLine(to: CGPoint(x: x + 0.6, y: 246))
                },
                with: .color(TrailWorld.fireflyWarm.opacity(lit ? 0.30 : 0.12)), lineWidth: 1.2
            )
        }
    }

    /// A tábua: bloco 3/4 com topo iluminado, moldura entalhada e veio.
    private func plank(_ ctx: inout GraphicsContext, top: Color, bottom: Color) {
        let body = CGRect(x: 58, y: 62, width: 184, height: 78)

        // canto/espessura de cima (a luz bate aqui)
        var cap = Path()
        cap.move(to: CGPoint(x: body.minX, y: body.minY))
        cap.addLine(to: CGPoint(x: body.minX + 10, y: body.minY - 8))
        cap.addLine(to: CGPoint(x: body.maxX + 10, y: body.minY - 8))
        cap.addLine(to: CGPoint(x: body.maxX, y: body.minY))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(top.opacity(0.92)))

        // lateral direita (profundidade)
        var side = Path()
        side.move(to: CGPoint(x: body.maxX, y: body.minY))
        side.addLine(to: CGPoint(x: body.maxX + 10, y: body.minY - 8))
        side.addLine(to: CGPoint(x: body.maxX + 10, y: body.maxY - 8))
        side.addLine(to: CGPoint(x: body.maxX, y: body.maxY))
        side.closeSubpath()
        ctx.fill(side, with: .color(bottom.opacity(0.85)))

        // face frontal (gradiente = superfície pegando luz de cima-esquerda)
        let face = Path(roundedRect: body, cornerRadius: 5)
        ctx.fill(
            face,
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: CGPoint(x: body.minX, y: body.minY),
                endPoint: CGPoint(x: body.maxX, y: body.maxY)
            )
        )

        // highlight especular no topo da face (fio de luz = matéria sólida)
        ctx.stroke(
            Path { p in
                p.move(to: CGPoint(x: body.minX + 6, y: body.minY + 2.5))
                p.addLine(to: CGPoint(x: body.maxX - 6, y: body.minY + 2.5))
            },
            with: .color(TrailWorld.fireflyWarm.opacity(lit ? 0.42 : 0.16)), lineWidth: 2
        )

        // moldura entalhada
        ctx.stroke(
            Path(roundedRect: body.insetBy(dx: 7, dy: 7), cornerRadius: 3),
            with: .color(.black.opacity(0.22)), lineWidth: 1.5
        )

        // veio da madeira (duas linhas longas, baixo contraste)
        for y in [CGFloat(96), CGFloat(122)] {
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: body.minX + 14, y: y))
                    p.addCurve(
                        to: CGPoint(x: body.maxX - 14, y: y + 1.5),
                        control1: CGPoint(x: body.minX + 70, y: y - 2),
                        control2: CGPoint(x: body.maxX - 70, y: y + 4)
                    )
                },
                with: .color(.black.opacity(0.10)), lineWidth: 1
            )
        }

        // parafusos nos 4 cantos
        for p in [
            CGPoint(x: body.minX + 13, y: body.minY + 13), CGPoint(x: body.maxX - 13, y: body.minY + 13),
            CGPoint(x: body.minX + 13, y: body.maxY - 13), CGPoint(x: body.maxX - 13, y: body.maxY - 13),
        ] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                with: .color(lit ? TrailWorld.fireflyGold.opacity(0.85) : TrailWorld.stoneTop)
            )
        }
    }

    /// "MISSÕES" gravado na tábua — some no apagado (fica só o entalhe).
    private func carvedText(_ ctx: inout GraphicsContext) {
        let text = Text("MISSÕES")
            .font(.system(size: 21, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
            .foregroundStyle(lit ? TrailWorld.fireflyWarm : TrailWorld.signTint.opacity(0.85))
        // sombra do entalhe (1px abaixo) + texto
        ctx.draw(
            Text("MISSÕES")
                .font(.system(size: 21, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(Color.black.opacity(0.45)),
            at: CGPoint(x: 150, y: 102.5)
        )
        ctx.draw(text, at: CGPoint(x: 150, y: 101))
    }

    /// Lanterna pendurada na quina — só na placa da fase atual (a "viva").
    private func lantern(_ ctx: inout GraphicsContext) {
        let cx: CGFloat = 232, cy: CGFloat = 150
        // halo
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - 26, y: cy - 26, width: 52, height: 52)),
            with: .radialGradient(
                Gradient(colors: [TrailWorld.fireflyGold.opacity(0.34), .clear]),
                center: CGPoint(x: cx, y: cy), startRadius: 1, endRadius: 26
            )
        )
        // gancho
        ctx.stroke(
            Path { p in
                p.move(to: CGPoint(x: cx, y: 132))
                p.addLine(to: CGPoint(x: cx, y: cy - 9))
            },
            with: .color(TrailWorld.wood), lineWidth: 1.5
        )
        // corpo + vidro aceso
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - 7, y: cy - 9, width: 14, height: 18), cornerRadius: 3),
            with: .color(TrailWorld.wood)
        )
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - 5, y: cy - 7, width: 10, height: 14), cornerRadius: 2),
            with: .linearGradient(
                Gradient(colors: [TrailWorld.fireflyWarm, TrailWorld.windowGlow]),
                startPoint: CGPoint(x: cx - 5, y: cy - 7), endPoint: CGPoint(x: cx + 5, y: cy + 7)
            )
        )
    }
}

/// Pulso lento do selo de pendentes (respiração, não pisca-pisca).
private struct SealPulse: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? 1.10 : 0.96)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

#Preview("Placa — acesa com pendentes") {
    ZStack {
        LinearGradient(
            colors: [TrailWorld.fieldTop, TrailWorld.fieldBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        TrailMissionSign(lit: true, pendingCount: 2).frame(width: 210, height: 210)
    }
}

#Preview("Placa — apagada (outra fase)") {
    ZStack {
        LinearGradient(
            colors: [TrailWorld.fieldTop, TrailWorld.fieldBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        TrailMissionSign(lit: false, pendingCount: 0).frame(width: 210, height: 210)
    }
}
