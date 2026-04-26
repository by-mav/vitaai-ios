import SwiftUI

// MARK: - QBankTopicsContent — Quick Fire árvore de tópicos
//
// Mostrada quando user toca uma disciplina na Home (Questões). Lista os 4
// níveis canônicos (ÁREA → DISCIPLINA → TEMA → CONTEÚDO) via `QBankDiscipline`
// recursivo (`children`). Tap em qualquer nó (folha ou intermediário) inicia
// uma sessão Quick Fire imediata com escopo subtree.
//
// Shell pattern: AppRouter aplica VitaAmbientBackground (starfield) global —
// esta tela NÃO sobrepõe background opaco. Cards via VitaGlassCard (D4).
// Loading via VitaHeartbeatLoader. Empty via VitaEmptyState.
//
// Rafael 2026-04-26: "questoes eh pra fazer questoes direto, em ordem
// rapida, apenas fazer e pronto".

struct QBankTopicsContent: View {
    @Bindable var vm: QBankViewModel
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    /// Initial seed (slug + title só) vem de `state.topicsDiscipline`. Quando
    /// `loadFilters` termina, busca a versão LIVE na árvore (com children).
    private var discipline: QBankDiscipline? {
        let seed = vm.state.topicsDiscipline
        guard let slug = seed?.slug else { return seed }
        let live = QBankUiState.flattenDisciplines(vm.state.filters.disciplines)
            .first(where: { $0.slug == slug })
        return live ?? seed
    }

    /// Estatísticas agregadas por disciplina vindas de `state.progress.byTopic`.
    /// Soma respondidas + corretas dos tópicos cuja subtree pertence ao
    /// `topicsExpandedNodeIds + discipline.children` (todos os IDs do subtree).
    private var disciplineStats: (answered: Int, correct: Int, total: Int)? {
        guard let disc = discipline, !disc.children.isEmpty else { return nil }
        let allTopicIds = QBankTopicNodeView.collectAllIds(disc.children)
        let entries = vm.state.progress.byTopic.filter { allTopicIds.contains($0.topicId) }
        guard !entries.isEmpty else { return nil }
        let answered = entries.reduce(0) { $0 + $1.answered }
        let correct = entries.reduce(0) { $0 + $1.correct }
        return (answered, correct, disc.questionCount)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard
                quickStartCard
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

    // MARK: - Quick Start CTA

    private var quickStartCard: some View {
        Button {
            guard let slug = discipline?.slug else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.startQuickFire(disciplineSlug: slug)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(VitaColors.accentHover)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Começar pela disciplina toda")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("10 questões aleatórias de toda a matéria")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VitaColors.accent.opacity(0.36), lineWidth: 1)
        )
    }

    // MARK: - Content section (loading / empty / topics tree)

    @ViewBuilder
    private var contentSection: some View {
        if vm.state.filtersLoading && (discipline?.children.isEmpty ?? true) {
            loadingState
        } else if let disc = discipline, !disc.children.isEmpty {
            topicsTreeSection(disc)
        } else {
            emptyState
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
            message: "A árvore de tópicos pra essa disciplina ainda não foi mapeada. Usa o atalho acima pra começar com a disciplina toda."
        ) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.top, 12)
    }

    private func topicsTreeSection(_ disc: QBankDiscipline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Por tópico")
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.leading, 4)
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(disc.children) { node in
                    QBankTopicNodeView(
                        vm: vm,
                        node: node,
                        depth: 0,
                        disciplineSlug: disc.slug
                    )
                }
            }
        }
    }
}

// MARK: - QBankTopicNodeView (recursive — separado pra evitar opaque-recursion)

private struct QBankTopicNodeView: View {
    @Bindable var vm: QBankViewModel
    let node: QBankDiscipline
    let depth: Int
    let disciplineSlug: String?

    var body: some View {
        let isExpanded = vm.state.topicsExpandedNodeIds.contains(node.id)
        let hasChildren = !node.children.isEmpty

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Disclosure (chevron rotaciona)
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

                // Tap no título → quick fire subtree
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let topicIds = Self.collectTopicIds(node)
                    vm.startQuickFire(
                        disciplineSlug: disciplineSlug,
                        topicIds: topicIds
                    )
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title)
                                .font(.system(size: depth == 0 ? 14 : 13, weight: depth == 0 ? .semibold : .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Text(Self.levelLabel(depth) + (node.questionCount > 0 ? " · \(node.questionCount) questões" : ""))
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
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
                // Top-level usa glassCard D4 completo; subtópicos usam fill
                // mais sutil pra não competir visualmente.
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
                    ForEach(node.children) { child in
                        QBankTopicNodeView(
                            vm: vm,
                            node: child,
                            depth: depth + 1,
                            disciplineSlug: disciplineSlug
                        )
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 8)
            }
        }
    }

    static func collectTopicIds(_ node: QBankDiscipline) -> Set<Int> {
        var ids: Set<Int> = [node.id]
        for child in node.children {
            ids.formUnion(collectTopicIds(child))
        }
        return ids
    }

    /// Coleta TODOS os IDs de uma lista de nodes (todos os descendentes).
    /// Usado pelo Hero stats da disciplina.
    static func collectAllIds(_ nodes: [QBankDiscipline]) -> Set<Int> {
        var ids: Set<Int> = []
        for node in nodes {
            ids.formUnion(collectTopicIds(node))
        }
        return ids
    }

    static func levelLabel(_ depth: Int) -> String {
        switch depth {
        case 0: return "Tema"
        case 1: return "Subtema"
        case 2: return "Conteúdo"
        default: return "Subtópico"
        }
    }
}

