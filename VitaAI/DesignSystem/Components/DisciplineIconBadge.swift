import SwiftUI

/// Badge redondo de disciplina/área. Quando a disciplina é conhecida, mostra a
/// ARTE dela (`disc-*` — os 99 badges de fogo do ComfyUI, cada disciplina com a
/// sua). Quando não é (baralho "aaa", "FEEDBACK AULA 5"), cai no glifo semântico
/// sobre círculo colorido — nunca a arte errada.
///
/// Rafael 2026-07-17: "esperava mais, algo que tivesse um ícone bonito por
/// área/disciplina" — a arte existia no bundle e nenhuma lista chamava.
/// Mesma taxonomia, mesmos ícones em todo lugar (2026-07-16).
struct DisciplineIconBadge: View {
    /// Nome da disciplina OU da grande área (resolve arte, ou símbolo+cor).
    let name: String
    var size: CGFloat = 50

    var body: some View {
        if let asset = DisciplineImages.imageAssetIfKnown(for: name) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // O badge ja vem com borda e brilho proprios; a sombra so o
                // descola do fundo, sem competir com a arte.
                .shadow(color: .black.opacity(0.45), radius: size * 0.09, y: 3)
        } else {
            glyphFallback
        }
    }

    /// Disciplina desconhecida: glifo + cor determinística (mesmo nome → mesma cor).
    private var glyphFallback: some View {
        let spec = DisciplineImages.iconSpec(for: name)
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [spec.color.opacity(0.95), spec.color.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            Image(systemName: spec.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))  // ds-allow: glifo do ícone (não é texto)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: spec.color.opacity(0.35), radius: size * 0.1, y: 3)
    }
}

#Preview("Conhecidas (arte) vs desconhecidas (glifo)") {
    HStack(spacing: 14) {
        DisciplineIconBadge(name: "Cardiologia")
        DisciplineIconBadge(name: "Anatomia")
        DisciplineIconBadge(name: "Farmacologia")
        DisciplineIconBadge(name: "aaa")
        DisciplineIconBadge(name: "FEEDBACK AULA PRÁTICA 5")
    }
    .padding()
    .background(VitaColors.surface)
}
