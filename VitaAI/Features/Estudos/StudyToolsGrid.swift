import SwiftUI

// MARK: - StudyToolsGrid — cards de IMAGEM das ferramentas de estudo (topo do Estudos)
//
// Rafael 2026-07-15: as imagens bonitas (tool-*) voltaram pro topo do Estudos,
// no lugar do hero. A arte JÁ traz título + ícone + seta — o card é a própria
// PNG. As 4 ferramentas principais (Questões/Flashcards/Simulados/Transcrição)
// num 2x2. O Atlas 3D não é uma dessas 4 imagens: fica como cartão de vidro
// compacto embaixo (secundário, não compete visualmente com as 4).

struct StudyToolsGrid: View {
    var onQuestoes: () -> Void = {}
    var onFlashcards: () -> Void = {}
    var onSimulados: () -> Void = {}
    var onTranscricao: () -> Void = {}
    var onAtlas: () -> Void = {}
    var showsAtlas: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                toolImage("tool-questoes", id: "tool_questoes", action: onQuestoes)
                toolImage("tool-flashcards", id: "tool_flashcards", action: onFlashcards)
            }
            HStack(spacing: 10) {
                toolImage("tool-simulados", id: "tool_simulados", action: onSimulados)
                toolImage("tool-transcricao", id: "tool_transcricao", action: onTranscricao)
            }
            if showsAtlas {
                atlasCard
            }
        }
    }

    // As 4 ferramentas = a própria arte tool-* (aspecto natural, sem recorte no título).
    @ViewBuilder
    private func toolImage(_ name: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(name).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(VitaColors.surfaceCard.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))  // ds-allow: card de ferramenta (arte tool-*) — igual ao original
                .overlay(
                    RoundedRectangle(cornerRadius: 14)  // ds-allow: card de ferramenta (arte tool-*) — igual ao original
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 5)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // Atlas 3D = cartão de vidro compacto (secundário às 4 imagens). Emblema
    // dourado + rótulo + seta, mesma física de luz do restante do DS.
    private var atlasCard: some View {
        Button(action: onAtlas) {
            HStack(spacing: 12) {
                VitaEmblem(symbol: "brain.head.profile", size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atlas 3D")
                        .font(.system(size: 14, weight: .bold))  // ds-allow: rótulo do card de ferramenta (consistente com os antigos)
                        .foregroundStyle(VitaColors.textWarm.opacity(0.92))
                    Text("Anatomia interativa")
                        .font(.system(size: 11))  // ds-allow: subtítulo do card de ferramenta
                        .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))  // ds-allow: chevron do card de ferramenta
                    .foregroundStyle(VitaColors.textWarm.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tool_atlas3d")
        .accessibilityLabel("Atlas 3D")
    }
}
