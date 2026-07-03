// VitaEmblem — o emblema dourado canônico do Vita (Frosted Gold).
//
// Mesma física de luz do medalhão de level-up (VitaLevelUpOverlay): ouro com
// gradiente que pega luz de cima, highlight especular, rim light e sombra de
// elevação. O símbolo (SF Symbol) é GRAVADO na peça (letterpress: glifo escuro
// + fio de luz por baixo), não colado por cima.
//
// LEI (Rafael 2026-07-02): todo ícone de ferramenta/feature/ação usa ESTE
// componente. PNG gerado por IA pra ícone = PROIBIDO — cada imagem nasce com
// estética própria e o app vira colcha de retalhos (era o estado anterior:
// tool-questoes/flashcards/simulados/atlas3d, cada um de um mundo).
//
// Tamanhos canônicos: 64 hero · 54 tool · 40 row · 30 chip.

import SwiftUI

struct VitaEmblem: View {
    let symbol: String
    var size: CGFloat = 54

    private var corner: CGFloat { size * 0.30 }

    // Ouro do medalhão (mesma família do VitaSectionColors tier 1)
    private let bright  = Color(red: 0.976, green: 0.824, blue: 0.576)
    private let mid     = Color(red: 0.878, green: 0.675, blue: 0.388)
    private let deep    = Color(red: 0.663, green: 0.455, blue: 0.227)
    private let dark    = Color(red: 0.431, green: 0.282, blue: 0.125)
    private let engrave = Color(red: 0.329, green: 0.216, blue: 0.059)

    var body: some View {
        ZStack {
            // corpo dourado: luz de cima, sombra interna embaixo (peça sólida)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: bright, location: 0),
                            .init(color: mid,    location: 0.42),
                            .init(color: deep,   location: 0.74),
                            .init(color: dark,   location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .shadow(.inner(color: .white.opacity(0.50), radius: 1, y: 1))
                    .shadow(.inner(color: dark.opacity(0.60), radius: 3, y: -2))
                )

            // highlight especular (reflexo no topo → peça polida)
            Ellipse()
                .fill(.white.opacity(0.50))
                .frame(width: size * 0.55, height: size * 0.22)
                .offset(y: -size * 0.32)
                .blur(radius: size * 0.055)
                .blendMode(.plusLighter)

            // rim light (fio de luz na borda superior)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.60), dark.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: max(1, size * 0.02)
                )

            // símbolo gravado (letterpress: escuro + luz na aresta de baixo)
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(engrave)
                .shadow(color: .white.opacity(0.40), radius: 0, y: max(1, size * 0.022))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.50), radius: size * 0.15, y: size * 0.11)
        .shadow(color: mid.opacity(0.30), radius: size * 0.32)
    }
}

#Preview {
    HStack(spacing: 18) {
        VitaEmblem(symbol: "list.clipboard", size: 64)
        VitaEmblem(symbol: "mic", size: 54)
        VitaEmblem(symbol: "stopwatch", size: 40)
        VitaEmblem(symbol: "brain.head.profile", size: 30)
    }
    .padding(30)
    .background(Color(red: 0.05, green: 0.04, blue: 0.03))
}
