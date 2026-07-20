import SwiftUI
import UniformTypeIdentifiers

// MARK: - AnkiImportSheet — "Importar do Anki" (Criar com o Vita)
//
// Picker de arquivo .apkg → upload multipart → progresso com a mascote →
// "N cards em M baralhos" → abrir o primeiro baralho. O motor é o backend
// (POST /api/study/flashcards/import-anki): parser v11, mídia via R2, cards
// nascem NEW no nosso FSRS. Formato novo do Anki (anki21b) volta 400 com
// instrução de re-exportar — a mensagem do servidor aparece no failed.

struct AnkiImportSheet: View {
    let onOpenDeck: (String) -> Void
    /// Chamado quando o import terminou (refresh da lista de baralhos).
    var onImported: () -> Void = {}

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .picking
    @State private var showFilePicker = false
    @State private var result: VitaAPI.AnkiImportResponse?

    private enum Phase: Equatable {
        case picking, working, done
        case failed(String)
    }

    /// .apkg não tem UTType registrado no sistema — cai pro genérico.
    private static let apkgTypes: [UTType] = [UTType(filenameExtension: "apkg") ?? .data, .zip, .data]

    var body: some View {
        VitaSheet(title: "Importar do Anki", detents: [.large]) {
            ZStack {
                switch phase {
                case .picking: pickingBody
                case .working: workingBody
                case .done: doneBody
                case .failed(let msg): failedBody(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .interactiveDismissDisabled(phase == .working)
        // vita-modals-ignore: seletor de arquivo é UI de sistema
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView(allowedTypes: Self.apkgTypes) { url in
                importFile(url)
            }
        }
    }

    // MARK: - Picking

    private var pickingBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "square.and.arrow.down.on.square")  // ds-allow: ícone hero da sheet
                .font(.system(size: 44, weight: .light))  // ds-allow: hero
                .foregroundStyle(VitaColors.accentLight)
            Text("Traga teus baralhos do Anki")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                explainRow(icon: "doc.zipper", text: "Escolha o arquivo .apkg exportado do Anki")
                explainRow(icon: "photo", text: "Imagens dos cards vêm junto")
                explainRow(icon: "sparkles", text: "Cada deck vira um baralho novo aqui")
            }
            .padding(VitaTokens.Spacing.lg)
            .glassCard(cornerRadius: 16)

            Button {
                showFilePicker = true
            } label: {
                Text("Escolher arquivo .apkg")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(VitaColors.accent)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("anki_pick_file")
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func explainRow(icon: String, text: String) -> some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: icon)  // ds-allow: ícone da linha explicativa
                .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone
                .foregroundStyle(VitaColors.accent)
                .frame(width: 24)
            Text(text)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
    }

    // MARK: - Working / Done / Failed (mesmo padrão do StudyMaterialPicker)

    private var workingBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            VitaMascotEquipped(state: .thinking, size: 96)
            Text("Importando teus baralhos...")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneBody: some View {
        let decks = result?.decks ?? []
        return VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")  // ds-allow: ícone hero do estado final
                .font(.system(size: 48))  // ds-allow: hero
                .foregroundStyle(VitaColors.accent)
            Text("\(result?.totalCards ?? 0) cards em \(decks.count) \(decks.count == 1 ? "baralho" : "baralhos")")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
            ForEach(decks.prefix(4), id: \.deckId) { deck in
                HStack {
                    Text(deck.title)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(deck.cards) cards")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.vertical, VitaTokens.Spacing.sm)
                .glassCard(cornerRadius: 12)
            }
            Button {
                let first = decks.first?.deckId
                dismiss()
                if let first { onOpenDeck(first) }
            } label: {
                Text("Abrir baralho")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.surface)
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .padding(.vertical, VitaTokens.Spacing.md)
                    .background(Capsule().fill(VitaColors.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("anki_open_deck")
        }
        .padding(VitaTokens.Spacing._2xl)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, VitaTokens.Spacing.xl)
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
            Button("Tentar de novo") { phase = .picking }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.accent)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import

    private func importFile(_ url: URL) {
        showFilePicker = false
        guard let data = try? Data(contentsOf: url) else {
            phase = .failed("Não consegui abrir esse arquivo.")
            return
        }
        guard data.count <= 200 * 1_024 * 1_024 else {
            phase = .failed("O arquivo precisa ter até 200 MB.")
            return
        }
        phase = .working
        Task { @MainActor in
            do {
                let response = try await container.api.importAnkiDeck(
                    fileData: data, fileName: url.lastPathComponent
                )
                result = response
                phase = .done
                onImported()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    AnkiImportSheet(onOpenDeck: { _ in })
        .preferredColorScheme(.dark)
}
