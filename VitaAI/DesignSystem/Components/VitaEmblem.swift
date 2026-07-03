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

    // Rampa de ouro = FONTE ÚNICA em VitaColors (compartilhada com o medalhão de
    // level-up). Zero RGB local: muda o token → muda todo emblema do app.
    private var bright:  Color { VitaColors.emblemBright }
    private var mid:     Color { VitaColors.emblemMid }
    private var deep:    Color { VitaColors.emblemDeep }
    private var dark:    Color { VitaColors.emblemDark }
    private var engrave: Color { VitaColors.emblemEngrave }

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
