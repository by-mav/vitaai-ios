import SwiftUI

// MARK: - DeckTagPickerView — "Selecione uma tag" (disciplina do baralho)
//
// Passo 2 do Criar Baralho (Rafael 2026-07-19): em vez das tags genéricas do
// concorrente (Biologia/Direito/Matemática — ref 2-selecione-tag.png), lista as
// NOSSAS disciplinas de medicina (taxonomia canônica, via biblioteca) com busca
// no topo e a opção "Outro" primeiro. Pode ser trocada depois nas config do deck.
// Spec: agent-brain/specs/vitaai/importacao-magica-flashcards.md

struct DeckTagPickerView: View {
    @Environment(\.appContainer) private var container

    /// slug selecionado (nil = "Outro" / sem disciplina).
    @Binding var selectedSlug: String?
    /// Nome humano da seleção — o pai usa pra exibir/salvar.
    @Binding var selectedName: String?

    @State private var search = ""
    @State private var disciplines: [FlashcardLibraryDiscipline] = []
    @State private var loading = true

    private var filtered: [FlashcardLibraryDiscipline] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return disciplines }
        return disciplines.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            GlassTextField(placeholder: "Buscar disciplina", text: $search, icon: "magnifyingglass")

            ScrollView(showsIndicators: false) {
                VStack(spacing: VitaTokens.Spacing.sm) {
                    row(slug: nil, name: "Outro", symbol: "books.vertical", tint: VitaColors.textSecondary)

                    if loading {
                        HStack {
                            Spacer()
                            ProgressView().tint(VitaColors.accent).padding(.top, VitaTokens.Spacing.xl)
                            Spacer()
                        }
                    } else {
                        ForEach(filtered) { d in
                            let spec = DisciplineImages.iconSpec(for: d.name)
                            row(slug: d.slug, name: d.name, symbol: spec.symbol, tint: spec.color)
                        }
                    }
                }
                .padding(.bottom, VitaTokens.Spacing._2xl)
            }
        }
        .task {
            guard disciplines.isEmpty else { return }
            if let lib = try? await container.api.getFlashcardLibrary() {
                disciplines = lib.areas
                    .flatMap(\.disciplines)
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            loading = false
        }
    }

    private func row(slug: String?, name: String, symbol: String, tint: Color) -> some View {
        let isSelected = selectedSlug == slug && (slug != nil || selectedName == "Outro" || selectedName == nil)
        return Button {
            selectedSlug = slug
            selectedName = name
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone da disciplina (área de toque)
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(tint.opacity(0.14)))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))

                Text(name)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))  // ds-allow: check de seleção
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .fill(isSelected ? VitaColors.accent.opacity(0.12) : VitaColors.glassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .stroke(isSelected ? VitaColors.accent.opacity(0.45) : VitaColors.glassBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}
