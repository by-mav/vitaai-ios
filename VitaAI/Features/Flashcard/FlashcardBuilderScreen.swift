import SwiftUI
import Sentry

// MARK: - FlashcardBuilderScreen — Fase 5 reescrita gold-standard
//
// Tela única que substitui o builder embutido em FlashcardsListScreen.
// Composição vertical com mode selector visivel inline (Revisao/Especifico/Novos),
// lente operacional só quando mode=.specific, decks grid embaixo, e CTA sticky.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.3 + §11.3
//
// Layout vertical mirror do QBankBuilderScreen mas com diff por pagina conforme
// spec §11.3:
//   Hero → Mode → (Lente só se Specific) → Tags → Especialidades → [colapsadas]
//   → Limite → Decks Grid → CTA

struct FlashcardBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: FlashcardBuilderViewModel?
    // Default state §11.2 — colapsadas: Origem
    // (Instituições, Anos quando A7 publicar wrappers ficam colapsados também;
    // Avançadas (AdvancedSection) já é collapsible nativo com default false)
    /// Baralhos marcados pra estudar juntos (Cardiologia + Medicina de Família...). Rafael 2026-07-10.
    @State private var selectedDeckIds: Set<String> = []
    @State private var showStudioImport = false
    /// Menu do "+" (criar flashcard / criar baralho / gerar do material) — issue #188.
    @State private var showCreateMenu = false
    @State private var showCreateDeck = false
    @State private var showCreateCard = false
    /// Aba da lista de baralhos: Biblioteca (disciplinas canonicas) vs os que o aluno criou.
    @State private var deckTab: DeckTab = .mine
    @State private var deckSearch: String = ""
    @State private var showSessionSettings = false

    private enum DeckTab: String, CaseIterable, Identifiable {
        case mine, biblioteca
        var id: String { rawValue }
    }
    /// Quando vem de DisciplineDetailScreen → flashcardHome(subjectId), pré-seleciona
    /// essa disciplina e abre em mode `.specific`. nil = comportamento padrão (mode `.due`).
    var initialSubjectId: String? = nil
    let onBack: () -> Void
    let onOpenDeck: (String) -> Void

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(StudyShellTheme.flashcards.primaryLight)
            }
        }
        .onAppear {
            if vm == nil {
                vm = FlashcardBuilderViewModel(api: container.api)
                vm?.boot()
                vm?.setInitialSubject(slug: initialSubjectId)
                SentrySDK.reportFullyDisplayed()
            } else {
                // Voltou da sessao (VM viva): re-busca stats+decks pra "hoje"/
                // "pendentes" refletirem as revisoes recem-feitas.
                Task { await vm?.refresh() }
            }
        }
        .navigationBarHidden(true)
        .trackScreen("FlashcardBuilder")
    }

    @ViewBuilder
    private func content(vm: FlashcardBuilderViewModel) -> some View {
        VStack(spacing: 0) {
            appBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GlassTextField(
                        placeholder: "Buscar baralhos",
                        text: $deckSearch,
                        icon: "magnifyingglass"
                    )
                    deckList(vm: vm)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedDeckIds.isEmpty {
                StickyBottomCTA(
                    title: "Estudar selecionados",
                    count: selectedCardsCount(vm: vm),
                    isLoading: false,
                    isCreating: false,
                    theme: .flashcards,
                    action: {
                        FlashcardMultiDeckHandoff.shared.set(Array(selectedDeckIds))
                        if let first = selectedDeckIds.first { onOpenDeck(first) }
                    }
                )
            }
            // Sem selecao nao ha sticky: o hero e o unico CTA primario da tela
            // (havia dois "Estudar agora" competindo — Rafael 2026-07-12).
        }
        .background(Color.clear)
        .sheet(isPresented: $showStudioImport) {
            StudyMaterialPicker(title: "Criar flashcards", actionVerb: "Gerar flashcards") { sourceIds in
                let pack = try await container.api.generateStudyPack(
                    sourceIds: sourceIds, mode: "practice",
                    includeQuestions: false, includeFlashcards: true
                )
                let deckId = pack.flashcardDeckId ?? ""
                return .init(label: "\(pack.counts.flashcards) flashcards criados", open: { onOpenDeck(deckId) })
            }
        }
        .sheet(isPresented: $showSessionSettings) {
            FlashcardSettingsV2Sheet()
        }
        .sheet(isPresented: $showCreateDeck) {
            CreateDeckSheet(onCreated: { Task { await vm.refresh() } })
        }
        .sheet(isPresented: $showCreateCard) {
            CardEditorScreen(onCreated: { Task { await vm.refresh() } })
        }
    }

    // MARK: - App bar (titulo + criar + ajustes) — mockup Rafael 2026-07-10

    private var appBar: some View {
        VitaScreenHeader(title: "Baralhos", onBack: onBack) {
            appBarButton(icon: "plus") { showCreateMenu = true }
                .vitaBubble(isPresented: $showCreateMenu, arrowEdge: .top) { createMenu }
        }
        .padding(.bottom, VitaTokens.Spacing.sm)
    }

    private func appBarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))  // ds-allow: icone da app bar (area de toque)
                .foregroundStyle(icon == "plus" ? VitaColors.surface : VitaColors.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(icon == "plus" ? VitaColors.accent : VitaColors.glassBg)
                )
                .overlay(
                    Circle().stroke(icon == "plus" ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu do "+" — criar flashcard / baralho / gerar do material (issue #188)

    private var createMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            createMenuRow(
                icon: "square.and.pencil",
                title: "Criar flashcard",
                subtitle: "Escreva frente e verso"
            ) { openFromMenu { showCreateCard = true } }
            Divider().overlay(VitaColors.glassBorder.opacity(0.5))
            createMenuRow(
                icon: "rectangle.stack.badge.plus",
                title: "Criar baralho",
                subtitle: "Organize seus cards por tema"
            ) { openFromMenu { showCreateDeck = true } }
            Divider().overlay(VitaColors.glassBorder.opacity(0.5))
            createMenuRow(
                icon: "doc.badge.plus",
                title: "Gerar do meu material",
                subtitle: "PDF, slides ou foto viram cards"
            ) { openFromMenu { showStudioImport = true } }
        }
        .frame(width: 272)
    }

    /// Fecha o bubble e abre a sheet DEPOIS do dismiss — apresentar sheet com o
    /// popover ainda vivo faz o UIKit cancelar a apresentação silenciosamente.
    private func openFromMenu(_ open: @escaping () -> Void) {
        showCreateMenu = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            open()
        }
    }

    private func createMenuRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone do menu (área de toque)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(VitaColors.glassBg))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, VitaTokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero (N para revisar + ilustracao de cards + Estudar agora)

    private func deckList(vm: FlashcardBuilderViewModel) -> some View {
        let all = vm.state.decks
        let byName: (FlashcardDeckEntry, FlashcardDeckEntry) -> Bool = {
            cleanDeckTitle($0.title).localizedCaseInsensitiveCompare(cleanDeckTitle($1.title)) == .orderedAscending
        }
        // Rafael 2026-07-15: baralho curado com < 20 cards não vira linha própria
        // (é fragmento de auto-seed) — some da lista. Os do usuário aparecem sempre.
        let minLibraryCards = 20
        let library = all
            .filter { ($0.userId ?? "").isEmpty && $0.cardCount >= minLibraryCards }
            .sorted(by: byName)
        let mine = all.filter { !($0.userId ?? "").isEmpty }.sorted(by: byName)
        let ordered = library + mine
        let q = deckSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = q.isEmpty ? ordered : ordered.filter { cleanDeckTitle($0.title).lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            if vm.state.decksLoading && all.isEmpty {
                groupsSkeleton
            } else if shown.isEmpty {
                deckTabEmpty
            } else {
                ForEach(shown) { deck in
                    deckRowV2(deck)
                }
            }
        }
    }

    private func deckRowV2(_ deck: FlashcardDeckEntry) -> some View {
        Button(action: { onOpenDeck(deck.id) }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                deckIconTile(deck)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cleanDeckTitle(deck.title))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(deck.cardCount) cartões")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer(minLength: VitaTokens.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.vertical, VitaTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Badge da disciplina — `DisciplineIconBadge` (arte `disc-*` quando conhece a
    /// disciplina, glifo quando não). Era desenhado inline aqui, duplicando o
    /// componente: mudar o badge em um lugar não mudava no outro.
    private func deckIconTile(_ deck: FlashcardDeckEntry) -> some View {
        DisciplineIconBadge(name: deck.disciplineSlug ?? deck.title, size: 50)
    }

    private var deckTabEmpty: some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: deckTab == .biblioteca ? "books.vertical" : "rectangle.stack.badge.plus")
                .font(.system(size: 30))  // ds-allow: icone empty state
                .foregroundStyle(VitaColors.textTertiary)
            Text(deckTab == .biblioteca ? "Nenhuma disciplina encontrada" : "Você ainda não criou baralhos")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing._2xl)
    }

    /// Soma de cards dos baralhos marcados (pro CTA "Estudar selecionados").
    private func selectedCardsCount(vm: FlashcardBuilderViewModel) -> Int {
        vm.visibleDecks().filter { selectedDeckIds.contains($0.id) }.reduce(0) { $0 + $1.cardCount }
    }

    /// Limpa ruído do gerador antigo: "Treino: " e " - Flashcards".
    private func cleanDeckTitle(_ raw: String) -> String {
        var t = raw
        if t.hasPrefix("Treino: ") { t = String(t.dropFirst(8)) }
        for suffix in [" - Flashcards", " \u{2014} Flashcards"] {
            if t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { idx in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(VitaColors.glassBg)
                            .frame(width: 16, height: 16)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VitaColors.glassBg)
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VitaColors.glassBg)
                            .frame(width: 40, height: 12)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .opacity(0.4)
                    if idx < 3 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

}
