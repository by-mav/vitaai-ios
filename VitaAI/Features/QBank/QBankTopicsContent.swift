import SwiftUI

// MARK: - QBankTopicsContent — árvore real de tópicos da disciplina
//
// Mostrada quando user toca uma disciplina na Home (Questões). Constrói árvore
// client-side a partir de `state.filters.topics` (FLAT) usando `parentTopicId`
// pra montar hierarquia 4 níveis ÁREA → TEMA → SUBTEMA → CONTEÚDO. Filtra
// pelo `disciplineSlug` da matéria escolhida. Tap em qualquer nó (folha ou
// intermediário) inicia sessão Quick Fire imediata com escopo subtree.
//
// Search bar no topo filtra por título (case/accent insensitive).
//
// Shell pattern: AppRouter aplica VitaAmbientBackground (starfield) global —
// esta tela NÃO sobrepõe background opaco. Cards via VitaGlassCard (D4).
//
// Rafael 2026-04-26: "tu tira o negocio de comecar pela disciplina toda,
// ninguem vai usar isso. precisa ser separado em topicos e conteudos e ter
// um menu de busca ali".

struct QBankTopicsContent: View {
    @Bindable var vm: QBankViewModel
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    /// Initial seed (slug + title só) vem de `state.topicsDiscipline`. Quando
    /// `loadFilters` termina, busca a versão LIVE na árvore (com children).
    private var discipline: QBankDiscipline? {
        let seed = vm.state.topicsDiscipline
        guard let slug = seed?.slug else { return seed }
        let live = QBankUiState.flattenDisciplines(vm.state.filters.disciplines)
            .first(where: { $0.slug == slug })
        return live ?? seed
    }

    /// Tópicos da disciplina ativa, plano (filtered de filters.topics).
    private var disciplineTopics: [QBankTopic] {
        guard let slug = discipline?.slug else { return [] }
        return vm.state.filters.topics.filter { $0.disciplineSlug == slug }
    }

    /// Nós raiz da árvore (parentTopicId == nil) com sort + filtro de busca.
    private var rootTopics: [QBankTopic] {
        let roots = disciplineTopics.filter { $0.parentTopicId == nil }
        let sorted = sortNodes(roots)
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { matchesSearchInSubtree($0) }
    }

