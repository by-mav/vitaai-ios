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

    /// Material solto em cima de um tile: (id do documento, ferramenta).
    /// Assinatura fina de proposito — quem sabe montar a geracao e a tela.
    var onSoltarMaterial: ((String, Ferramenta) -> Void)? = nil

    enum Ferramenta { case questoes, flashcards, simulados, transcricao }

    @State private var avisoEmBreve = false
    /// Tile sob o dedo durante o arrasto (pra dar retorno visual).
    @State private var alvoAtivo: Ferramenta?

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                tile("tool-questoes", id: "tool_questoes", aceita: .questoes, acao: onQuestoes)
                tile("tool-flashcards", id: "tool_flashcards", aceita: .flashcards, acao: onFlashcards)
                tile("tool-simulados", id: "tool_simulados", aceita: .simulados, acao: onSimulados)
            }
            HStack(spacing: VitaTokens.Spacing.sm) {
                tile("tool-transcricao", id: "tool_transcricao", aceita: .transcricao, acao: onTranscricao)
                tile("tool-atlas", id: "tool_atlas3d", acao: onAtlas)
                tile("tool-3dsim", id: "tool_3dsim", emBreve: true, acao: { avisoEmBreve = true })
            }
        }
        .alert("3D Simulator", isPresented: $avisoEmBreve) {
            Button("Entendi", role: .cancel) { }
        } message: {
            Text("Ainda não está pronto — a gente avisa quando abrir.")
        }
    }

    /// A arte JA e o card (moldura, titulo e seta vem pintados). O app nao
    /// desenha rotulo por cima: colidia com o chip de icone da propria arte.
    @ViewBuilder
    private func tile(_ arte: String, id: String, aceita: Ferramenta? = nil,
                      emBreve: Bool = false, acao: @escaping () -> Void) -> some View {
        let destacado = aceita != nil && alvoAtivo == aceita
        Button(action: acao) {
            Image(arte).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
                .overlay(alignment: .top) {
                    if destacado {
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .strokeBorder(VitaColors.accent,
                                          style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                            .padding(VitaTokens.Spacing.xs)
                            .overlay(alignment: .top) {
                                Text("Solte para criar")
                                    .font(VitaTypography.labelSmall)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VitaColors.surface)
                                    .padding(.horizontal, VitaTokens.Spacing.sm)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VitaColors.accent))
                                    .offset(y: -6)
                            }
                    }
                }
                .scaleEffect(destacado ? 1.04 : 1)
                .animation(.easeOut(duration: 0.15), value: destacado)
                .opacity(emBreve ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .modifier(AceitaMaterial(
            ferramenta: aceita,
            alvoAtivo: $alvoAtivo,
            aoSoltar: { docId, f in onSoltarMaterial?(docId, f) }
        ))
    }
}

/// Só os tiles que sabem gerar a partir de material aceitam o arrasto.
private struct AceitaMaterial: ViewModifier {
    let ferramenta: StudyToolsGrid.Ferramenta?
    @Binding var alvoAtivo: StudyToolsGrid.Ferramenta?
    let aoSoltar: (String, StudyToolsGrid.Ferramenta) -> Void

    func body(content: Content) -> some View {
        if let ferramenta {
            content.dropDestination(for: String.self) { ids, _ in
                guard let docId = ids.first else { return false }
                aoSoltar(docId, ferramenta)
                return true
            } isTargeted: { dentro in
                alvoAtivo = dentro ? ferramenta : nil
            }
        } else {
            content
        }
    }
}
