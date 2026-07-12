import SwiftUI

// MARK: - CreateDeckSheet — criação manual de baralho (issue vitaai-web#188)
//
// Aberta pelo menu "+" do FlashcardBuilderScreen. POST /api/study/flashcards/decks
// via VitaAPI.createDeck(title:) — idempotente por título (server reusa se já
// existe). Irmã visual da FlashcardSettingsV2Sheet: section label uppercase,
// campos glass, CTA cheio em accent.

struct CreateDeckSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    /// Chamado após criar com sucesso — o builder usa pra recarregar os baralhos.
    var onCreated: () -> Void = {}

    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VitaSheet(title: "Novo baralho", detents: [.medium]) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing._2xl) {
                section(title: "Nome", subtitle: "Como o baralho aparece em Meus baralhos.") {
                    GlassTextField(
                        placeholder: "Ex.: Cardiologia — Arritmias",
                        text: $title,
                        icon: "rectangle.stack"
                    )
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.danger)
                }
                createButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing._3xl)
        }
    }

    // MARK: - CTA

    private var createButton: some View {
        Button {
            Task { await create() }
        } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                if isSaving {
                    ProgressView().tint(VitaColors.surface)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))  // ds-allow: ícone do CTA
                }
                Text(isSaving ? "Criando…" : "Criar baralho")
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
            _ = try await container.api.createDeck(title: trimmedTitle)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCreated()
            dismiss()
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
