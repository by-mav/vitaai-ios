import SwiftUI

// MARK: - CardComposerSheet — criar / editar 1 card (frente + verso)
//
// Sheet leve do Card Browser: dois campos (frente/verso) em superfície de
// vidro Vita. Serve pros dois casos:
//   • .create → cria no baralho atual (VM.createCard)
//   • .edit   → salva frente/verso (VM.updateCard, PATCH)
//
// Sub-tela de detalhe = .sheet com fundo material (lei do shell). O card real
// rico (imagem/formatação) é o CardEditorScreen; aqui é o editor rápido de
// texto que o browser precisa (inline, sem sair da lista).

enum CardComposerTarget: Identifiable {
    case create
    case edit(FlashcardEntry)

    var id: String {
        switch self {
        case .create:            return "create"
        case .edit(let card):    return "edit-\(card.id)"
        }
    }
}

struct CardComposerSheet: View {
    let target: CardComposerTarget
    let deckTitle: String
    /// Retorna true se a operação foi concluída com sucesso (pra fechar).
    let onSubmit: (_ front: String, _ back: String) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var front: String
    @State private var back: String
    @State private var isSaving = false
    @FocusState private var focus: Field?

    private enum Field { case front, back }

    init(
        target: CardComposerTarget,
        deckTitle: String,
        onSubmit: @escaping (_ front: String, _ back: String) async -> Bool
    ) {
        self.target = target
        self.deckTitle = deckTitle
        self.onSubmit = onSubmit
        switch target {
        case .create:
            _front = State(initialValue: "")
            _back = State(initialValue: "")
        case .edit(let card):
            _front = State(initialValue: card.front)
            _back = State(initialValue: card.back)
        }
    }

    private var isEditing: Bool { if case .edit = target { return true }; return false }

    private var canSave: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
                    field(label: "FRENTE", text: $front, placeholder: "Pergunta ou caso clínico…", field: .front)
                    field(label: "VERSO", text: $back, placeholder: "Resposta…", field: .back)
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.top, VitaTokens.Spacing.lg)
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
        .onAppear { focus = .front }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancelar")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(isEditing ? "Editar card" : "Novo card")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(deckTitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button { Task { await submit() } } label: {
                Text(isSaving ? "…" : "Salvar")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(canSave ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.top, VitaTokens.Spacing.md)
    }

    // MARK: Campo de texto

    private func field(label: String, text: Binding<String>, placeholder: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text(label)
                .font(VitaTypography.labelSmall)
                .kerning(1.0)
                .foregroundStyle(VitaColors.accentLight.opacity(0.7))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textTertiary)
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .tint(VitaColors.accent)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: field)
                    .frame(minHeight: 120)
                    .padding(.horizontal, VitaTokens.Spacing.md)
                    .padding(.vertical, VitaTokens.Spacing.sm)
            }
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .stroke(focus == field ? VitaColors.accent.opacity(0.4) : VitaColors.glassBorder, lineWidth: 1)
            )
        }
    }

    // MARK: Ação

    private func submit() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        let ok = await onSubmit(front, back)
        isSaving = false
        if ok {
            PixioHaptics.tap()
            dismiss()
        }
    }
}

#if DEBUG
#Preview("CardComposerSheet — novo") {
    CardComposerSheet(target: .create, deckTitle: "Cardiologia") { _, _ in true }
}
#endif
