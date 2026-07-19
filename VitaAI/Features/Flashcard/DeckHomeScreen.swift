import SwiftUI

// MARK: - DeckHomeScreen — tela CENTRAL do baralho (Rafael 2026-07-19)
//
// TODO baralho abre aqui (nunca direto nos flashcards) — ref concorrente
// 3-tela-central-baralho.png, visual 100% Vita. Spec:
// agent-brain/specs/vitaai/importacao-magica-flashcards.md §3.
//
// Top bar: voltar · busca (browser de cards) · config · "+" (CardEditorScreen —
// tela JÁ PRONTA, proibido duplicar). Vazio → mascote + "Adicionar cartões";
// com cards → stats + CTA "Estudar agora".

struct DeckHomeScreen: View {
    @Environment(\.appContainer) private var container

    let deckId: String
    var deckTitle: String? = nil
    let onBack: () -> Void
    let onStudy: (String) -> Void

    @State private var deck: FlashcardDeckEntry?
    @State private var loading = true
    @State private var showAddCard = false
    @State private var showBrowser = false
    @State private var showSettings = false

    private var totalCards: Int { deck?.totalCards ?? deck?.cards.count ?? 0 }
    private var dueToday: Int { deck?.dueCount ?? 0 }
    private var title: String { deck?.title ?? deckTitle ?? "Baralho" }

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(title: title, onBack: onBack) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    barButton(icon: "magnifyingglass") { showBrowser = true }
                    barButton(icon: "gearshape") { showSettings = true }
                    barButton(icon: "plus", prominent: true) { showAddCard = true }
                }
            }
            .padding(.bottom, VitaTokens.Spacing.sm)

            if loading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else if totalCards == 0 {
                emptyState
            } else {
                content
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
        .sheet(isPresented: $showAddCard, onDismiss: { Task { await load() } }) {
            CardEditorScreen(onCreated: { Task { await load() } }, presetDeckTitle: title)
        }
        .sheet(isPresented: $showBrowser) {
            CardBrowserScreen(deckId: deckId, deckTitle: title, subjectId: deck?.subjectId)
        }
        .sheet(isPresented: $showSettings) {
            FlashcardSettingsV2Sheet()
        }
        .trackScreen("DeckHome")
    }

    // MARK: - Estados

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VitaEmptyState(
                title: "Vamos começar adicionando alguns cartões",
                message: "Crie frente e verso do seu jeito — ou gere com o Vita a partir do seu material.",
                actionText: "Adicionar cartões",
                onAction: { showAddCard = true }
            )
            Spacer()
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
                statsCard

                Button { onStudy(deckId) } label: {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))  // ds-allow: ícone do CTA
                        Text("Estudar agora")
                            .font(VitaTypography.labelLarge)
                    }
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VitaTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(VitaColors.accent)
                    )
                }
                .buttonStyle(.plain)

                Button { showAddCard = true } label: {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))  // ds-allow: ícone do botão secundário
                        Text("Adicionar cartões")
                            .font(VitaTypography.labelMedium)
                    }
                    .foregroundStyle(VitaColors.accentLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VitaTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(VitaColors.glassBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .stroke(VitaColors.glassBorder, lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing._4xl)
        }
    }

    private var statsCard: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            HStack(spacing: 0) {
                stat(value: "\(totalCards)", label: "cartões")
                Divider().frame(height: 34).overlay(VitaColors.glassBorder)
                stat(value: "\(dueToday)", label: "para hoje")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VitaTokens.Spacing.lg)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.accentLight)
                .monospacedDigit()
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func barButton(icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone da app bar (área de toque)
                .foregroundStyle(prominent ? VitaColors.surface : VitaColors.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(prominent ? VitaColors.accent : VitaColors.glassBg))
                .overlay(Circle().stroke(prominent ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() async {
        if let decks = try? await container.api.getFlashcardDecks(deckLimit: 2000, summary: true) {
            deck = decks.first(where: { $0.id == deckId })
        }
        loading = false
    }
}
