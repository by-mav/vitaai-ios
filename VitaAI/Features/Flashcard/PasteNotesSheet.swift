import SwiftUI

// MARK: - PasteNotesSheet — "Colar suas anotações" (Criar com o Vita)
//
// Mini-sheet: cola um texto → POST /api/studio/add-material (fonte ready na
// hora, chunking síncrono) → generateStudyPack só-flashcards → "N flashcards
// criados" → Estudar agora. Estados espelham o StudyMaterialPicker (working/
// done/failed com a mascote), sem duplicar o picker — aqui não há escolha de
// material, só o texto.

struct PasteNotesSheet: View {
    let onOpenDeck: (String) -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var phase: Phase = .editing
    @State private var progressText = ""
    @State private var result: (label: String, deckId: String)?
    @FocusState private var editorFocused: Bool

    private enum Phase: Equatable {
        case editing, working, done
        case failed(String)
    }

    /// Erro com mensagem legível pro estudante (mesmo padrão do StudyMaterialPicker).
    private struct PasteError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Mesmo mínimo da rota (40 chars) — CTA só liga com texto de verdade.
    private var canGenerate: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40
    }

    var body: some View {
        VitaSheet(title: "Colar suas anotações", detents: [.large]) {
            ZStack {
                switch phase {
                case .editing: editingBody
                case .working: workingBody
                case .done: doneBody
                case .failed(let msg): failedBody(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .interactiveDismissDisabled(phase == .working)
    }

    // MARK: - Editing

    private var editingBody: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($editorFocused)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(VitaTokens.Spacing.md)
                    .frame(minHeight: 220, maxHeight: .infinity)
                    .accessibilityIdentifier("paste_notes_editor")
                if text.isEmpty {
                    Text("Cole aqui as tuas anotações de aula, resumo ou trecho de livro...")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                        .padding(VitaTokens.Spacing.md + 5)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .fill(VitaColors.glassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .stroke(VitaColors.glassBorder, lineWidth: 0.75)
            )

            HStack {
                Text(text.isEmpty ? "" : "\(text.count) caracteres")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                Spacer()
            }

            Button {
                editorFocused = false
                Task { await run() }
            } label: {
                Text(canGenerate ? "Gerar flashcards" : "Cole pelo menos algumas frases")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(canGenerate ? VitaColors.surface : VitaColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(canGenerate ? VitaColors.accent : VitaColors.surfaceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .stroke(
                                canGenerate ? VitaColors.accent.opacity(0.9) : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canGenerate)
            .accessibilityIdentifier("paste_notes_generate")
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.bottom, VitaTokens.Spacing.lg)
        .onAppear { editorFocused = true }
    }

    // MARK: - Working / Done / Failed (espelho do StudyMaterialPicker)

    private var workingBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            VitaMascotEquipped(state: .thinking, size: 96)
            Text(progressText.isEmpty ? "Lendo as anotações..." : progressText)
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")  // ds-allow: ícone hero do estado final
                .font(.system(size: 48))  // ds-allow: hero
                .foregroundStyle(VitaColors.accent)
            Text(result?.label ?? "Pronto")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                let deckId = result?.deckId
                dismiss()
                if let deckId { onOpenDeck(deckId) }
            } label: {
                Text("Estudar agora")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.surface)
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .padding(.vertical, VitaTokens.Spacing.md)
                    .background(Capsule().fill(VitaColors.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paste_notes_open_deck")
        }
        .padding(VitaTokens.Spacing._2xl)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedBody(_ msg: String) -> some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")  // ds-allow: ícone de erro
                .font(.system(size: 36))  // ds-allow: hero de erro
                .foregroundStyle(VitaColors.dataRed)
            Text("Não rolou")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Text(msg)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar de novo") { phase = .editing }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.accent)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Run

    private func run() async {
        phase = .working
        progressText = "Lendo as anotações..."
        do {
            let material = try await container.api.addStudioTextMaterial(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            progressText = "Gerando flashcards..."
            let pack = try await container.api.generateStudyPack(
                sourceIds: [material.sourceId],
                title: material.title,
                includeQuestions: false,
                includeFlashcards: true
            )
            guard let deckId = pack.flashcardDeckId, pack.counts.flashcards > 0 else {
                throw PasteError(message: "Não consegui gerar cards desse texto.")
            }
            result = ("\(pack.counts.flashcards) flashcards criados", deckId)
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    PasteNotesSheet(onOpenDeck: { _ in })
        .preferredColorScheme(.dark)
}
