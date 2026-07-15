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
    @State private var originExpanded: Bool = false
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
        var label: String { self == .biblioteca ? "Biblioteca" : "Meus baralhos" }
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
                vm = FlashcardBuilderViewModel(api: container.api, dataManager: container.dataManager)
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
                    heroCard(vm: vm)
                    statsCard(vm: vm)
                    GlassTextField(
                        placeholder: deckTab == .biblioteca ? "Buscar disciplina" : "Buscar baralhos",
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
            CreateCardSheet(onCreated: { Task { await vm.refresh() } })
        }
    }

    // MARK: - App bar (titulo + criar + ajustes) — mockup Rafael 2026-07-10

    private var appBar: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(VitaColors.glassBg))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            Text("Flashcards")
                .font(VitaTypography.headlineLarge)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer(minLength: 0)
            appBarButton(icon: "plus") { showCreateMenu = true }
                .vitaBubble(isPresented: $showCreateMenu, arrowEdge: .top) { createMenu }
            appBarButton(icon: "slider.horizontal.3") { showSessionSettings = true }
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.top, VitaTokens.Spacing.sm)
        .padding(.bottom, VitaTokens.Spacing.md)
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

    private func heroCard(vm: FlashcardBuilderViewModel) -> some View {
        let hasDue = vm.state.dueNow > 0
        // "para aprender" honesto: /preview.new (cards realmente novos) quando o
        // preview ja carregou, em vez de total-due (que inflava contando cards em
        // revisao como novos). Rafael 2026-07-12 (#189 hero honesto).
        let newCount = vm.state.previewLoaded ? vm.state.previewNew : vm.state.newNow
        let count = hasDue ? vm.state.dueNow : newCount
        let caption = hasDue ? "para revisar" : "para aprender"
        let est = max(1, Int((Double(count) * 1.6).rounded(.up)))
        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: VitaTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 20, weight: .semibold))  // ds-allow: icone hero
                        .foregroundStyle(VitaColors.accent)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: VitaTokens.Radius.md).fill(VitaColors.glassBg))
                    HStack(alignment: .firstTextBaseline, spacing: VitaTokens.Spacing.sm) {
                        Text("\(count)")
                            .font(.system(size: 46, weight: .bold))  // ds-allow: numero hero
                            .foregroundStyle(VitaColors.accent)
                        Text(caption)
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                    Text("Aproximadamente \(est) min")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer(minLength: 0)
                cardsIllustration
            }
            Button {
                Task {
                    if let id = await vm.createSession() {
                        // Consome a fila FSRS cross-deck do servidor (POST /session)
                        // em vez de abrir um baralho arbitrario. Isso tambem faz a
                        // gaveta valer: o server ja aplica novos/dia, max revisoes e
                        // retencao ao montar a fila. Rafael 2026-07-12 (#189).
                        if !vm.state.lastSessionCardIds.isEmpty {
                            FlashcardMultiDeckHandoff.shared.setQuickSession(
                                cardIds: vm.state.lastSessionCardIds,
                                title: vm.lastSessionTitle
                            )
                        }
                        onOpenDeck(id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))  // ds-allow: icone play
                    Text("Estudar agora").font(VitaTypography.labelMedium)
                }
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VitaTokens.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).fill(VitaColors.accent))
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)

            // Modos alternativos do MESMO ato (estudar) moram aqui no hero —
            // soltos entre stats e busca liam como filtro da lista
            // (Rafael 2026-07-12, review impeccable).
            FlashcardQuickModesRow(vm: vm, onOpenDeck: onOpenDeck)
        }
        .padding(VitaTokens.Spacing._2xl)
        .glassCard(cornerRadius: VitaTokens.Radius.xl)
    }

    // Ilustracao: 3 cards dourados em leque com glow (aproxima o mockup).
    private var cardsIllustration: some View {
        ZStack {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [VitaColors.accentHover, VitaColors.accent, VitaColors.accentDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .stroke(VitaColors.accentLight.opacity(0.5), lineWidth: 0.75)
                    )
                    .rotationEffect(.degrees(Double(i - 1) * 14))
                    .offset(x: CGFloat(i - 1) * 16, y: CGFloat(abs(i - 1)) * 4)
                    .shadow(color: VitaColors.accent.opacity(0.35), radius: 10, y: 4)
            }
        }
        .frame(width: 120, height: 84)
    }

    // MARK: - Card de stats (hoje / dias seguidos / cartoes)

    private func statsCard(vm: FlashcardBuilderViewModel) -> some View {
        HStack(spacing: 0) {
            statCell(value: "\(vm.state.reviewedToday)", label: "hoje")
            statDivider
            statCell(value: "\(vm.state.streakDays)", label: "dias seguidos")
            statDivider
            statCell(value: formatNumber(vm.state.totalCards), label: "cartões")
        }
        .padding(.vertical, VitaTokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(VitaTypography.headlineSmall).foregroundStyle(VitaColors.textPrimary)
            Text(label).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(VitaColors.glassBorder).frame(width: 1, height: 28)
    }

    // MARK: - Lista de baralhos (switcher + linhas com anel)

    private func deckList(vm: FlashcardBuilderViewModel) -> some View {
        let all = vm.state.decks
        let byName: (FlashcardDeckEntry, FlashcardDeckEntry) -> Bool = {
            cleanDeckTitle($0.title).localizedCaseInsensitiveCompare(cleanDeckTitle($1.title)) == .orderedAscending
        }
        let library = all.filter { ($0.userId ?? "").isEmpty }.sorted(by: byName)
        let mine = all.filter { !($0.userId ?? "").isEmpty }.sorted(by: byName)
        let base = deckTab == .biblioteca ? library : mine
        let q = deckSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = q.isEmpty ? base : base.filter { cleanDeckTitle($0.title).lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            deckTabSwitcher(libraryCount: library.count, mineCount: mine.count)
            if vm.state.decksLoading && all.isEmpty {
                groupsSkeleton
            } else if shown.isEmpty {
                deckTabEmpty
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, deck in
                            deckRowV2(deck)
                            if idx < shown.count - 1 {
                                Divider().overlay(VitaColors.glassBorder.opacity(0.5))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }
        }
    }

    private func deckRowV2(_ deck: FlashcardDeckEntry) -> some View {
        let due = deck.dueCount ?? 0
        let total = deck.totalCards ?? deck.cardCount
        let progress = (due > 0 && total > 0) ? min(1.0, Double(due) / Double(total)) : 0
        return Button(action: { onOpenDeck(deck.id) }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                ProgressRingView(
                    progress: progress,
                    size: 30,
                    strokeWidth: 3,
                    trackColor: VitaColors.glassBorder,
                    progressColor: due > 0 ? VitaColors.accent : VitaColors.textTertiary.opacity(0.5)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanDeckTitle(deck.title))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text(deckSubtitle(deck))
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(due > 0 ? VitaColors.accent : VitaColors.textTertiary)
                }
                Spacer(minLength: VitaTokens.Spacing.sm)
                Text("\(deck.cardCount)")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode selector — pills limpas (Pendentes · Filtros · Novos)
    // Clean-up 2026-07-09 (Rafael): antes eram 3 cards grandes com ícone+subtítulo.
    // Agora GlassChip pills discretas. Rótulo curto por modo.

    private func modeLabel(_ m: FlashcardSessionMode) -> String {
        switch m {
        case .due: return "Pendentes"
        case .specific: return "Filtros"
        case .newCards: return "Novos"
        }
    }

    private func modeSelector(vm: FlashcardBuilderViewModel) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            ForEach(FlashcardSessionMode.allCases) { m in
                GlassChip(
                    label: modeLabel(m),
                    isSelected: vm.state.mode == m,
                    action: { withAnimation(.easeInOut(duration: 0.2)) { vm.setMode(m) } }
                )
            }
            Spacer(minLength: 0)
            Button { showSessionSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: icone de ajustes (area de toque)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VitaColors.glassBg))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Origem collapsible (default colapsado §11.2)
    // Usa CollapsibleSectionCard shared (A7 publicou em EstudosBuilderComponents).

    private func originCollapsible(vm: FlashcardBuilderViewModel) -> some View {
        CollapsibleSectionCard(
            title: "Origem",
            icon: "tag",
            summary: vm.state.origin == .all ? "Todas" : vm.state.origin.displayName,
            theme: .flashcards,
            expanded: $originExpanded
        ) {
            originSection(vm: vm)
        }
    }

    // MARK: - Origem (só quando .specific)

    private func originSection(vm: FlashcardBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(FlashcardOrigin.allCases) { o in
                    let isSelected = vm.state.origin == o
                    Button {
                        vm.setOrigin(o)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: o.systemIcon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(o.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(
                            isSelected
                            ? StudyShellTheme.flashcards.primaryLight.opacity(0.98)
                            : VitaColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? StudyShellTheme.flashcards.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    isSelected
                                    ? StudyShellTheme.flashcards.primaryLight.opacity(0.32)
                                    : VitaColors.glassBorder,
                                    lineWidth: 0.75
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Limite

    private func limitSection(vm: FlashcardBuilderViewModel) -> some View {
        StudyOptionSliderCard(
            title: "Limite por sessão",
            selectedId: "\(vm.state.sessionLimit.rawValue)",
            options: FlashcardSessionLimit.allCases.map { limit in
                StudySliderOption(
                    id: "\(limit.rawValue)",
                    title: limit.displayName,
                    subtitle: limit == .unlimited ? "todos os cards" : "cards"
                )
            },
            theme: .flashcards,
            onSelect: { id in
                guard let raw = Int(id), let limit = FlashcardSessionLimit(rawValue: raw) else { return }
                vm.setSessionLimit(limit)
            }
        )
    }

    // MARK: - Decks grid 2-col

    // Clean-up 2026-07-09 (Rafael): 2-col cards → lista seccionada estilo Ajustes.
    // "Sugeridos pelo Vita" (Biblioteca, userId==nil) + "Seus baralhos" (do aluno).
    // Lista de baralhos estilo Anki: switcher Biblioteca (disciplinas canonicas,
    // scope=library) vs Meus baralhos (do aluno). Mostra por ESCOPO, NAO filtrado
    // pelo modo due — senao a Biblioteca (due=0) sumia. Rafael 2026-07-10.
    private func decksSectionWithSwitcher(vm: FlashcardBuilderViewModel) -> some View {
        let all = vm.state.decks
        let byName: (FlashcardDeckEntry, FlashcardDeckEntry) -> Bool = {
            cleanDeckTitle($0.title).localizedCaseInsensitiveCompare(cleanDeckTitle($1.title)) == .orderedAscending
        }
        let library = all.filter { ($0.userId ?? "").isEmpty }.sorted(by: byName)
        let mine = all.filter { !($0.userId ?? "").isEmpty }.sorted(by: byName)
        let base = deckTab == .biblioteca ? library : mine
        let q = deckSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = q.isEmpty ? base : base.filter { cleanDeckTitle($0.title).lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            deckTabSwitcher(libraryCount: library.count, mineCount: mine.count)
            GlassTextField(
                placeholder: deckTab == .biblioteca ? "Buscar disciplina" : "Buscar baralho",
                text: $deckSearch,
                icon: "magnifyingglass"
            )
            if vm.state.decksLoading && all.isEmpty {
                groupsSkeleton
            } else if shown.isEmpty {
                deckTabEmpty
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, deck in
                            deckRow(deck)
                            if idx < shown.count - 1 {
                                Divider()
                                    .overlay(VitaColors.glassBorder.opacity(0.5))
                                    .padding(.leading, VitaTokens.Spacing.lg)
                            }
                        }
                    }
                }
            }
        }
    }

    private func deckTabSwitcher(libraryCount: Int, mineCount: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(DeckTab.allCases) { tab in
                let isSel = deckTab == tab
                let count = tab == .biblioteca ? libraryCount : mineCount
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { deckTab = tab; deckSearch = "" }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.label).font(VitaTypography.labelMedium)
                        Text("\(count)")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(isSel ? VitaColors.surface.opacity(0.75) : VitaColors.textTertiary)
                    }
                    .foregroundStyle(isSel ? VitaColors.surface : VitaColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .fill(isSel ? VitaColors.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous).fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .stroke(VitaColors.glassBorder, lineWidth: 0.75)
        )
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

    /// Porta de entrada do Studio: teu PDF/slide vira baralho. Rafael 2026-07-10.
    private var studioImportRow: some View {
        Button(action: { showStudioImport = true }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 18))  // ds-allow: icone da row (mesmo tamanho do circulo de selecao)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Criar do teu material")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("PDF, slides ou foto viram flashcards")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Spacer(minLength: VitaTokens.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.trailing, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .stroke(VitaColors.glassBorder, lineWidth: 0.75)
        )
    }

    private func deckGroup(title: String, decks: [FlashcardDeckEntry]) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text(title)
                .font(VitaTypography.labelMedium)
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(VitaColors.sectionLabel)
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                VStack(spacing: 0) {
                    ForEach(Array(decks.enumerated()), id: \.element.id) { idx, deck in
                        deckRow(deck)
                        if idx < decks.count - 1 {
                            Divider()
                                .overlay(VitaColors.glassBorder.opacity(0.5))
                                .padding(.leading, VitaTokens.Spacing.lg)
                        }
                    }
                }
            }
        }
    }

    private func deckRow(_ deck: FlashcardDeckEntry) -> some View {
        let isSelected = selectedDeckIds.contains(deck.id)
        return HStack(spacing: 0) {
            // Círculo de seleção (tap marca; tap na linha continua abrindo o deck).
            Button(action: { toggleDeckSelection(deck.id) }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))  // ds-allow: ícone de seleção (área de toque 44pt)
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { onOpenDeck(deck.id) }) {
                HStack(spacing: VitaTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cleanDeckTitle(deck.title))
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                        Text(deckSubtitle(deck))
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle((deck.dueCount ?? 0) > 0 ? VitaColors.accent : VitaColors.textTertiary)
                    }
                    Spacer(minLength: VitaTokens.Spacing.sm)
                    Text("\(deck.cardCount)")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.trailing, VitaTokens.Spacing.lg)
                .padding(.vertical, VitaTokens.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleDeckSelection(_ id: String) {
        if selectedDeckIds.contains(id) { selectedDeckIds.remove(id) } else { selectedDeckIds.insert(id) }
    }

    /// Soma de cards dos baralhos marcados (pro CTA "Estudar selecionados").
    private func selectedCardsCount(vm: FlashcardBuilderViewModel) -> Int {
        vm.visibleDecks().filter { selectedDeckIds.contains($0.id) }.reduce(0) { $0 + $1.cardCount }
    }

    private func deckSubtitle(_ deck: FlashcardDeckEntry) -> String {
        let due = deck.dueCount ?? 0
        if due > 0 { return "\(due) pendentes" }
        let total = deck.totalCards ?? deck.cardCount
        let novos = max(0, total - due)
        return novos > 0 ? "\(novos) novos" : "em dia"
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

    private var emptyDecksCard: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text("Sem baralhos pra esse modo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                Text("Tenta outro modo ou ajusta filtros")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
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

    // MARK: - Helpers

    private func appliedFilterChips(vm: FlashcardBuilderViewModel) -> [FilterChipsRow.Chip] {
        var chips: [FilterChipsRow.Chip] = []
        for slug in vm.state.selectedGroupSlugs {
            let name = vm.state.groups.first(where: { $0.slug == slug })?.name ?? slug
            chips.append(.init(id: "g-\(slug)", label: name, onRemove: { vm.toggleGroup(slug: slug) }))
        }
        if vm.state.origin != .all {
            chips.append(.init(
                id: "o-\(vm.state.origin.rawValue)",
                label: vm.state.origin.displayName,
                onRemove: { vm.setOrigin(.all) }
            ))
        }
        return chips
    }

    private func advancedItems(vm: FlashcardBuilderViewModel) -> [AdvancedToggleItem] {
        [
            AdvancedToggleItem(
                icon: "lightbulb",
                title: "Mostrar dicas",
                description: "Hint na frente do card antes de virar",
                isOn: vm.state.showHints,
                action: { vm.setShowHints(!vm.state.showHints) }
            ),
            AdvancedToggleItem(
                icon: "hare",
                title: "Pular cards muito fáceis",
                description: "Cards com stability alta são adiados",
                isOn: vm.state.skipTooEasy,
                action: { vm.setSkipTooEasy(!vm.state.skipTooEasy) }
            ),
        ]
    }

    private func groupTitle(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Disciplinas"
        case .pbl: return "Sistemas"
        case .greatAreas: return "Áreas"
        }
    }

    /// Label genérico do nível 2 — usado pelo HorizontalDrillDown.
    private func n2Title(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Temas"
        case .pbl: return "Clusters"
        case .greatAreas: return "Subáreas"
        }
    }

    private func ctaTitle(vm: FlashcardBuilderViewModel) -> String {
        let count = vm.state.displayCount
        if count == 0 {
            switch vm.state.mode {
            case .due: return "Sem cards pendentes"
            case .specific: return "Sem cards nesses filtros"
            case .newCards: return "Sem cards novos"
            }
        }
        let limit = vm.state.sessionLimit.rawValue
        let effective = limit == 0 ? count : min(limit, count)
        return "Estudar Agora (\(effective))"
    }

    private func parseId(_ id: String) -> (String, String)? {
        let parts = id.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
