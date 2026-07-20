import SwiftUI

// MARK: - PersonMascot — a PESSOA do jogador, DESENHADA EM CODIGO (Rafael 2026-07-18)
//
// "eu literalmente criei um jogo contigo, replique flappy bird tu foi la e replicou...
//  eu to falando de CODIGO." — sim. Isto e codigo, igual a casa (Semi3DHouse, 668 linhas de
//  Canvas). Nao e imagem, nao e gerador 3D, nao e designer. E forma + gradiente + luz, feito a mao.
//
// Chibi de frente: cabeca grande (~44% da altura), rosto humano completo, cabelo em camadas,
// corpo com roupa preta + fio dourado (a marca Vita), maos, botas. Luz de cima-esquerda em TODO
// gradiente (a mesma da casa), cores do mundo dourado.

enum PersonKind: String, CaseIterable, Codable { case mulher, homem }

struct PersonMascot: View {
    var kind: PersonKind = .mulher
    var size: CGFloat = 220
    var idleEnabled: Bool = true
    @State private var breath: CGFloat = 0

    private let gold    = Color(red: 1.0,   green: 0.82, blue: 0.42)
    private let skinLit = Color(red: 0.95, green: 0.80, blue: 0.64)
    private let skinMid = Color(red: 0.82, green: 0.63, blue: 0.47)
    private let skinDark = Color(red: 0.60, green: 0.42, blue: 0.30)
    private let hairLit = Color(red: 0.34, green: 0.24, blue: 0.15)
    private let hairDark = Color(red: 0.12, green: 0.08, blue: 0.05)
    private let cloth = Color(red: 0.11, green: 0.10, blue: 0.09)
    private let clothLit = Color(red: 0.20, green: 0.18, blue: 0.15)

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width / 300, sz.height / 480)
            ctx.translateBy(x: (sz.width - 300 * s) / 2, y: (sz.height - 480 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            draw(&ctx)
        }
        .frame(width: size * 0.66, height: size)
        .scaleEffect(y: 1 + breath * 0.014, anchor: .bottom)
        .onAppear {
            guard idleEnabled else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breath = 1 }
        }
    }

    private func lit(_ a: Color, _ b: Color) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [a, b]),
                        startPoint: CGPoint(x: 90, y: 60), endPoint: CGPoint(x: 220, y: 380))
    }
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private func draw(_ ctx: inout GraphicsContext) {
        let mulher = kind == .mulher
        let cx: CGFloat = 150

        ctx.fill(Path(ellipseIn: CGRect(x: cx-60, y: 452, width: 120, height: 18)),
                 with: .color(.black.opacity(0.28)))

        // CABELO de tras (moldura)
        if mulher {
            var back = Path()
            back.move(to: P(cx-78, 150))
            back.addQuadCurve(to: P(cx-92, 300), control: P(cx-108, 210))
            back.addQuadCurve(to: P(cx-40, 250), control: P(cx-70, 300))
            back.addLine(to: P(cx+40, 250))
            back.addQuadCurve(to: P(cx+92, 300), control: P(cx+70, 300))
            back.addQuadCurve(to: P(cx+78, 150), control: P(cx+108, 210))
            back.closeSubpath()
            ctx.fill(back, with: lit(hairLit, hairDark))
        }

        legAndBoot(&ctx, x: cx-26, mulher: mulher)
        legAndBoot(&ctx, x: cx+26, mulher: mulher)

        // TRONCO
        var torso = Path()
        let shoulder: CGFloat = mulher ? 54 : 62
        let waist: CGFloat = mulher ? 40 : 48
        torso.move(to: P(cx-shoulder, 250))
        torso.addQuadCurve(to: P(cx-waist, 360), control: P(cx-shoulder-4, 310))
        if mulher {
            torso.addLine(to: P(cx-70, 400)); torso.addQuadCurve(to: P(cx+70, 400), control: P(cx, 418))
            torso.addLine(to: P(cx+waist, 360))
        } else {
            torso.addLine(to: P(cx+waist, 360))
        }
        torso.addQuadCurve(to: P(cx+shoulder, 250), control: P(cx+shoulder+4, 310))
        torso.addQuadCurve(to: P(cx, 238), control: P(cx, 244))
        torso.closeSubpath()
        ctx.fill(torso, with: lit(clothLit, cloth))
        ctx.stroke(torso, with: .color(gold.opacity(0.5)), lineWidth: 1.4)
        ctx.fill(Path(ellipseIn: CGRect(x: cx-8, y: 322, width: 16, height: 16)), with: .color(gold))
        ctx.fill(Path(ellipseIn: CGRect(x: cx-4, y: 326, width: 8, height: 8)), with: .color(hairDark))

        arm(&ctx, x: cx-shoulder-4)
        arm(&ctx, x: cx+shoulder+4)

        // PESCOCO
        ctx.fill(Path(roundedRect: CGRect(x: cx-14, y: 218, width: 28, height: 36), cornerRadius: 10),
                 with: lit(skinMid, skinDark))

        // CABECA
        let head = Path(ellipseIn: CGRect(x: cx-72, y: 60, width: 144, height: 160))
        ctx.fill(head, with: .radialGradient(Gradient(colors: [skinLit, skinMid, skinDark]),
                 center: P(cx-24, 100), startRadius: 6, endRadius: 120))
        ctx.fill(Path(ellipseIn: CGRect(x: cx-52, y: 150, width: 26, height: 18)),
                 with: .color(Color(red:0.95,green:0.55,blue:0.45).opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: cx+26, y: 150, width: 26, height: 18)),
                 with: .color(Color(red:0.95,green:0.55,blue:0.45).opacity(0.35)))

        ctx.fill(Path(ellipseIn: CGRect(x: cx-78, y: 128, width: 22, height: 30)), with: lit(skinMid, skinDark))
        ctx.fill(Path(ellipseIn: CGRect(x: cx+56, y: 128, width: 22, height: 30)), with: lit(skinMid, skinDark))

        face(&ctx, cx: cx)

        // CABELO frente
        var fringe = Path()
        fringe.move(to: P(cx-74, 130))
        fringe.addQuadCurve(to: P(cx-30, 74), control: P(cx-72, 70))
        fringe.addQuadCurve(to: P(cx+30, 74), control: P(cx, 58))
        fringe.addQuadCurve(to: P(cx+74, 130), control: P(cx+72, 70))
        fringe.addQuadCurve(to: P(cx+30, 118), control: P(cx+50, 138))
        fringe.addQuadCurve(to: P(cx-8, 106), control: P(cx+8, 120))
        fringe.addQuadCurve(to: P(cx-74, 130), control: P(cx-46, 132))
        fringe.closeSubpath()
        ctx.fill(fringe, with: lit(hairLit, hairDark))
        var shine = Path(); shine.move(to: P(cx-40, 88)); shine.addQuadCurve(to: P(cx+20, 80), control: P(cx-10, 72))
        ctx.stroke(shine, with: .color(gold.opacity(0.4)), lineWidth: 3)

        if mulher {
            ctx.fill(Path(ellipseIn: CGRect(x: cx-70, y: 158, width: 10, height: 10)), with: .color(gold))
        }
    }

    private func face(_ ctx: inout GraphicsContext, cx: CGFloat) {
        for sx in [cx-34, cx+18] {
            var b = Path(); b.move(to: P(sx, 132)); b.addQuadCurve(to: P(sx+26, 130), control: P(sx+13, 124))
            ctx.stroke(b, with: .color(hairDark), lineWidth: 4)
        }
        for ex in [cx-32, cx+16] {
            ctx.fill(Path(ellipseIn: CGRect(x: ex, y: 140, width: 30, height: 34)), with: .color(.white.opacity(0.92)))
            ctx.fill(Path(ellipseIn: CGRect(x: ex+6, y: 146, width: 20, height: 24)),
                     with: .color(Color(red:0.28,green:0.18,blue:0.10)))
            ctx.fill(Path(ellipseIn: CGRect(x: ex+9, y: 150, width: 8, height: 8)), with: .color(.black))
            ctx.fill(Path(ellipseIn: CGRect(x: ex+8, y: 148, width: 6, height: 6)), with: .color(.white))
        }
        var nose = Path(); nose.move(to: P(cx, 168)); nose.addQuadCurve(to: P(cx+5, 178), control: P(cx+6, 174))
        ctx.stroke(nose, with: .color(skinDark), lineWidth: 2.5)
        var mouth = Path(); mouth.move(to: P(cx-16, 190)); mouth.addQuadCurve(to: P(cx+16, 190), control: P(cx, 200))
        ctx.stroke(mouth, with: .color(Color(red:0.55,green:0.28,blue:0.24)), lineWidth: 3)
    }

    private func legAndBoot(_ ctx: inout GraphicsContext, x: CGFloat, mulher: Bool) {
        let top: CGFloat = mulher ? 392 : 358
        ctx.fill(Path(roundedRect: CGRect(x: x-12, y: top, width: 24, height: 60), cornerRadius: 10),
                 with: lit(clothLit, cloth))
        let boot = Path(roundedRect: CGRect(x: x-16, y: top+50, width: 34, height: 30), cornerRadius: 8)
        ctx.fill(boot, with: lit(clothLit, cloth))
        ctx.stroke(boot, with: .color(gold.opacity(0.55)), lineWidth: 1.4)
        ctx.fill(Path(ellipseIn: CGRect(x: x-4, y: top+58, width: 12, height: 12)), with: .color(gold.opacity(0.85)))
    }

    private func arm(_ ctx: inout GraphicsContext, x: CGFloat) {
        ctx.fill(Path(roundedRect: CGRect(x: x-11, y: 258, width: 22, height: 84), cornerRadius: 11),
                 with: lit(clothLit, cloth))
        ctx.fill(Path(ellipseIn: CGRect(x: x-11, y: 336, width: 24, height: 24)), with: lit(skinMid, skinDark))
    }
}

struct PersonMascotLab: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red:0.106,green:0.086,blue:0.051), Color(red:0.055,green:0.043,blue:0.027)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            HStack(spacing: 30) {
                VStack { PersonMascot(kind: .mulher, size: 300); Text("mulher").foregroundStyle(.white.opacity(0.4)) }
                VStack { PersonMascot(kind: .homem, size: 300); Text("homem").foregroundStyle(.white.opacity(0.4)) }
            }
        }
    }
}
#Preview { PersonMascotLab() }
