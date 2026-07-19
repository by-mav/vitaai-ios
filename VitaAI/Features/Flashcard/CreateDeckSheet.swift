import SwiftUI

// MARK: - CreateDeckSheet — criação manual de baralho (issue vitaai-web#188)
//
// Fluxo em 2 passos (Rafael 2026-07-19, refs 1/2 em specs/vitaai/references/
// importacao-magica): NOME → TAG (disciplina, com busca + "Outro") → cria e
// abre a TELA CENTRAL do baralho. POST /api/study/flashcards/decks via
// VitaAPI.createDeck(title:disciplineSlug:) — idempotente por título.
// Irmã visual da FlashcardSettingsV2Sheet: section label uppercase,
// campos glass, CTA cheio em accent.

struct CreateDeckSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    /// Chamado após criar com sucesso — o builder usa pra recarregar os baralhos.
    var onCreated: () -> Void = {}
    /// Quando presente, recebe (deckId, title) pra navegar pra tela central do baralho.
    var onCreatedDeck: ((String, String) -> Void)? = nil

    private enum Step { case name, tag }

    @State private var step: Step = .name
    @State private var title = ""
    @State private var tagSlug: String? = nil
    @State private var tagName: String? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VitaSheet(
            title: step == .name ? "Novo baralho" : "Selecione uma tag",
            detents: step == .name ? [.medium] : [.large]
        ) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing._2xl) {
                switch step {
                case .name:
                    section(title: "Nome", subtitle: "Como o baralho aparece em Meus baralhos.") {
                        GlassTextField(
                            placeholder: "Ex.: Cardiologia — Arritmias",
                            text: $title,
                            icon: "rectangle.stack"
                        )
                    }
                case .tag:
                    section(title: "Disciplina", subtitle: "Pode ser alterada depois nas configurações do baralho.") {
                        DeckTagPickerView(selectedSlug: $tagSlug, selectedName: $tagName)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.danger)
                }
                ctaButton
                if step == .name { Spacer(minLength: 0) }
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing._3xl)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            switch step {
            case .name:
                withAnimation(.easeInOut(duration: 0.2)) { step = .tag }
            case .tag:
                Task { await create() }
            }
        } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                if isSaving {
                    ProgressView().tint(VitaColors.surface)
                } else {
                    Image(systemName: step == .name ? "arrow.right" : "checkmark")
                        .font(.system(size: 13, weight: .bold))  // ds-allow: ícone do CTA
                }
                Text(step == .name ? "Continuar" : (isSaving ? "Criando…" : "Salvar"))
                    .font(VitaTypography.labelMedium)
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
        .disabled(trimmedTitle.isEmpty || isSaving)
        .opacity(trimmedTitle.isEmpty || isSaving ? 0.5 : 1)
    }

    private func create() async {
        guard !trimmedTitle.isEmpty, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            let resp = try await container.api.createDeck(title: trimmedTitle, disciplineSlug: tagSlug)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCreated()
            dismiss()
            if let id = resp.id, let onCreatedDeck {
                // Abre a tela central DEPOIS do dismiss (mesmo padrão openFromMenu:
                // apresentar navegação com a sheet viva faz o UIKit cancelar).
                let deckTitle = resp.title ?? trimmedTitle
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    onCreatedDeck(id, deckTitle)
                }
            }
        } catch {
            errorMessage = "Não foi possível criar o baralho. Tente de novo."
        }
        isSaving = false
    }

    // MARK: - Section shell (mesmo padrão da FlashcardSettingsV2Sheet)

    private func section<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))  // ds-allow: label de seção (kerning)
                    .kerning(0.5)
                    .foregroundStyle(VitaColors.sectionLabel)
                if let subtitle {
                    Text(subtitle).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textTertiary)
                }
            }
            content()
        }
    }
}
