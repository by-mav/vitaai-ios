import SwiftUI

// MARK: - CardBrowserScreen — navegador/gerenciador de cards de um baralho
//
// Estilo Anki, visual Vita (Gold Glassmorphism): lista os cards de UM baralho
// mostrando FRENTE + preview do VERSO, com busca, chips de filtro, multi-
// seleção (excluir/suspender em lote), criar card novo, editar e reordenar.
//
// Shell: página empurrada full-bleed → cabeçalho PRÓPRIO com botão voltar
// (VitaScreenHeader), fundo VitaAmbientBackground. Sub-telas (compositor de
// card) = .sheet com fundo material.
//
// Fiação (entry-point) — ver comentário no fim do arquivo.

struct CardBrowserScreen: View {
    let deckId: String
    let deckTitle: String
    /// subjectId do deck (quando existe) — estreita o getFlashcardDecks.
    var subjectId: String? = nil
    /// Disciplina da Biblioteca (offline): quando presente, o browser lê os cards
    /// do bundle (VitaContentBundle), não do servidor. Read-only. Rafael 2026-07-17.
    var disciplineSlug: String? = nil
    var onBack: (() -> Void)? = nil

    /// Injeção só de #Preview: pula a rede e semeia cards fake.
    var previewCards: [FlashcardEntry]? = nil

    @Environment(\.appContainer) private var container
    @State private var vm = CardBrowserViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var composerTarget: CardComposerTarget?
    @State private var pendingDelete: FlashcardEntry?
    @State private var moveDestinations: [VitaContentBundle.Discipline]?

