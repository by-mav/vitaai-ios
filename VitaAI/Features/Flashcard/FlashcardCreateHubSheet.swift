import SwiftUI

// MARK: - FlashcardCreateHubSheet — gaveta do "+" (Rafael 2026-07-19)
//
// "Selecione o que você quer fazer": 3 caminhos, cards grandes, de baixo pra
// cima. Referência de IDEIA (concorrente): agent-brain/specs/vitaai/references/
// importacao-magica/1-sheet-3-opcoes.png — o visual é 100% Vita gold glass.
// Spec: agent-brain/specs/vitaai/importacao-magica-flashcards.md
//
// 1. Criar um Baralho   → CreateDeckSheet (nome → tag/disciplina)
// 2. Explorar decks     → comunidade/pré-fabricados
// 3. Criar com o Vita   → importação mágica (PDF · aula · áudio · foto · Anki · colar)

struct FlashcardCreateHubSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreateDeck: () -> Void
    let onExplore: () -> Void
    let onMagicImport: () -> Void

    var body: some View {
        VitaSheet(title: "Selecione o que você quer fazer", detents: [.medium, .large]) {
            VStack(spacing: VitaTokens.Spacing.lg) {
                optionCard(
                    icon: "square.and.pencil",
                    title: "Criar um Baralho",
                    subtitle: "Com cartões personalizados"
                ) { pick(onCreateDeck) }

                optionCard(
                    icon: "sparkle.magnifyingglass",
                    title: "Explorar decks pré-fabricados",
                    subtitle: "Baralhos compartilhados pela comunidade"
                ) { pick(onExplore) }

                optionCard(
                    icon: "wand.and.stars",
                    title: "Criar com o Vita",
                    subtitle: "PDF · aula · áudio · foto · Anki · anotações"
                ) { pick(onMagicImport) }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing._3xl)
        }
    }

    /// Fecha a gaveta e só então dispara — apresentar sheet com outra viva faz o
    /// UIKit cancelar a apresentação (mesmo padrão do openFromMenu do builder).
    private func pick(_ action: @escaping () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            action()
        }
    }

    private func optionCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        HubOptionCard(icon: icon, title: title, subtitle: subtitle, action: action)
    }
}

// MARK: - HubOptionCard — card de opção compartilhado das gavetas de criação
// (usado pela gaveta do "+" e pela "Criar com o Vita" — 1 componente, 2 sheets).

struct HubOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VitaTokens.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 17 : 20, weight: .semibold))  // ds-allow: ícone do card de opção (área de toque)
                    .foregroundStyle(VitaColors.accentLight)
                    .frame(width: compact ? 44 : 52, height: compact ? 44 : 52)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [VitaColors.accent.opacity(0.24), VitaColors.accent.opacity(0.08)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .stroke(VitaColors.glassBorder, lineWidth: 0.75)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))  // ds-allow: chevron do card
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(compact ? VitaTokens.Spacing.lg : VitaTokens.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .fill(VitaColors.glassBg)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .stroke(VitaColors.glassBorder, lineWidth: 0.75)
            )
            .overlay(alignment: .top) {
                // Fio de luz no topo — peça sólida sob luz (canon §2.12).
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [VitaColors.glassHighlight, .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FlashcardCreateHubSheet(onCreateDeck: {}, onExplore: {}, onMagicImport: {})
        .preferredColorScheme(.dark)
}
