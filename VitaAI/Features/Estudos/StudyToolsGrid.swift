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

    /// 3D Simulator ainda nao existe — a propria arte diz "Em breve".
    @State private var avisoEmBreve = false

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            HStack(spacing: VitaTokens.Spacing.md) {
                toolImage("tool-questoes", id: "tool_questoes", action: onQuestoes)
                toolImage("tool-flashcards", id: "tool_flashcards", action: onFlashcards)
            }
            HStack(spacing: VitaTokens.Spacing.md) {
                toolImage("tool-simulados", id: "tool_simulados", action: onSimulados)
                toolImage("tool-transcricao", id: "tool_transcricao", action: onTranscricao)
            }
            HStack(spacing: VitaTokens.Spacing.md) {
                toolImage("tool-atlas", id: "tool_atlas3d", action: onAtlas)
                toolImage("tool-3dsim", id: "tool_3dsim", emBreve: true,
                          action: { avisoEmBreve = true })
            }
        }
        .alert("3D Simulator", isPresented: $avisoEmBreve) {
            Button("Entendi", role: .cancel) { }
        } message: {
            Text("Ainda não está pronto — a gente avisa quando abrir.")
        }
    }

    // A ferramenta E a propria arte (aspecto natural, sem recorte no titulo).
    @ViewBuilder
    private func toolImage(_ name: String, id: String, emBreve: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // A arte ja vem com fundo transparente e moldura/brilho proprios
            // (fundo branco removido com rembg em 2026-07-23). Nao colocar
            // background nem stroke por baixo: reintroduz o quadradao.
            Image(name).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
                // Em breve fica levemente recuado: da pra ver, mas nao chama.
                .opacity(emBreve ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
