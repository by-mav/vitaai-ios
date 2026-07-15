import SwiftUI

// MARK: - CreateCardSheet — criação manual de flashcard (issue vitaai-web#188)
//
// Aberta pelo menu "+" do FlashcardBuilderScreen. POST /api/study/flashcards
// via VitaAPI.createFlashcard(front:back:deckTitle:) — o server cria/reusa o
// baralho pelo título. Permite criar vários em sequência: salva, limpa os
// campos e mantém o baralho escolhido. Irmã visual da FlashcardSettingsV2Sheet
// (section labels uppercase, campos glass, CTA cheio em accent).

struct CreateCardSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    /// Chamado a cada card criado — o builder usa pra recarregar decks/contadores.
    var onCreated: () -> Void = {}

    @State private var front = ""
    @State private var back = ""
    /// Baralhos do aluno (userId presente) pro seletor. Biblioteca fica fora.
    @State private var myDecks: [FlashcardDeckEntry] = []
    /// Título RAW do baralho escolhido (server resolve por título). nil = novo baralho.
    @State private var selectedDeckTitle: String?
    @State private var newDeckName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedFlash = false

    var body: some View {
        VitaSheet(title: "Novo flashcard", detents: [.large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing._2xl) {
                    section(title: "Frente — pergunta ou caso clínico", subtitle: nil) {
                        glassEditor(
                            text: $front,
                            placeholder: "Ex.: Qual o tratamento de primeira linha da HAS?"
                        )
                    }
                    section(title: "Verso — resposta", subtitle: nil) {
                        glassEditor(
                            text: $back,
                            placeholder: "Ex.: IECA ou BRA, tiazídico ou BCC"
                        )
                    }
                    section(title: "Baralho", subtitle: "Onde o card entra. Crie um novo se precisar.") {
                        VStack(spacing: VitaTokens.Spacing.md) {
                            deckMenu
                            if selectedDeckTitle == nil {
                                GlassTextField(
                                    placeholder: "Nome do novo baralho",
                                    text: $newDeckName,
                                    icon: "plus.rectangle.on.rectangle"
                                )
                            }
                        }
                    }
                    if hasContent {
                        section(title: "Prévia", subtitle: "Como o card vai aparecer no estudo.") {
                            previewCard
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.danger)
                    }
                    if savedFlash {
                        confirmation
                    }
                    saveButton
                    closeButton
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
                .padding(.top, VitaTokens.Spacing.md)
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
        }
        .task { await loadDecks() }
    }

    // MARK: - Seletor de baralho

    private var deckMenu: some View {
        Menu {
            ForEach(myDecks) { deck in
                Button(cleanTitle(deck.title)) { selectedDeckTitle = deck.title }
            }
            if !myDecks.isEmpty {
                Divider()
            }
            Button {
                selectedDeckTitle = nil
            } label: {
                Label("Novo baralho…", systemImage: "plus")
            }
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "rectangle.stack")
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 20)
                Text(selectedDeckTitle.map(cleanTitle) ?? "Novo baralho…")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, 14)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))  // ds-allow: espelha o radius 14 do GlassTextField canonico
            .overlay(
                RoundedRectangle(cornerRadius: 14)  // ds-allow: espelha o radius 14 do GlassTextField canonico
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Confirmação sutil (criar vários em sequência)

    private var confirmation: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))  // ds-allow: ícone da confirmação
                .foregroundStyle(VitaColors.success)
            Text("Flashcard criado")
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - CTAs

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                if isSaving {
                    ProgressView().tint(VitaColors.surface)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))  // ds-allow: ícone do CTA
                }
                Text(isSaving ? "Salvando…" : "Salvar flashcard")
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
        .disabled(!canSave || isSaving)
        .opacity(!canSave || isSaving ? 0.5 : 1)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("Fechar")
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VitaTokens.Spacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Estado derivado

    /// Título que vai pro server: baralho existente escolhido OU o nome digitado.
    private var targetDeckTitle: String? {
        if let selectedDeckTitle { return selectedDeckTitle }
        let name = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private var canSave: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        targetDeckTitle != nil
    }

    // MARK: - Ações

    private func save() async {
        guard canSave, !isSaving, let deckTitle = targetDeckTitle else { return }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await container.api.createFlashcard(
                front: front.trimmingCharacters(in: .whitespacesAndNewlines),
                back: back.trimmingCharacters(in: .whitespacesAndNewlines),
                deckTitle: deckTitle
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Baralho novo agora existe no server: vira seleção fixa pra criar
            // vários em sequência no mesmo baralho.
            if selectedDeckTitle == nil { selectedDeckTitle = deckTitle }
            front = ""
            back = ""
            newDeckName = ""
            onCreated()
            withAnimation(.easeOut(duration: 0.2)) { savedFlash = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.3)) { savedFlash = false }
            }
            await loadDecks()
        } catch {
            errorMessage = "Não foi possível salvar o flashcard. Tente de novo."
        }
        isSaving = false
    }

    private func loadDecks() async {
        guard let decks = try? await container.api.getFlashcardDecks(deckLimit: 2000, summary: true) else { return }
        myDecks = decks
            .filter { !($0.userId ?? "").isEmpty }
            .sorted { cleanTitle($0.title).localizedCaseInsensitiveCompare(cleanTitle($1.title)) == .orderedAscending }
    }

    // MARK: - Helpers

    /// Limpa ruído do gerador antigo pra EXIBIÇÃO (o server continua recebendo o
    /// título raw). Mesma regra do cleanDeckTitle do FlashcardBuilderScreen.
    private func cleanTitle(_ raw: String) -> String {
        var t = raw
        if t.hasPrefix("Treino: ") { t = String(t.dropFirst(8)) }
        for suffix in [" - Flashcards", " \u{2014} Flashcards"] {
            if t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Editor rico (barra negrito/itálico/listas) no visual GlassTextField.
    private func glassEditor(text: Binding<String>, placeholder: String) -> some View {
        RichCardEditor(text: text, placeholder: placeholder)
            .frame(minHeight: 110)
            .padding(.horizontal, VitaTokens.Spacing.sm)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))  // ds-allow: espelha o radius 14 do GlassTextField canonico
            .overlay(
                RoundedRectangle(cornerRadius: 14)  // ds-allow: espelha o radius 14 do GlassTextField canonico
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
    }

    // MARK: - Prévia ao vivo (renderizador REAL do card → mesma tipografia/estrutura)

    private var hasContent: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            previewFace(label: "FRENTE", content: front)
            Divider().background(VitaColors.glassBorder)
            previewFace(label: "VERSO", content: back)
        }
        .padding(VitaTokens.Spacing.lg)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    private func previewFace(label: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))  // ds-allow: label da prévia (kerning)
                .kerning(1)
                .foregroundStyle(VitaColors.sectionLabel)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("—").font(VitaTypography.bodyMedium).foregroundStyle(VitaColors.textTertiary)
            } else {
                FlashcardContentView(
                    content: content,
                    fontSize: 16,
                    textColor: VitaColors.textPrimary,
                    alignment: .leading
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