    var body: some View {
        VitaAmbientBackground {
            VStack(spacing: 0) {
                headerArea
                    .padding(.bottom, VitaTokens.Spacing.sm)

                if !vm.isSelecting && editMode != .active {
                    controlsArea
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                        .padding(.bottom, VitaTokens.Spacing.sm)
                }

                content
            }
            .overlay(alignment: .bottom) {
                if vm.isSelecting {
                    CardBrowserSelectionBar(
                        selectedCount: vm.selectedCount,
                        allSelected: vm.allVisibleSelected,
                        isBundle: disciplineSlug?.isEmpty == false,
                        onDelete: { Task { await vm.deleteSelected() } },
                        onToggleSelectAll: {
                            if vm.allVisibleSelected { vm.clearSelection() } else { vm.selectAllVisible() }
                        },
                        onEdit: {
                            if let id = vm.selection.first, let card = vm.cards.first(where: { $0.id == id }) {
                                composerTarget = .edit(card)
                            }
                        },
                        onInvert: { withAnimation { vm.invertSelection() } },
                        onDuplicate: { Task { await vm.duplicateSelected() } },
                        onMove: { Task { await presentMoveSheet() } },
                        onSuspend: { Task { await vm.suspendSelected() } }
                    )
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                    .padding(.bottom, VitaTokens.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            #if DEBUG
            if let previewCards {
                vm.seedForPreview(cards: previewCards, deckTitle: deckTitle)
                return
            }
            #endif
            vm.bind(api: container.api)
            vm.configure(deckId: deckId, deckTitle: deckTitle, subjectId: subjectId, disciplineSlug: disciplineSlug)
            await vm.loadIfNeeded()
        }
        .sheet(item: $composerTarget) { target in
            CardComposerSheet(target: target, deckTitle: vm.deckTitle) { front, back in
                switch target {
                case .create:
                    return await vm.createCard(front: front, back: back)
                case .edit(let card):
                    return await vm.updateCard(id: card.id, front: front, back: back)
                }
            }
        }
        .sheet(item: Binding(
            get: { moveDestinations.map { MoveSheetPayload(destinations: $0) } },
            set: { if $0 == nil { moveDestinations = nil } }
        )) { payload in
            MoveToDeckSheet(
                count: vm.selectedCount,
                destinations: payload.destinations,
                onPick: { slug in
                    moveDestinations = nil
                    Task { await vm.moveSelected(to: slug) }
                },
                onCancel: { moveDestinations = nil }
            )
        }
        .alert("Excluir card?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
            Button("Excluir", role: .destructive) {
                if let card = pendingDelete { Task { await vm.delete(id: card.id) } }
                pendingDelete = nil
            }
        } message: {
            Text("Esta ação remove o card do baralho.")
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isSelecting)
        .trackScreen("CardBrowser", extra: ["deck_id": deckId])
    }

    // MARK: Cabeçalho (3 estados: seleção / reordenar / normal)

    @ViewBuilder
    private var headerArea: some View {
        if vm.isSelecting {
            selectionHeader
        } else if editMode == .active {
            VitaScreenHeader(title: vm.deckTitle, subtitle: reorderSubtitle, onBack: dismiss) {
                Button {
                    withAnimation { editMode = .inactive }
                } label: {
                    Text("Concluir")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.accent)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
            }
        } else {
            VitaScreenHeader(title: vm.deckTitle, subtitle: countSubtitle, onBack: dismiss) {
                if !vm.isReadOnly {
                    HStack(spacing: VitaTokens.Spacing.xs) {
                        overflowMenu
                        circleButton(system: "plus") { composerTarget = .create }
                            .accessibilityLabel("Novo card")
                    }
                }
            }
        }
    }

    private var selectionHeader: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button { withAnimation { vm.cancelSelection() } } label: {
                Text("Cancelar")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(minWidth: 80, minHeight: 40, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text("\(vm.selectedCount) selecionados")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer(minLength: 0)

            // Balanceia o "Cancelar" à esquerda.
            Color.clear.frame(width: 80, height: 40)
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.top, VitaTokens.Spacing.sm)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                withAnimation { vm.enterSelection() }
            } label: { Label("Selecionar", systemImage: "checkmark.circle") }

            Button {
                guard vm.canReorder else { return }
                withAnimation { editMode = .active }
            } label: { Label("Reordenar", systemImage: "arrow.up.arrow.down") }
                .disabled(!vm.canReorder)
        } label: {
            circleIconLabel(system: "ellipsis")
        }
        .accessibilityLabel("Mais ações")
    }

    // MARK: Busca + chips

    private var controlsArea: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            GlassTextField(placeholder: "Buscar card…", text: $vm.searchText, icon: "magnifyingglass")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    ForEach(CardBrowserViewModel.Filter.allCases) { f in
                        GlassChip(label: f.label, isSelected: vm.filter == f) {
                            withAnimation(.easeInOut(duration: 0.15)) { vm.filter = f }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: Conteúdo (lista / vazio / carregando)

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            Spacer()
            ProgressView()
                .tint(VitaColors.accent)
            Spacer()
        } else if vm.loadFailed {
            Spacer()
            VitaEmptyState(
                title: "Não foi possível carregar",
                message: "Verifique sua conexão e tente de novo.",
                actionText: "Tentar de novo",
                onAction: { Task { await vm.refresh() } }
            )
            Spacer()
        } else if vm.filteredCards.isEmpty {
            Spacer()
            VitaEmptyState(
                title: vm.cards.isEmpty ? "Nenhum card ainda" : "Nada encontrado",
                message: vm.cards.isEmpty
                    ? (vm.isReadOnly
                        ? "Este baralho da Biblioteca ainda não tem cards."
                        : "Toque em + para criar o primeiro card deste baralho.")
                    : "Nenhum card corresponde à busca ou ao filtro.",
                actionText: (vm.cards.isEmpty && !vm.isReadOnly) ? "Criar card" : nil,
                onAction: (vm.cards.isEmpty && !vm.isReadOnly) ? { composerTarget = .create } : nil
            )
            Spacer()
        } else {
            cardList
        }
    }

    private var cardList: some View {
        List {
            ForEach(vm.filteredCards) { card in
                CardBrowserRow(
                    card: card,
                    isSelecting: vm.isSelecting,
                    isSelected: vm.selection.contains(card.id),
                    onTap: { onRowTap(card) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: VitaTokens.Spacing.lg, bottom: 4, trailing: VitaTokens.Spacing.lg))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !vm.isReadOnly {
                        Button(role: .destructive) { pendingDelete = card } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    if !vm.isReadOnly {
                        Button { composerTarget = .edit(card) } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(VitaColors.accent)
                    }
                }
                .contentShape(Rectangle())
                .onLongPressGesture {
                    if !vm.isReadOnly && !vm.isSelecting {
                        withAnimation { vm.enterSelection(preselect: card.id) }
                    }
                }
            }
            .onMove { source, dest in vm.moveCards(from: source, to: dest) }

            // Respiro pra barra de seleção flutuante não cobrir o último card.
            Color.clear
                .frame(height: vm.isSelecting ? 92 : 24)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    // MARK: Ações de linha

    private func onRowTap(_ card: FlashcardEntry) {
        guard editMode != .active else { return }
        // Rafael 2026-07-18: no gerenciador, TOCAR seleciona (estilo Anki browser).
        // O 1º toque entra em seleção já marcando o card; toques seguintes alternam.
        // Editar 1 card = swipe pra direita (Editar) OU o botão Editar da barra
        // quando só 1 está selecionado.
        if vm.isSelecting {
            vm.toggle(card.id)
        } else if !vm.isReadOnly {
            withAnimation { vm.enterSelection(preselect: card.id) }
        } else {
            composerTarget = .edit(card)  // deck read-only (não deveria ocorrer)
        }
    }

    /// Carrega os destinos (disciplinas ou baralhos do aluno) e abre o sheet.
    private func presentMoveSheet() async {
        let dests = await vm.availableDestinations()
        guard !dests.isEmpty else {
            vm.errorMessage = "Você não tem outro baralho para mover os cards."
            return
        }
        moveDestinations = dests
    }

    private func dismiss() {
        if let onBack { onBack() }
    }

    private var countSubtitle: String {
        let n = vm.cards.count
        return "\(n) \(n == 1 ? "card" : "cards")"
    }

    private var reorderSubtitle: String { "Arraste para reordenar" }

    // MARK: Botões circulares (chrome de vidro)

    private func circleButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleIconLabel(system: system) }
            .buttonStyle(.plain)
    }

    private func circleIconLabel(system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 16, weight: .semibold))  // ds-allow: tamanho óptico do SF Symbol
            .foregroundStyle(VitaColors.textSecondary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(VitaColors.glassBg))
            .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - CardBrowserRow — 1 card: checkbox + frente + preview do verso + status

struct CardBrowserRow: View {
    let card: FlashcardEntry
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: VitaTokens.Spacing.md) {
                if isSelecting {
                    checkbox
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                    Text(plain(card.front))
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(plain(card.back))
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: VitaTokens.Spacing.sm)

                if let pill = statusPill {
                    CardStatusPill(text: pill.text, tint: pill.tint)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .fill(VitaColors.surfaceCard.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .stroke(isSelected ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var checkbox: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? VitaColors.accent : VitaColors.textTertiary, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle().fill(VitaColors.accent).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))  // ds-allow: tamanho óptico do SF Symbol
                    .foregroundStyle(VitaColors.surface)
            }
        }
    }

    private var statusPill: (text: String, tint: Color)? {
        switch card.browserStatus {
        case .new:       return ("Novo", VitaColors.accentLight)
        case .today:     return ("Hoje", VitaColors.warning)
        case .due:       return ("Pendente", VitaColors.danger)
        case .scheduled: return nil
        }
    }

    /// Remove marcação leve (HTML/markdown) do preview de lista.
    private func plain(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[*_#`>]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - CardStatusPill

struct CardStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(VitaTypography.labelSmall)
            .kerning(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, VitaTokens.Spacing.sm)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - CardBrowserSelectionBar — barra inferior (Excluir / Selecionar tudo / ⋯)

struct CardBrowserSelectionBar: View {
    let selectedCount: Int
    let allSelected: Bool
    /// Biblioteca (edição local) → habilita Copiar / Mover para outro baralho.
    /// Baralho do servidor → mostra Suspender no lugar.
    let isBundle: Bool
    let onDelete: () -> Void
    let onToggleSelectAll: () -> Void
    let onEdit: () -> Void
    let onInvert: () -> Void
    let onDuplicate: () -> Void
    let onMove: () -> Void
    let onSuspend: () -> Void

    var body: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            action(label: "Deletar", system: "trash", tint: VitaColors.danger, enabled: selectedCount > 0, action: onDelete)

            action(
                label: allSelected ? "Limpar" : "Selecionar tudo",
                system: allSelected ? "circle" : "checkmark.circle",
                tint: VitaColors.accent,
                enabled: true,
                action: onToggleSelectAll
            )

            Menu {
                Button { onEdit() } label: { Label("Editar card", systemImage: "pencil") }
                    .disabled(selectedCount != 1)

                Button { onInvert() } label: { Label("Inverter seleção", systemImage: "arrow.triangle.2.circlepath") }

                if isBundle {
                    Button { onDuplicate() } label: { Label("Copiar", systemImage: "doc.on.doc") }
                        .disabled(selectedCount == 0)
                } else {
                    Button { onSuspend() } label: { Label("Suspender", systemImage: "pause.circle") }
                        .disabled(selectedCount == 0)
                }
                // Mover vale pros dois mundos: Biblioteca → outra disciplina
                // (overlay local); baralho do aluno → outro baralho dele
                // (PATCH deckId). Destinos vêm de availableDestinations().
                Button { onMove() } label: { Label("Mover para outro baralho", systemImage: "tray.and.arrow.up") }
                    .disabled(selectedCount == 0)
            } label: {
                pill(label: "Mais", system: "ellipsis", tint: VitaColors.textSecondary, enabled: true)
            }
        }
        .padding(VitaTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl)
                .fill(VitaColors.glassBg)
                .shadow(color: VitaColors.black.opacity(0.35), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    private func action(label: String, system: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            pill(label: label, system: system, tint: tint, enabled: enabled)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func pill(label: String, system: String, tint: Color, enabled: Bool) -> some View {
        VStack(spacing: VitaTokens.Spacing.xxs) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))  // ds-allow: tamanho óptico do SF Symbol
            Text(label)
                .font(VitaTypography.labelSmall)
                .lineLimit(1)
        }
        .foregroundStyle(enabled ? tint : tint.opacity(0.35))
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - MoveToDeckSheet — escolher o baralho de destino

/// Wrapper Identifiable pra dirigir o `.sheet(item:)` (o array de destinos não é
/// Identifiable sozinho).
private struct MoveSheetPayload: Identifiable {
    let id = UUID()
    let destinations: [VitaContentBundle.Discipline]
}

struct MoveToDeckSheet: View {
    let count: Int
    let destinations: [VitaContentBundle.Discipline]
    var onPick: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surfaceElevated.ignoresSafeArea()
                if destinations.isEmpty {
                    VitaEmptyState(
                        title: "Sem outros baralhos",
                        message: "Não há outra disciplina na Biblioteca para receber os cards."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: VitaTokens.Spacing.sm) {
                            ForEach(destinations) { d in
                                Button { onPick(d.slug) } label: { row(d) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(VitaTokens.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Mover \(count) \(count == 1 ? "card" : "cards")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    private func row(_ d: VitaContentBundle.Discipline) -> some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: "tray.full")
                .font(.system(size: 16, weight: .semibold))  // ds-allow: tamanho óptico do SF Symbol
                .foregroundStyle(VitaColors.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(VitaColors.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(d.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                Text("\(d.count) \(d.count == 1 ? "card" : "cards")")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))  // ds-allow: tamanho óptico do SF Symbol
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(VitaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .fill(VitaColors.surfaceCard.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Fiação (entry-point) — arquivos NOVOS, sem tocar os existentes
//
// Pra plugar esta tela na navegação do app (fazer em arquivos existentes,
// numa PR separada — aqui só documentado):
//
// 1) VitaAI/Navigation/Route.swift — adicionar o case:
//      case cardBrowser(deckId: String, deckTitle: String, subjectId: String? = nil)
//
// 2) VitaAI/Navigation/AppRouter.swift — no switch de destino (perto de
//    `case .flashcardTopics`, ~linha 760), adicionar:
//      case .cardBrowser(let deckId, let deckTitle, let subjectId):
//          CardBrowserScreen(
//              deckId: deckId,
//              deckTitle: deckTitle,
//              subjectId: subjectId,
//              onBack: { router.goBack() }
//          )
//
// 3) VitaAI/Navigation/Route+Breadcrumb.swift — adicionar:
//      case .cardBrowser(_, let title, _): return title
//
// 4) Chamar de onde faz sentido (ex.: FlashcardTopicsScreen, long-press num
//    deck na lista, ou botão "Gerenciar cards"):
//      router.navigate(to: .cardBrowser(
//          deckId: deck.id, deckTitle: deck.title, subjectId: deck.subjectId))

#if DEBUG
#Preview("CardBrowserScreen") {
    let cards: [FlashcardEntry] = [
        { var c = FlashcardEntry(); c.id = "1"; c.front = "Qual a tríade de Beck no tamponamento cardíaco?"; c.back = "Hipotensão, turgência jugular e abafamento de bulhas."; c.state = "NEW"; c.reps = 0; return c }(),
        { var c = FlashcardEntry(); c.id = "2"; c.front = "Mecanismo de ação da amiodarona"; c.back = "Bloqueio de canais de K+ (classe III), prolonga a repolarização."; c.state = "REVIEW"; c.reps = 4; c.nextReviewAt = "2020-01-01T00:00:00Z"; return c }(),
        { var c = FlashcardEntry(); c.id = "3"; c.front = "Sinal de Kussmaul"; c.back = "Aumento paradoxal da PVJ na inspiração."; c.state = "REVIEW"; c.reps = 2; c.scheduledDays = 6; return c }()
    ]
    return NavigationStack {
        CardBrowserScreen(
            deckId: "deck-1",
            deckTitle: "Cardiologia",
            onBack: {},
            previewCards: cards
        )
    }
    .environment(Router())
}
#endif
