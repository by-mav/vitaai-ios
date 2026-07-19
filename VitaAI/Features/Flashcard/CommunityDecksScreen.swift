import SwiftUI

// MARK: - CommunityDecksScreen — "Explorar decks pré-fabricados" (Rafael 2026-07-19)
//
// Marketplace estilo Anki shared decks (ref 4-explorar-decks-comunidade.png):
// busca + chips de área + lista (ícone · título · N cartões). v1 lista os decks
// pré-fabricados da Biblioteca Vita (scope=library, por disciplina); decks
// PUBLICADOS pela comunidade entram quando o publish existir (follow-up no spec).
// Spec: agent-brain/specs/vitaai/importacao-magica-flashcards.md §1.2

struct CommunityDecksScreen: View {
    @Environment(\.appContainer) private var container

    let onBack: () -> Void
    /// Abre o estudo da disciplina da Biblioteca (mesma rota que a lista de Baralhos usa).
    let onOpenDiscipline: (FlashcardLibraryDiscipline) -> Void

    @State private var search = ""
    @State private var areas: [FlashcardLibraryArea] = []
    @State private var selectedAreaSlug: String? = nil
    @State private var loading = true

    private var disciplines: [FlashcardLibraryDiscipline] {
        let base = areas
            .filter { selectedAreaSlug == nil || $0.slug == selectedAreaSlug }
            .flatMap(\.disciplines)
        let q = search.trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? base : base.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return list.sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(title: "Explorar decks", onBack: onBack) { EmptyView() }
                .padding(.bottom, VitaTokens.Spacing.sm)

            VStack(spacing: VitaTokens.Spacing.md) {
                GlassTextField(placeholder: "Pesquisar", text: $search, icon: "magnifyingglass")
                    .padding(.horizontal, VitaTokens.Spacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        chip(label: "Todos", slug: nil)
                        ForEach(areas) { area in
                            chip(label: area.name, slug: area.slug)
                        }
                    }
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                }
            }
            .padding(.bottom, VitaTokens.Spacing.md)

            if loading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: VitaTokens.Spacing.sm) {
                        ForEach(disciplines) { d in
                            deckRow(d)
                        }
                    }
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                    .padding(.bottom, VitaTokens.Spacing._4xl)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            guard areas.isEmpty else { return }
            if let lib = try? await container.api.getFlashcardLibrary() {
                areas = lib.areas
            }
            loading = false
        }
        .trackScreen("CommunityDecks")
    }

    private func chip(label: String, slug: String?) -> some View {
        let isSelected = selectedAreaSlug == slug
        return Button { selectedAreaSlug = slug } label: {
            Text(label)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(isSelected ? VitaColors.surface : VitaColors.textSecondary)
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.vertical, VitaTokens.Spacing.sm)
                .background(Capsule().fill(isSelected ? VitaColors.accent : VitaColors.glassBg))
                .overlay(Capsule().stroke(isSelected ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    private func deckRow(_ d: FlashcardLibraryDiscipline) -> some View {
        let spec = DisciplineImages.iconSpec(for: d.name)
        return Button { onOpenDiscipline(d) } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: spec.symbol)
                    .font(.system(size: 17, weight: .semibold))  // ds-allow: ícone da disciplina (área de toque)
                    .foregroundStyle(spec.color)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .fill(spec.color.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .stroke(VitaColors.glassBorder, lineWidth: 0.75)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(d.total) cartões")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))  // ds-allow: chevron da linha
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
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
}
