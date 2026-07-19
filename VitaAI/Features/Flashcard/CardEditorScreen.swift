import SwiftUI
import PhotosUI

// MARK: - CardEditorScreen — criar card ESCREVENDO NO CARD REAL
//
// O editor É o card (superfície canônica FlashcardCardSurface, a mesma do estudo):
// o aluno escreve direto na frente, troca pro verso, formata (negrito/itálico/
// lista) e coloca imagem no próprio card. Não há "prévia" — o card é o que ele vê.
// Design canônico: fundo VitaAmbientBackground + header, igual à sessão de estudo.

struct CardEditorScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    var onCreated: () -> Void = {}
    /// Baralho pré-selecionado (tela central do baralho abre o editor já mirando ele).
    var presetDeckTitle: String? = nil

    @State private var front = ""
    @State private var back = ""
    @State private var editingBack = false
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var myDecks: [FlashcardDeckEntry] = []
    @State private var selectedDeckTitle: String?
    @State private var newDeckName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedFlash = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VitaAmbientBackground {
            VStack(spacing: 0) {
                header
                faceToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                cardEditor
                    .frame(height: hSize == .regular ? 460 : 340)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                Spacer(minLength: 12)
                bottomControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .task { await loadDecks() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { item in
            Task { await loadPickedImage(item) }
        }
    }

    // MARK: Header — fechar | título | salvar

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VitaColors.glassBg))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
            }
            Spacer()
            Text("Novo card")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
            Button { Task { await save() } } label: {
                Text(isSaving ? "…" : "Salvar")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(canSave ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(minWidth: 36, minHeight: 36)
            }
            .disabled(!canSave || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Frente / Verso

    private var faceToggle: some View {
        HStack(spacing: 4) {
            faceTab("Frente", active: !editingBack) { withAnimation(.easeInOut(duration: 0.2)) { editingBack = false } }
            faceTab("Verso", active: editingBack) { withAnimation(.easeInOut(duration: 0.2)) { editingBack = true } }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: VitaTokens.Radius.md).fill(VitaColors.glassBg))
        .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.md).stroke(VitaColors.glassBorder, lineWidth: 1))
    }

    private func faceTab(_ title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(active ? VitaColors.surface : VitaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                        .fill(active ? VitaColors.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: O CARD (editável)

    private var cardEditor: some View {
        VStack(spacing: 12) {
            Text(editingBack ? "VERSO" : "FRENTE")
                .font(.system(size: 10, weight: .bold))  // ds-allow: tag do card (kerning)
                .kerning(1.0)
                .foregroundStyle(VitaColors.accentLight.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let img = editingBack ? backImage : frontImage {
                imageOnCard(img)
            }

            RichCardEditor(
                text: editingBack ? $back : $front,
                placeholder: editingBack ? "Escreva a resposta…" : "Escreva a pergunta ou o caso clínico…",
                fontSize: 20,
                centered: true,
                onImage: { showPhotoPicker = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .flashcardCardSurface()
    }

    // Imagem no card: preenche a largura, arredondada com borda sutil (parece parte
    // do card), altura generosa mantendo o aspecto. Sem redimensionar na mão (v1) —
    // auto-fit goldstandard; crop/resize manual pode vir depois.
    private func imageOnCard(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 190)
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    if editingBack { backImage = nil } else { frontImage = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .padding(8)
            }
    }

    // MARK: Baralho + salvar

    private var bottomControls: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            deckMenu
            if selectedDeckTitle == nil {
                GlassTextField(placeholder: "Nome do novo baralho", text: $newDeckName, icon: "plus.rectangle.on.rectangle")
            }
            if savedFlash {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.success)
                    Text("Card criado").font(VitaTypography.labelMedium).foregroundStyle(VitaColors.textSecondary)
                }
                .transition(.opacity)
            }
            if let errorMessage {
                Text(errorMessage).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.danger)
            }
        }
    }

    private var deckMenu: some View {
        Menu {
            ForEach(myDecks) { deck in
                Button(cleanTitle(deck.title)) { selectedDeckTitle = deck.title }
            }
            if !myDecks.isEmpty { Divider() }
            Button { selectedDeckTitle = nil } label: { Label("Novo baralho…", systemImage: "plus") }
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "rectangle.stack").foregroundStyle(VitaColors.textTertiary).frame(width: 20)
                Text(selectedDeckTitle.map(cleanTitle) ?? "Novo baralho…")
                    .font(VitaTypography.bodyMedium).foregroundStyle(VitaColors.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, 14)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).stroke(VitaColors.glassBorder, lineWidth: 1))
        }
    }

    // MARK: Estado + ações

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
            if selectedDeckTitle == nil { selectedDeckTitle = deckTitle }
            front = ""; back = ""; frontImage = nil; backImage = nil; newDeckName = ""
            editingBack = false
            onCreated()
            withAnimation(.easeOut(duration: 0.2)) { savedFlash = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.3)) { savedFlash = false }
            }
            await loadDecks()
        } catch {
            errorMessage = "Não foi possível salvar o card. Tente de novo."
        }
        isSaving = false
    }

    private func loadDecks() async {
        guard let decks = try? await container.api.getFlashcardDecks(deckLimit: 2000, summary: true) else { return }
        myDecks = decks
            .filter { !($0.userId ?? "").isEmpty }
            .sorted { cleanTitle($0.title).localizedCaseInsensitiveCompare(cleanTitle($1.title)) == .orderedAscending }
        if selectedDeckTitle == nil, let presetDeckTitle {
            selectedDeckTitle = presetDeckTitle
        }
    }

    @MainActor
    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
        if editingBack { backImage = img } else { frontImage = img }
        photoItem = nil
    }

    private func cleanTitle(_ raw: String) -> String {
        var t = raw
        if t.hasPrefix("Treino: ") { t = String(t.dropFirst(8)) }
        for suffix in [" - Flashcards", " \u{2014} Flashcards"] {
            if t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
