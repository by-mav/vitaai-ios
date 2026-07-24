import SwiftUI
import Sentry

// MARK: - QBankBuilderScreen — Fase 3 reescrita gold-standard
//
// Tela única que substitui QBankHomeContent + QBankConfigContent.
// Composição vertical com builder visível inline, lente operacional,
// count dinâmico e CTA sticky. SOT do layout:
// agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.1

struct QBankBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: QBankBuilderViewModel?
    let onBack: () -> Void
    let onSessionCreated: (String, QBankMode) -> Void

    // Configuração avançada fica fora do fluxo principal para reduzir carga visual.
    @State private var activeSheet: QBankBuilderSheet? = nil
    @State private var yearsExpanded: Bool = false
    @State private var formatExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    @State private var showStudioImport = false

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if vm == nil {
                vm = QBankBuilderViewModel(api: container.api, dataManager: container.dataManager)
                vm?.boot()
                SentrySDK.reportFullyDisplayed()
            }
        }
        .navigationBarHidden(true)
        .trackScreen("QBankBuilder")
    }

    @ViewBuilder
    private func content(vm: QBankBuilderViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                    QBankBuilderHeader(
                        onBack: onBack,
                        onCreate: { showStudioImport = true },
                        onHistory: { activeSheet = .recents },
                        onFavorites: { activeSheet = .favorites }
                    )

                    // 1. Hero
                    StudyImageHeroStat(
                        imageAsset: "hero-questoes-v2",
                        eyebrow: "Treino clínico",
                        primary: formatNumber(heroAvailableCount(vm: vm)),
                        // Digitos rolam conforme o filtro aperta o pool.
                        primaryValue: Double(heroAvailableCount(vm: vm)),
                        primaryCaption: "questões disponíveis",
                        stats: heroStats(vm: vm),
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)

                    // 2. Tags removíveis
                    FilterChipsRow(
                        chips: appliedFilterChips(vm: vm),
                        theme: .questoes,
                        onClearAll: { vm.clearAllFilters() }
                    )

                    // 2b. FILTROS na própria página (Rafael 2026-07-19): banca · anos ·
                    // formato · dificuldade · avançadas. Antes só viviam na sheet de
                    // settings; agora ficam à vista, cada um abre seu drawer collapsible.
                    Text("FILTROS")
                        .font(PixioTypo.sectionLabel)
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.sectionLabel)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    secondaryFilters(vm: vm)

                    // Quantidade, modo e o card "Conteúdo" SAÍRAM daqui
                    // (Rafael 2026-07-20): esta página é só o FILTRO — o que
                    // entra no bolo de questões. Quantidade e modo são decisão
                    // da sessão e agora vivem na tela que abre no "Iniciar
                    // treino"; disciplinas viraram filtro acima; histórico
                    // virou o botão do topo.
                }
                .padding(.bottom, 148)
            }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // O botão NÃO cria mais a sessão direto: ele abre a tela onde o
            // aluno dá nome, escolhe quantas e como. Antes ele apertava
            // "Iniciar" e já caía dentro do treino, sem ver o que ia começar.
            StickyBottomCTA(
                title: ctaTitle(vm: vm),
                count: vm.state.displayCount,
                isLoading: vm.state.previewLoading,
                isCreating: vm.state.creatingSession,
                theme: .questoes,
                action: { activeSheet = .start }
            )
        }
        .background(Color.clear)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            // Todas param na mesma altura (abaixo do hero) e usam o mesmo
            // material grafite dos cards — uma apresentação canônica, não três
            // combinações diferentes de detent e fundo.
            case .disciplines:
                QBankDisciplinesSheet(vm: vm)
                    .studyFilterSheet()
            case .recents:
                QBankRecentSessionsSheet(vm: vm) { sessionId, mode in
                    activeSheet = nil
                    onSessionCreated(sessionId, mode)
                }
                .studyFilterSheet()
            case .start:
                QBankStartSessionSheet(vm: vm) { sessionId, mode in
                    activeSheet = nil
                    onSessionCreated(sessionId, mode)
                }
                .studyFilterSheet()
            case .favorites:
                QBankFavoritesSheet()
                    .studyFilterSheet()
            }
        }
        .sheet(isPresented: $showStudioImport) {
            StudyMaterialPicker(title: "Gerar questões", actionVerb: "Gerar questões") { sourceIds in
                let pack = try await container.api.generateStudyPack(
                    sourceIds: sourceIds, mode: "practice",
                    includeQuestions: true, includeFlashcards: false
                )
                let sid = pack.qbankSessionId ?? ""
                return .init(label: "\(pack.counts.questions) questões criadas", open: { onSessionCreated(sid, .pratica) })
            }
        }
        // "1 sessão aberta global": Iniciar com um treino já aberto → prompt.
        .alert(
            "Você já tem um treino em aberto",
            isPresented: Binding(
                get: { vm.state.openSessionConflict != nil },
                set: { if !$0 { vm.state.openSessionConflict = nil } }
            ),
            presenting: vm.state.openSessionConflict
        ) { open in
            Button("Encerrar e começar novo", role: .destructive) {
                Task {
                    if let id = await vm.createSession(abandonExisting: true) {
                        onSessionCreated(id, vm.state.mode)
                    }
                }
            }
            Button("Cancelar", role: .cancel) { vm.state.openSessionConflict = nil }
        } message: { open in
            let name = open.title.map { " (\($0))" } ?? ""
            Text("Há um treino de \(open.typeLabel)\(name) em andamento. Começar um novo vai encerrá-lo.")
        }
    }

    // MARK: - Studio import row

    // MARK: - Sections

    private func quantitySection(vm: QBankBuilderViewModel) -> some View {
        StudyAmountSliderCard(
            title: "Quantidade",
            value: vm.state.questionCount,
            range: 5...100,
            step: 5,
            theme: .questoes,
            valueSuffix: "questões",
            presets: [10, 20, 30, 50, 100],
            onChange: { vm.setQuestionCount($0) }
        )
    }

    private func modeSection(vm: QBankBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 0) {
                ForEach(QBankMode.allCases, id: \.self) { m in
                    let isSelected = vm.state.mode == m
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { vm.setMode(m) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(m.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                            Text(m == .pratica ? "feedback a cada questão" : "gabarito no final")
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? VitaColors.accent.opacity(0.7) : VitaColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? VitaColors.accent.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? VitaColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard(cornerRadius: 14)
        }
    }

    private func quickAccessSection(vm: QBankBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conteúdo")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.sectionLabel)

            HStack(spacing: 10) {
                QBankQuickActionCard(
                    title: "Disciplinas",
                    subtitle: disciplineSummary(vm: vm),
                    value: disciplineValue(vm: vm),
                    icon: "square.grid.2x2",
                    theme: .questoes,
                    action: { activeSheet = .disciplines }
                )

                QBankQuickActionCard(
                    title: "Sessões",
                    subtitle: recentSessionsSummary(vm: vm),
                    value: "\(vm.state.recentSessions.count)",
                    icon: "clock.arrow.circlepath",
                    theme: .questoes,
                    action: { activeSheet = .recents }
                )
            }
        }
    }

    @ViewBuilder
    private func secondaryFilters(vm: QBankBuilderViewModel) -> some View {
        // ESPECIALIDADES é filtro e mora aqui com os outros (Rafael 2026-07-20).
        // Vivia escondida num card "Conteúdo" no fim da página, longe da seção
        // FILTROS — o aluno tinha que adivinhar que disciplina era filtro.
        // Reusa a folha que já existe (`.disciplines`), sem tela nova.
        QBankFilterRow(
            icon: "square.grid.2x2",
            title: "ESPECIALIDADES",
            summary: disciplineSummary(vm: vm),
            theme: .questoes,
            action: { activeSheet = .disciplines }
        )
        .padding(.horizontal, 16)

        if !vm.state.institutions.isEmpty {
            InstitutionsCollapsibleSection(
                institutions: vm.state.institutions,
                selectedIds: Binding(
                    get: { vm.state.selectedInstitutionIds },
                    set: { newSet in
                        let removed = vm.state.selectedInstitutionIds.subtracting(newSet)
                        let added = newSet.subtracting(vm.state.selectedInstitutionIds)
                        for id in removed { vm.toggleInstitution(id: id) }
                        for id in added { vm.toggleInstitution(id: id) }
                    }
                ),
                theme: .questoes
            )
            .padding(.horizontal, 16)
        }

        if !vm.state.years.isEmpty {
            YearsPickerSection(
                years: vm.state.years,
                counts: vm.state.yearCounts,
                selected: Binding(
                    get: { vm.state.selectedYears },
                    set: { vm.state.selectedYears = $0 }
                ),
                theme: .questoes,
                onChange: { vm.scheduleRefreshPreview() }
            )
            .padding(.horizontal, 16)
        }

        CollapsibleSectionCard(
            title: "Formato",
            icon: "doc.text",
            summary: formatSummary(vm: vm),
            theme: .questoes,
            expanded: $formatExpanded
        ) {
            FormatPills(
                selected: Binding(
                    get: { vm.state.selectedFormats },
                    set: { newSet in
                        let removed = vm.state.selectedFormats.subtracting(newSet)
                        let added = newSet.subtracting(vm.state.selectedFormats)
                        for f in removed { vm.toggleFormat(f) }
                        for f in added { vm.toggleFormat(f) }
                    }
                ),
                theme: .questoes,
                counts: vm.state.formatCounts
            )
        }
        .padding(.horizontal, 16)

        if !vm.state.difficulties.isEmpty {
            CollapsibleSectionCard(
                title: "Dificuldade",
                icon: "chart.bar",
                summary: difficultySummary(vm: vm),
                theme: .questoes,
                expanded: $difficultyExpanded
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.state.difficulties) { dc in
                            let label = "\(dc.displayLabel) (\(dc.count))"
                            QBankChip(
                                label: label,
                                isSelected: vm.state.selectedDifficulties.contains(dc.difficulty)
                            ) { vm.toggleDifficulty(dc.difficulty) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }

        AdvancedSection(
            items: advancedItems(vm: vm),
            theme: .questoes
        )
        .padding(.horizontal, 16)
    }

    private func difficultySection(vm: QBankBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DIFICULDADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.state.difficulties) { dc in
                            let label = "\(dc.displayLabel) (\(dc.count))"
                            QBankChip(
                                label: label,
                                isSelected: vm.state.selectedDifficulties.contains(dc.difficulty)
                            ) { vm.toggleDifficulty(dc.difficulty) }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func recentsSection(vm: QBankBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSÕES RECENTES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
                .padding(.horizontal, 16)
            VStack(spacing: 8) {
                ForEach(vm.state.recentSessions) { s in
                    QBankSessionCard(session: s, theme: .questoes) {
                        onSessionCreated(s.id, vm.state.mode)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func appliedFilterChips(vm: QBankBuilderViewModel) -> [FilterChipsRow.Chip] {
        var chips: [FilterChipsRow.Chip] = []
        for slug in vm.state.selectedGroupSlugs {
            let name = vm.state.groups.first(where: { $0.slug == slug })?.name ?? slug
            chips.append(.init(id: "g-\(slug)", label: name, onRemove: { vm.toggleGroup(slug: slug) }))
        }
        for d in vm.state.selectedDifficulties {
            let label = d == "easy" ? "Fácil" : d == "hard" ? "Difícil" : "Médio"
            chips.append(.init(id: "d-\(d)", label: label, onRemove: { vm.toggleDifficulty(d) }))
        }
        for f in vm.state.selectedFormats {
            let label = f == "objective" ? "Objetivas" : f == "discursive" ? "Discursivas" : "C/Imagem"
            chips.append(.init(id: "f-\(f)", label: label, onRemove: { vm.toggleFormat(f) }))
        }
        for id in vm.state.selectedInstitutionIds {
            if let inst = vm.state.institutions.first(where: { $0.id == id }) {
                chips.append(.init(id: "i-\(id)", label: inst.name, onRemove: { vm.toggleInstitution(id: id) }))
            }
        }
        return chips
    }

    private func advancedItems(vm: QBankBuilderViewModel) -> [AdvancedToggleItem] {
        qbankAdvancedToggles(vm: vm)
    }

    /// Hero do builder: pool disponível como métrica principal; histórico pessoal
    /// como estatísticas secundárias. Assim o card não parece quebrado para quem
    /// ainda não respondeu nada.
    /// O hero conta a HISTÓRIA do aluno: quanto fez, quanto acerta, quanto
    /// demora. "Por sessão" saiu porque não é conquista, é configuração — e o
    /// aluno já a ajusta em Quantidade, logo abaixo.
    ///
    /// O tempo médio por questão já era medido (`responseTimeMs` em cada
    /// resposta) e nunca aparecia em lugar nenhum. Para quem estuda pra prova
    /// cronometrada, ritmo é tão importante quanto acerto.
    private func heroStats(vm: QBankBuilderViewModel) -> [StudyHeroStat.Stat] {
        var stats: [StudyHeroStat.Stat] = [
            .init(value: formatNumber(vm.state.progressAnswered), label: "respondidas"),
            .init(value: heroAccuracyLabel(vm: vm), label: "de acerto"),
        ]
        if let pace = vm.state.avgSecondsPerQuestion, pace > 0 {
            stats.append(.init(value: paceLabel(pace), label: "por questão"))
        }
        return stats
    }

    private func ctaTitle(vm: QBankBuilderViewModel) -> String {
        let pool = vm.state.displayCount
        let count = min(vm.state.questionCount, pool)
        // "Calculando" enquanto o preview não voltou: dizer "sem questões" num
        // momento em que ainda NÃO SABEMOS é mentir pro aluno — era o que a
        // tela fazia no primeiro instante de cada abertura.
        if vm.state.previewLoading { return "Calculando…" }
        if pool == 0 { return "Sem questões disponíveis" }
        return "Iniciar (\(count) de \(formatNumber(pool)))"
    }

    /// "41s" abaixo de um minuto, "1m20" acima — ninguém lê "80s".
    private func paceLabel(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let rest = total % 60
        return rest == 0 ? "\(minutes)m" : "\(minutes)m\(rest)"
    }

    private func heroAvailableCount(vm: QBankBuilderViewModel) -> Int {
        if let preview = vm.state.previewCount { return preview }
        if vm.state.totalQuestions > 0 { return vm.state.totalQuestions }
        return vm.state.progressTotal
    }

    private func heroAccuracyLabel(vm: QBankBuilderViewModel) -> String {
        guard vm.state.progressAnswered > 0 else { return "—" }
        return "\(Int((vm.state.progressAccuracy * 100).rounded()))%"
    }

    private func formatSummary(vm: QBankBuilderViewModel) -> String {
        if vm.state.selectedFormats.isEmpty { return "Todos" }
        return "\(vm.state.selectedFormats.count) selec."
    }

    private func difficultySummary(vm: QBankBuilderViewModel) -> String {
        if vm.state.selectedDifficulties.isEmpty { return "Todas" }
        return "\(vm.state.selectedDifficulties.count) selec."
    }

    private func disciplineSummary(vm: QBankBuilderViewModel) -> String {
        let selectedCount = vm.state.selectedGroupSlugs.count + vm.state.selectedSubgroupIds.count
        if selectedCount == 0 { return "Todas as áreas" }
        if selectedCount == 1 {
            if let slug = vm.state.selectedGroupSlugs.first,
               let group = vm.state.groups.first(where: { $0.slug == slug }) {
                return group.name
            }
            return "1 seleção"
        }
        return "\(selectedCount) seleções"
    }

    private func disciplineValue(vm: QBankBuilderViewModel) -> String {
        let selectedCount = vm.state.selectedGroupSlugs.count + vm.state.selectedSubgroupIds.count
        return selectedCount == 0 ? "Tudo" : "\(selectedCount)"
    }

    private func recentSessionsSummary(vm: QBankBuilderViewModel) -> String {
        guard !vm.state.recentSessions.isEmpty else { return "Sem histórico" }
        if vm.state.recentSessions.contains(where: { $0.isActive }) {
            return "Retomar treino"
        }
        return "Revisar histórico"
    }


    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { idx in
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
                    if idx < 4 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
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

private enum QBankBuilderSheet: String, Identifiable {
    case disciplines
    case recents
    case start
    case favorites

    var id: String { rawValue }
}

private struct QBankQuickActionCard: View {
    let title: String
    let subtitle: String
    let value: String
    let icon: String
    let theme: StudyShellTheme
    let action: () -> Void

    var body: some View {
        Button {
            PixioHaptics.tap()
            action()
        } label: {
            VitaGlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(theme.primary.opacity(0.16))
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.primaryLight)
                        }
                        .frame(width: 34, height: 34)

                        Spacer(minLength: 4)

                        Text(value)
                            .font(PixioTypo.sans(size: 16, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(PixioTypo.cardTitle)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(PixioTypo.micro)
                            .foregroundStyle(VitaColors.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct QBankDisciplinesSheet: View {
    let vm: QBankBuilderViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard

                    if vm.state.groups.isEmpty && vm.state.filtersLoading {
                        groupsSkeleton
                    } else {
                        HorizontalDrillDown(
                            n1Title: "Áreas",
                            n2Title: "Disciplinas",
                            n3Title: "Conteúdos",
                            theme: .questoes,
                            n1Items: vm.state.groups.map { group in
                                DrillItem(
                                    id: group.slug,
                                    name: group.name,
                                    count: group.count,
                                    hasChildren: !group.children.isEmpty
                                )
                            },
                            selectedN1Ids: Binding(
                                get: { vm.state.selectedGroupSlugs },
                                set: { newSet in
                                    let removed = vm.state.selectedGroupSlugs.subtracting(newSet)
                                    let added = newSet.subtracting(vm.state.selectedGroupSlugs)
                                    for slug in removed { vm.toggleGroup(slug: slug) }
                                    for slug in added { vm.toggleGroup(slug: slug) }
                                }
                            ),
                            n2ItemsFor: { n1Id in
                                guard let group = vm.state.groups.first(where: { $0.slug == n1Id }) else {
                                    return []
                                }
                                return group.children.map { child in
                                    DrillItem(
                                        id: "\(child.parentSlug)/\(child.slug)",
                                        name: child.name,
                                        count: child.count,
                                        hasChildren: false
                                    )
                                }
                            },
                            selectedN2Ids: Binding(
                                get: { vm.state.selectedSubgroupIds },
                                set: { newSet in
                                    let removed = vm.state.selectedSubgroupIds.subtracting(newSet)
                                    let added = newSet.subtracting(vm.state.selectedSubgroupIds)
                                    for id in removed {
                                        if let parts = parseId(id) {
                                            vm.toggleSubgroup(parentSlug: parts.0, childSlug: parts.1)
                                        }
                                    }
                                    for id in added {
                                        if let parts = parseId(id) {
                                            vm.toggleSubgroup(parentSlug: parts.0, childSlug: parts.1)
                                        }
                                    }
                                }
                            ),
                            n3ItemsFor: { _ in [] },
                            selectedN3Ids: .constant([]),
                            onSelectionChange: {},
                            maxListHeight: nil
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Color.clear)
            .navigationTitle("Disciplinas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        PixioHaptics.soft()
                        clearDisciplineSelection()
                    }
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textSecondary)
                    .disabled(selectedCount == 0)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        PixioHaptics.tap()
                        dismiss()
                    }
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.accentLight)
                }
            }
        }
    }

    private var summaryCard: some View {
        VitaGlassCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.16))
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTitle)
                        .font(PixioTypo.cardTitle)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(formatNumber(vm.state.displayCount)) questões no pool atual")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { idx in
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

                    if idx < 4 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var selectedCount: Int {
        vm.state.selectedGroupSlugs.count + vm.state.selectedSubgroupIds.count
    }

    private var selectedTitle: String {
        if selectedCount == 0 { return "Todas as disciplinas" }
        if selectedCount == 1 {
            if let slug = vm.state.selectedGroupSlugs.first,
               let group = vm.state.groups.first(where: { $0.slug == slug }) {
                return group.name
            }
            return "1 seleção"
        }
        return "\(selectedCount) seleções"
    }

    private func clearDisciplineSelection() {
        vm.state.selectedGroupSlugs.removeAll()
        vm.state.selectedSubgroupIds.removeAll()
        vm.state.expandedGroupSlugs.removeAll()
        vm.scheduleRefreshPreview()
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

private struct QBankRecentSessionsSheet: View {
    let vm: QBankBuilderViewModel
    let onOpen: (String, QBankMode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if vm.state.recentSessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.state.recentSessions) { session in
                            QBankSessionCard(session: session, theme: .questoes) {
                                PixioHaptics.tap()
                                dismiss()
                                onOpen(session.id, vm.state.mode)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Color.clear)
            .navigationTitle("Sessões recentes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        PixioHaptics.tap()
                        dismiss()
                    }
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.accentLight)
                }
            }
        }
    }

    private var emptyState: some View {
        VitaGlassCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.14))
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nenhuma sessão ainda")
                        .font(PixioTypo.cardTitle)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("As sessões iniciadas aparecem aqui.")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

private struct QBankBuilderHeader: View {
    let onBack: () -> Void
    let onCreate: () -> Void
    let onHistory: () -> Void
    let onFavorites: () -> Void

    var body: some View {
        VitaScreenHeader(title: "Questões", onBack: onBack) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                // "+" = criar questoes do material do aluno (padrao das 3
                // ferramentas de estudo — Rafael 2026-07-12).
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))  // ds-allow: icone SF do botao criar
                        .foregroundStyle(VitaColors.surface)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VitaColors.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Criar questões do meu material")

                // Últimas sessões. Aqui existia um segundo botão de FILTROS que
                // abria uma folha com a mesma lista já presente na página, logo
                // abaixo do hero — dois caminhos para o mesmo ajuste, e o de
                // cima podia divergir do de baixo. Filtro mora na página; o topo
                // é atalho para o histórico (Rafael 2026-07-20).
                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone SF do botão de histórico
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VitaColors.glassBg.opacity(0.76)))
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Últimas sessões")

                // Favoritas. Irmao do historico: os dois sao "minhas coisas",
                // secundarios ao "+". Nao repete caminho de lugar nenhum —
                // ate hoje nao havia COMO ver o que o coracao salvou.
                Button(action: onFavorites) {
                    Image(systemName: "heart")
                        .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone SF do botão de favoritas
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VitaColors.glassBg.opacity(0.76)))
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minhas favoritas")
            }
        }
    }
}


