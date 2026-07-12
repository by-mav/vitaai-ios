import SwiftUI

// MARK: - FlashcardQuickModesRow — modos rápidos de estudo (issue #188 I1)
//
// Linha de 2 chips glass logo abaixo do card de stats do FlashcardBuilderScreen:
//  · "Só os que errei"  → sessão server-side modo de erros (cards com lapso)
//  · "Véspera de prova" → sessão server-side modo intensivo (todo o escopo,
//    ignora vencimento — o orçamento diário do backend limita a fila)
// A fila volta em cardIds e chega no FlashcardViewModel via
// FlashcardMultiDeckHandoff.setQuickSession; fila vazia (ex.: nenhum erro
// ainda) vira aviso discreto inline em vez de abrir tela vazia.

/// Resultado de FlashcardBuilderViewModel.createQuickSession.
enum FlashcardQuickSessionOutcome {
    case open(deckId: String)
    case empty
    case failed
}

struct FlashcardQuickModesRow: View {
    let vm: FlashcardBuilderViewModel
    let onOpenDeck: (String) -> Void

    @State private var notice: String? = nil
    /// Modo em criação (trava re-tap enquanto o POST roda).
    @State private var creatingMode: String? = nil
    @State private var noticeDismissTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                GlassChip(label: "Só os que errei", icon: "arrow.counterclockwise") {
                    start(
                        mode: "lapsed",
                        title: "Só os que errei",
                        emptyNotice: "Nenhum cartão com erro ainda"
                    )
                }
                GlassChip(label: "Véspera de prova", icon: "bolt.fill") {
                    start(
                        mode: "cram",
                        title: "Véspera de prova",
                        emptyNotice: "Nenhum cartão pra estudar ainda"
                    )
                }
                Spacer(minLength: 0)
            }
            .opacity(creatingMode == nil ? 1 : 0.55)
            .disabled(creatingMode != nil)

            if let notice {
                Text(notice)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .padding(.leading, VitaTokens.Spacing.xs)
                    .transition(.opacity)
            }
        }
    }

    private func start(mode: String, title: String, emptyNotice: String) {
        guard creatingMode == nil else { return }
        creatingMode = mode
        noticeDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) { notice = nil }
        Task { @MainActor in
            defer { creatingMode = nil }
            switch await vm.createQuickSession(mode: mode, title: title) {
            case .open(let deckId):
                onOpenDeck(deckId)
            case .empty:
                show(emptyNotice)
            case .failed:
                show("Não foi possível montar a sessão agora")
            }
        }
    }

    /// Aviso discreto que some sozinho (não bloqueia nada).
    private func show(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { notice = text }
        noticeDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { notice = nil }
        }
    }
}
