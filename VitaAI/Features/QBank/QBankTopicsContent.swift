import SwiftUI

// MARK: - QBankTopicsContent — Quick Fire árvore de tópicos
//
// Mostrada quando user toca uma disciplina na Home (Questões). Lista os 4
// níveis canônicos (ÁREA → DISCIPLINA → TEMA → CONTEÚDO) via `QBankDiscipline`
// recursivo (`children`). Tap em qualquer nó (folha ou intermediário) inicia
// uma sessão Quick Fire imediata com escopo subtree.
//
// Rafael 2026-04-26: "questoes eh pra fazer questoes direto, em ordem
// rapida, apenas fazer e pronto". Sem config, sem multi-select.

struct QBankTopicsContent: View {
    @Bindable var vm: QBankViewModel
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

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if vm.state.filtersLoading && discipline?.children.isEmpty == true {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            allDisciplineButton
                            if let discipline {
                                if discipline.children.isEmpty {
                                    emptyState
                                } else {
                                    ForEach(discipline.children) { node in
                                        QBankTopicNodeView(
                                            vm: vm,
                                            node: node,
                                            depth: 0,
                                            disciplineSlug: discipline.slug
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(VitaColors.glassBg)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("QUICK FIRE")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))
                Text(discipline?.title ?? "Questões")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            if let discipline, discipline.questionCount > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(discipline.questionCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VitaColors.accent)
                        .monospacedDigit()
                    Text("questões")
                        .font(.system(size: 9))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Botão "Todas as questões da disciplina"

    private var allDisciplineButton: some View {
        Button {
            guard let slug = discipline?.slug else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.startQuickFire(disciplineSlug: slug)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(VitaColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Começar pela disciplina toda")
                        .font(.system(size: 14, weight: .semibold))
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
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.accent.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Nenhum tópico catalogado pra esta disciplina ainda.")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Usa o botão acima pra começar com toda a matéria.")
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
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
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 24, height: 24)
                }

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
                            .foregroundStyle(VitaColors.accent.opacity(0.75))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(depth) * 14)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(VitaColors.glassBg.opacity(depth == 0 ? 0.8 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VitaColors.glassBorder.opacity(0.4), lineWidth: 0.5)
            )

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

    static func levelLabel(_ depth: Int) -> String {
        switch depth {
        case 0: return "Área"
        case 1: return "Tema"
        case 2: return "Conteúdo"
        default: return "Subtópico"
        }
    }
}
