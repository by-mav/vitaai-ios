import SwiftUI

// MARK: - PersonMascot — a PESSOA do jogador na trilha (Rafael 2026-07-17)
//
// "quero um boneco homem e mulher... o vita que ta em cima dos blocos vai ser
//  trocado pela pessoa. ela escolhe no onboarding, sempre de frente olhando pra
//  gente, mesmo posicionamento."
//
// Nasce IRMÃO do OrbMascot: mesma língua visual (formas SwiftUI empilhadas em
// ZStack, luz de cima-esquerda em UnitPoint(0.36,0.30), corpo feito DA cor da
// paleta do tier, olhos que piscam). Não é Canvas como a casa — é o método do
// orb, porque a pessoa HERDA o contrato do orb (palette/state/size) e um dia os
// acessórios. Fase 1: sem acessório (não há jogador ainda; todos nível 1).
//
// A cabeça é a MESMA esfera-orb (mantém a alma do Vita). O que muda: em vez de
// flutuar sozinha, ela senta num CORPO humano de frente — ombros, tronco,
// braços, pernas — desenhado na paleta escura do mundo, com o dourado por cima.

enum PersonKind: String, CaseIterable, Codable {
    case mulher, homem
}

struct PersonMascot: View {
    var kind: PersonKind = .mulher
    var palette: MascotPalette = .vita
    var state: VitaMascotState = .awake
    var size: CGFloat = 120          // altura total da pessoa (cabeça+corpo)
    var idleEnabled: Bool = true

    // proporções: a cabeça-orb ocupa ~38% da altura; o corpo, o resto.
    private var head: CGFloat { size * 0.40 }
    private var asleep: Bool { if case .sleeping = state { return true } else { return false } }

    @State private var breath: CGFloat = 0

    var body: some View {
        VStack(spacing: -size * 0.045) {
            // A CABEÇA — a mesma esfera-orb, com a cara do Vita (olhos que piscam).
            OrbMascot(palette: palette, state: state, size: head,
                      accessories: [], bounceEnabled: false, idleEnabled: idleEnabled)

            // O CORPO — humano, de frente, feito da paleta do mundo.
            body(kind)
                .frame(width: size * 0.62, height: size * 0.60)
        }
        .frame(width: size * 0.7, height: size)
        .scaleEffect(y: 1 + breath * 0.012, anchor: .bottom)   // respiração leve (como as janelas piscam)
        .onAppear {
            guard idleEnabled, !asleep else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breath = 1 }
        }
    }

    // corpo em formas empilhadas — ombros, tronco, braços, pernas. Luz de cima-
    // esquerda (a mesma do orb) via gradiente linear diagonal.
    @ViewBuilder private func body(_ k: PersonKind) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let torsoW = k == .mulher ? w * 0.72 : w * 0.82   // ombro do homem mais largo
            let hipW   = k == .mulher ? w * 0.78 : w * 0.66   // quadril da mulher mais largo
            let skin = LinearGradient(
                colors: [palette.sphereInner, palette.sphereMid],
                startPoint: .topLeading, endPoint: .bottomTrailing)   // luz cima-esquerda
            ZStack {
                // pernas
                Capsule().fill(skin)
                    .frame(width: w * 0.16, height: h * 0.42)
                    .offset(x: -w * 0.12, y: h * 0.26)
                Capsule().fill(skin)
                    .frame(width: w * 0.16, height: h * 0.42)
                    .offset(x: w * 0.12, y: h * 0.26)
                // tronco — trapézio via RoundedRectangle afunilado (ombro→quadril)
                TorsoShape(topW: torsoW / w, bottomW: hipW / w)
                    .fill(skin)
                    .overlay(   // edge-light dourado na borda esquerda (como o orb tem)
                        TorsoShape(topW: torsoW / w, bottomW: hipW / w)
                            .stroke(palette.bright.opacity(0.28), lineWidth: 1.2)
                            .blur(radius: 0.6))
                    .frame(width: w, height: h * 0.62)
                    .offset(y: -h * 0.02)
                // braços
                Capsule().fill(skin)
                    .frame(width: w * 0.13, height: h * 0.44)
                    .rotationEffect(.degrees(8))
                    .offset(x: -torsoW * 0.52, y: h * 0.04)
                Capsule().fill(skin)
                    .frame(width: w * 0.13, height: h * 0.44)
                    .rotationEffect(.degrees(-8))
                    .offset(x: torsoW * 0.52, y: h * 0.04)
            }
        }
    }
}

// tronco afunilado: largura do topo (ombro) → base (quadril)
private struct TorsoShape: Shape {
    var topW: CGFloat    // 0..1 fração da largura
    var bottomW: CGFloat
    func path(in r: CGRect) -> Path {
        let cx = r.midX
        let tw = r.width * topW, bw = r.width * bottomW
        let inset: CGFloat = 6
        var p = Path()
        p.move(to: CGPoint(x: cx - tw/2, y: r.minY + inset))
        p.addLine(to: CGPoint(x: cx + tw/2, y: r.minY + inset))
        p.addQuadCurve(to: CGPoint(x: cx + bw/2, y: r.maxY - inset),
                       control: CGPoint(x: cx + bw/2 + 3, y: r.midY))
        p.addLine(to: CGPoint(x: cx - bw/2, y: r.maxY - inset))
        p.addQuadCurve(to: CGPoint(x: cx - tw/2, y: r.minY + inset),
                       control: CGPoint(x: cx - bw/2 - 3, y: r.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Laboratório: só a pessoa, homem e mulher, pra iterar com screenshot
struct PersonMascotLab: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [TrailWorld.fieldTop, TrailWorld.fieldBottom],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            HStack(spacing: 60) {
                VStack { PersonMascot(kind: .mulher, size: 200); Text("mulher").foregroundStyle(.white.opacity(0.5)) }
                VStack { PersonMascot(kind: .homem, size: 200); Text("homem").foregroundStyle(.white.opacity(0.5)) }
            }
        }
    }
}

#Preview { PersonMascotLab() }