    /// Ordenação aplicada em qualquer lista de nodes (root + children).
    /// Fonte do "count" considera AGREGADO da subtree (não só direct).
    private func sortNodes(_ nodes: [QBankTopic]) -> [QBankTopic] {
        switch vm.state.topicsSortOrder {
        case .byQuestions:
            return nodes.sorted {
                QBankTopicNodeView.aggregateCount($0, in: disciplineTopics) >
                    QBankTopicNodeView.aggregateCount($1, in: disciplineTopics)
            }
        case .alphabetical:
            return nodes.sorted {
                $0.displayTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) <
                    $1.displayTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            }
        }
    }

    private func matchesSearchInSubtree(_ node: QBankTopic) -> Bool {
        if titleMatches(node) { return true }
        let children = disciplineTopics.filter { $0.parentTopicId == node.id }
        return children.contains(where: matchesSearchInSubtree)
    }

    private func titleMatches(_ node: QBankTopic) -> Bool {
        let needle = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let hay = node.displayTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return hay.contains(needle)
    }

    /// Estatísticas agregadas pela disciplina (state.progress.byTopic ∩ tópicos da disciplina).
    private var disciplineStats: (answered: Int, correct: Int, total: Int)? {
        guard !disciplineTopics.isEmpty else { return nil }
        let topicIds = Set(disciplineTopics.map(\.id))
        let entries = vm.state.progress.byTopic.filter { topicIds.contains($0.topicId) }
        guard !entries.isEmpty else { return nil }
        let answered = entries.reduce(0) { $0 + $1.answered }
        let correct = entries.reduce(0) { $0 + $1.correct }
        return (answered, correct, discipline?.questionCount ?? 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard
                searchBar
                contentSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            // Sem clearance: passa por trás da TabBar Liquid Glass.
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            backButton
        }
    }

    // MARK: - Back button (canto superior esquerdo, glass D4)

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle().stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                )
        }
        .padding(.top, 6)
        .padding(.leading, 16)
    }

    // MARK: - Hero (D4 glass card com info da disciplina)

    private var heroCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QUICK FIRE")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(VitaColors.accent)
                        Text(discipline?.title ?? "Questões")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    if let count = discipline?.questionCount, count > 0 {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(count)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(VitaColors.accentHover)
                                .monospacedDigit()
                            Text("questões")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                }

                if let stats = disciplineStats, stats.answered > 0 {
                    let accuracy = Int(Double(stats.correct) / Double(stats.answered) * 100)
                    HStack(spacing: 10) {
                        statPill(
                            icon: "checkmark.circle.fill",
                            label: "Respondidas",
                            value: "\(stats.answered)/\(stats.total)",
                            tint: VitaColors.accent
                        )
                        statPill(
                            icon: "target",
                            label: "Acerto",
                            value: "\(accuracy)%",
                            tint: accuracy >= 70 ? VitaColors.dataGreen : VitaColors.dataAmber
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    private func statPill(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VitaColors.textSecondary)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Buscar tópico ou conteúdo")
                    .foregroundStyle(VitaColors.textTertiary)
            )
            .focused($searchFocused)
            .font(.system(size: 14))
            .foregroundStyle(VitaColors.textPrimary)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    searchFocused ? VitaColors.accent.opacity(0.40) : VitaColors.accent.opacity(0.12),
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.18), value: searchFocused)
        )
    }

    // MARK: - Content section

    @ViewBuilder
    private var contentSection: some View {
        if vm.state.filtersLoading && disciplineTopics.isEmpty {
            loadingState
        } else if rootTopics.isEmpty {
            if !searchText.isEmpty {
                searchEmptyState
            } else {
                emptyState
            }
        } else {
            topicsTreeSection
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            VitaHeartbeatLoader(orbSize: 64)
            Text("Carregando tópicos…")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VitaEmptyState(
            title: "Sem tópicos catalogados",
            message: "A árvore de tópicos pra essa disciplina ainda não foi mapeada no banco. Se há questões disponíveis, tópicos virão na próxima atualização do catálogo."
        ) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.top, 12)
    }

    private var searchEmptyState: some View {
        VitaEmptyState(
            title: "Nada encontrado",
            message: "Nenhum tópico bate com \"\(searchText)\". Tenta outro termo ou limpa a busca."
        ) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.top, 12)
    }

    private var topicsTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(searchText.isEmpty ? "Por tópico" : "Resultados")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(VitaColors.textSecondary)
                Spacer()
                sortChips
            }
            .padding(.leading, 4)
            .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(rootTopics) { node in
                    QBankTopicNodeView(
                        vm: vm,
                        node: node,
                        depth: 0,
                        disciplineSlug: discipline?.slug,
                        allTopics: disciplineTopics,
                        searchText: searchText,
                        sortOrder: vm.state.topicsSortOrder
                    )
                }
            }
        }
    }

    /// Sort chips — toggle "Mais questões" ↔ "A → Z". Fica à direita do
    /// header da seção. Tap aplica ordenação em todos os níveis da árvore.
    private var sortChips: some View {
        HStack(spacing: 6) {
            ForEach(QBankTopicsSortOrder.allCases, id: \.self) { order in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.state.topicsSortOrder = order
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: order == .byQuestions ? "number" : "textformat")
                            .font(.system(size: 9, weight: .semibold))
                        Text(order.displayName)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(
                        vm.state.topicsSortOrder == order
                            ? VitaColors.accent
                            : VitaColors.textSecondary
                    )
                    .background(
                        Capsule().fill(
                            vm.state.topicsSortOrder == order
                                ? VitaColors.accent.opacity(0.14)
                                : Color.clear
                        )
                    )
                    .overlay(
                        Capsule().stroke(
                            vm.state.topicsSortOrder == order
                                ? VitaColors.accent.opacity(0.30)
                                : VitaColors.glassBorder.opacity(0.30),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - QBankTopicNodeView (recursive — separado pra evitar opaque-recursion)

private struct QBankTopicNodeView: View {
    @Bindable var vm: QBankViewModel
    let node: QBankTopic
    let depth: Int
    let disciplineSlug: String?
    let allTopics: [QBankTopic]
    let searchText: String
    let sortOrder: QBankTopicsSortOrder

    private var children: [QBankTopic] {
        let raw = allTopics.filter { $0.parentTopicId == node.id }
        switch sortOrder {
        case .byQuestions:
            return raw.sorted {
                QBankTopicNodeView.aggregateCount($0, in: allTopics) >
                    QBankTopicNodeView.aggregateCount($1, in: allTopics)
            }
        case .alphabetical:
            return raw.sorted {
                $0.displayTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) <
                    $1.displayTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            }
        }
    }

    var body: some View {
        // Auto-expandir quando há busca ativa (UX de tree-search).
        let isExpanded = vm.state.topicsExpandedNodeIds.contains(node.id) || !searchText.isEmpty
        let hasChildren = !children.isEmpty

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if hasChildren {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.toggleTopicNodeExpansion(node.id)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.18), value: isExpanded)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let topicIds = Self.collectTopicIds(node, in: allTopics)
                    vm.startQuickFire(
                        disciplineSlug: disciplineSlug,
                        topicIds: topicIds
                    )
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.displayTitle)
                                .font(.system(size: depth == 0 ? 14 : 13, weight: depth == 0 ? .semibold : .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text(Self.levelLabel(depth))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(VitaColors.accent)
                                let aggregateCount = Self.aggregateCount(node, in: allTopics)
                                if aggregateCount > 0 {
                                    Text("·")
                                        .font(.system(size: 10))
                                        .foregroundStyle(VitaColors.textTertiary)
                                    Text("\(aggregateCount) \(aggregateCount == 1 ? "questão" : "questões")")
                                        .font(.system(size: 10))
                                        .foregroundStyle(VitaColors.textSecondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "play.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(VitaColors.accent.opacity(0.65))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(depth) * 14)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background {
                if depth == 0 {
                    Color.clear.glassCard(cornerRadius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.glassBg.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accent.opacity(0.10), lineWidth: 0.5)
                        )
                }
            }

            if isExpanded && hasChildren {
                VStack(spacing: 6) {
                    ForEach(children) { child in
                        QBankTopicNodeView(
                            vm: vm,
                            node: child,
                            depth: depth + 1,
                            disciplineSlug: disciplineSlug,
                            allTopics: allTopics,
                            searchText: searchText,
                            sortOrder: sortOrder
                        )
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 8)
            }
        }
    }

    static func collectTopicIds(_ node: QBankTopic, in all: [QBankTopic]) -> Set<Int> {
        var ids: Set<Int> = [node.id]
        let directChildren = all.filter { $0.parentTopicId == node.id }
        for child in directChildren {
            ids.formUnion(collectTopicIds(child, in: all))
        }
        return ids
    }

    /// Soma `count` direto deste nó + recursivo de toda a subtree.
    /// Mostra "247 questões" no root mesmo que ele tenha 0 questões diretas
    /// (todas estão nas folhas) — número real do que o tap inicia.
    static func aggregateCount(_ node: QBankTopic, in all: [QBankTopic]) -> Int {
        var total = node.count ?? 0
        let directChildren = all.filter { $0.parentTopicId == node.id }
        for child in directChildren {
            total += aggregateCount(child, in: all)
        }
        return total
    }

    /// Label semântico por nível (0=TEMA, 1=SUBTEMA, 2=CONTEÚDO, 3=detalhe).
    /// A disciplina já é o nível 1 do canon (ÁREA-DISCIPLINA-TEMA-CONTEÚDO);
    /// dentro da tela de Topics, profundidade 0 = TEMA.
    static func levelLabel(_ depth: Int) -> String {
        switch depth {
        case 0: return "TEMA"
        case 1: return "SUBTEMA"
        case 2: return "CONTEÚDO"
        default: return "DETALHE"
        }
    }
}