/// Lista ÚNICA dos filtros avançados de Questões.
///
/// Ela vivia duplicada: uma cópia na tela e outra na folha "Configurar filtros",
/// idênticas linha a linha. Toggle novo entrava num lugar e faltava no outro —
/// foi o que quase aconteceu ao adicionar "Apenas questões de banca". Agora as
/// duas superfícies chamam daqui: muda aqui, muda no app inteiro.
@MainActor
private func qbankAdvancedToggles(vm: QBankBuilderViewModel) -> [AdvancedToggleItem] {
    [
        AdvancedToggleItem(
            icon: "checkmark.circle.fill",
            title: "Ocultar já acertadas",
            description: "Pula questões que você acertou",
            isOn: vm.state.hideAnswered,
            action: { vm.setHideAnswered(!vm.state.hideAnswered) }
        ),
        AdvancedToggleItem(
            icon: "bookmark.slash",
            title: "Ocultar revisadas",
            description: "Cards já marcados como revisados",
            isOn: vm.state.hideReviewed,
            action: { vm.setHideReviewed(!vm.state.hideReviewed) }
        ),
        AdvancedToggleItem(
            icon: "exclamationmark.octagon",
            title: "Ocultar anuladas",
            description: "Questões anuladas oficialmente pela banca",
            isOn: vm.state.hideAnnulled,
            action: { vm.setHideAnnulled(!vm.state.hideAnnulled) }
        ),
        AdvancedToggleItem(
            icon: "checkmark.seal.fill",
            title: "Apenas com gabarito",
            description: "Só Q com comentário detalhado",
            isOn: vm.state.excludeNoExplanation,
            action: { vm.setExcludeNoExplanation(!vm.state.excludeNoExplanation) }
        ),
        // As inéditas eram removidas sem toggle e sem aviso — 91.809 questões
        // que o aluno não sabia que existiam. Agora entram por padrão e quem
        // quiser só prova aplicada desliga aqui.
        AdvancedToggleItem(
            icon: "building.columns",
            title: "Apenas questões de banca",
            description: "Esconde as inéditas, deixa só prova aplicada",
            isOn: !vm.state.includeSynthetic,
            action: { vm.setIncludeSynthetic(!vm.state.includeSynthetic) }
        ),
    ]
}

