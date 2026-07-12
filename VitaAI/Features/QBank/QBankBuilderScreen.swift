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
                        settingsCount: settingsActiveCount(vm: vm),
                        onBack: onBack,
                        onCreate: { showStudioImport = true },
                        onSettings: { activeSheet = .settings }
                    )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 1. Hero
                    StudyImageHeroStat(
                        imageAsset: "hero-questoes-v2",
                        eyebrow: "Treino clínico",
                        primary: formatNumber(heroAvailableCount(vm: vm)),
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

                    // 3. Quantidade e modo são controles globais da sessão.
                    quantitySection(vm: vm)
                        .padding(.horizontal, 16)

                    modeSection(vm: vm)
                        .padding(.horizontal, 16)

                    // 4. Conteúdo e histórico em camadas dedicadas.
                    quickAccessSection(vm: vm)
                        .padding(.horizontal, 16)

                    // 5. Criar do teu material (PDF/slides/foto -> questões via Studio)
                    studioImportRow
                        .padding(.horizontal, 16)

                }
                .padding(.bottom, 148)
            }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StickyBottomCTA(
                title: ctaTitle(vm: vm),
                count: vm.state.displayCount,
                isLoading: vm.state.previewLoading,
                isCreating: vm.state.creatingSession,
                theme: .questoes,
                action: {
                    Task {
                        if let id = await vm.createSession() {
                            onSessionCreated(id, vm.state.mode)
                        }
                    }
                }
            )
        }
        .background(Color.clear)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .disciplines:
                QBankDisciplinesSheet(vm: vm)
                    .presentationDetents([.large])
                    .presentationBackground(.ultraThinMaterial)
                    .presentationDragIndicator(.visible)
            case .recents:
                QBankRecentSessionsSheet(vm: vm) { sessionId, mode in
                    activeSheet = nil
                    onSessionCreated(sessionId, mode)
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
            case .settings:
                QBankSettingsSheet(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
                    .presentationDragIndicator(.visible)
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
    }

    // MARK: - Studio import row

    private var studioImportRow: some View {
        Button(action: { showStudioImport = true }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 18))  // ds-allow: icone da row
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Criar do teu material")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("PDF, slides ou foto viram questões")
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
        .background(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).fill(VitaColors.glassBg))
        .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).stroke(VitaColors.glassBorder, lineWidth: 0.75))
    }

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
            YearsRangeSection(
                minYear: Binding(
                    get: { vm.state.selectedYearMin },
                    set: { vm.state.selectedYearMin = $0 }
                ),
                maxYear: Binding(
                    get: { vm.state.selectedYearMax },
                    set: { vm.state.selectedYearMax = $0 }
                ),
                availableMin: vm.state.years.min() ?? 1995,
                availableMax: vm.state.years.max() ?? 2026,
                theme: .questoes,
                expanded: $yearsExpanded,
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
                theme: .questoes
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

    private func groupTitle(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Disciplinas"
        case .pbl: return "Sistemas"
        case .greatAreas: return "Áreas"
        }
    }

    /// Label genérico do nível 2 — usado em mensagens "sem X disponíveis".
    private func n2Title(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Temas"
        case .pbl: return "Clusters"
        case .greatAreas: return "Subáreas"
        }
    }

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
                description: "Remove questões marcadas como erro pelo banco",
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
            AdvancedToggleItem(
                icon: "rosette",
                title: "Apenas oficiais",
                description: "Exclui Q geradas por IA",
                isOn: !vm.state.includeSynthetic,
                action: { vm.setIncludeSynthetic(!(!vm.state.includeSynthetic)) }
            ),
        ]
    }

    /// Hero do builder: pool disponível como métrica principal; histórico pessoal
    /// como estatísticas secundárias. Assim o card não parece quebrado para quem
    /// ainda não respondeu nada.
    private func heroStats(vm: QBankBuilderViewModel) -> [StudyHeroStat.Stat] {
        var stats: [StudyHeroStat.Stat] = [
            .init(value: formatNumber(vm.state.progressAnswered), label: "respondidas"),
            .init(value: heroAccuracyLabel(vm: vm), label: "acerto"),
            .init(value: "\(vm.state.questionCount)", label: "por sessão"),
        ]
        if vm.state.streakDays > 0 {
            stats.append(.init(value: "\(vm.state.streakDays)d", label: "ofensiva"))
        }
        return stats
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

    private func settingsActiveCount(vm: QBankBuilderViewModel) -> Int {
        var count = 0
        if !vm.state.selectedInstitutionIds.isEmpty { count += 1 }
        if vm.state.selectedYearMin != nil || vm.state.selectedYearMax != nil { count += 1 }
        if !vm.state.selectedFormats.isEmpty { count += 1 }
        if !vm.state.selectedDifficulties.isEmpty { count += 1 }
        if vm.state.hideAnswered { count += 1 }
        if vm.state.hideReviewed { count += 1 }
        if vm.state.hideAnnulled { count += 1 }
        if !vm.state.excludeNoExplanation { count += 1 }
        if vm.state.includeSynthetic { count += 1 }
        return count
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

    private func ctaTitle(vm: QBankBuilderViewModel) -> String {
        let pool = vm.state.displayCount
        let count = min(vm.state.questionCount, pool)
        if pool == 0 { return "Sem questões disponíveis" }
        if vm.state.previewLoading { return "Iniciar Sessão" }
        return "Iniciar (\(count) de \(formatNumber(pool)))"
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
    case settings

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
                            n1Title: groupTitle(for: vm.state.lens),
                            n2Title: n2Title(for: vm.state.lens),
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

    private func groupTitle(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Disciplinas"
        case .pbl: return "Sistemas"
        case .greatAreas: return "Áreas"
        }
    }

    private func n2Title(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Temas"
        case .pbl: return "Clusters"
        case .greatAreas: return "Subáreas"
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
    let settingsCount: Int
    let onBack: () -> Void
    let onCreate: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VitaColors.glassBg.opacity(0.76)))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 2) {
                Text("Questões")
                    .font(PixioTypo.sans(size: 22, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
            }

            Spacer()

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

            Button(action: onSettings) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VitaColors.glassBg.opacity(0.76)))
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))

                    if settingsCount > 0 {
                        Text("\(settingsCount)")
                            .font(PixioTypo.micro)
                            .foregroundStyle(Color.black.opacity(0.88))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(VitaColors.accentLight))
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configurar filtros")
        }
    }
}

private struct QBankSettingsSheet: View {
    let vm: QBankBuilderViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var institutionsExpanded = false
    @State private var yearsExpanded = false
    @State private var formatExpanded = false
    @State private var difficultyExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerSummary

                    if !vm.state.institutions.isEmpty {
                        QBankInlineInstitutionsSection(
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
                            theme: .questoes,
                            expanded: $institutionsExpanded
                        )
                    }

                    if !vm.state.years.isEmpty {
                        YearsRangeSection(
                            minYear: Binding(
                                get: { vm.state.selectedYearMin },
                                set: { vm.state.selectedYearMin = $0 }
                            ),
                            maxYear: Binding(
                                get: { vm.state.selectedYearMax },
                                set: { vm.state.selectedYearMax = $0 }
                            ),
                            availableMin: vm.state.years.min() ?? 1995,
                            availableMax: vm.state.years.max() ?? 2026,
                            theme: .questoes,
                            expanded: $yearsExpanded,
                            onChange: { vm.scheduleRefreshPreview() }
                        )
                    }

                    CollapsibleSectionCard(
                        title: "Formato",
                        icon: "doc.text",
                        summary: formatSummary,
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
                            theme: .questoes
                        )
                    }

                    if !vm.state.difficulties.isEmpty {
                        CollapsibleSectionCard(
                            title: "Dificuldade",
                            icon: "chart.bar",
                            summary: difficultySummary,
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
                    }

                    AdvancedSection(
                        items: advancedItems,
                        theme: .questoes
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Color.clear)
            .navigationTitle("Configurar pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        PixioHaptics.soft()
                        vm.clearAllFilters()
                    }
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textSecondary)
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

    private var headerSummary: some View {
        VitaGlassCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.16))
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Ajustes finos")
                        .font(PixioTypo.cardTitle)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("Banca, ano, formato e dificuldade")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var formatSummary: String {
        vm.state.selectedFormats.isEmpty ? "Todos" : "\(vm.state.selectedFormats.count) selec."
    }

    private var difficultySummary: String {
        vm.state.selectedDifficulties.isEmpty ? "Todas" : "\(vm.state.selectedDifficulties.count) selec."
    }

    private var advancedItems: [AdvancedToggleItem] {
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
                description: "Remove questões marcadas como erro pelo banco",
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
            AdvancedToggleItem(
                icon: "rosette",
                title: "Apenas oficiais",
                description: "Exclui Q geradas por IA",
                isOn: !vm.state.includeSynthetic,
                action: { vm.setIncludeSynthetic(!(!vm.state.includeSynthetic)) }
            ),
        ]
    }
}

private struct QBankInlineInstitutionsSection: View {
    let institutions: [QBankInstitution]
    @Binding var selectedIds: Set<Int>
    let theme: StudyShellTheme
    @Binding var expanded: Bool

    @State private var search = ""

    private var summaryText: String {
        if selectedIds.isEmpty { return "Todas (\(institutions.count))" }
        return "\(selectedIds.count) selecionada\(selectedIds.count == 1 ? "" : "s")"
    }

    private var filtered: [QBankInstitution] {
        guard !search.isEmpty else { return institutions }
        let query = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return institutions.filter {
            $0.name
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        CollapsibleSectionCard(
            title: "Instituições",
            icon: "building.2",
            summary: summaryText,
            theme: theme,
            expanded: $expanded
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                    TextField("Buscar instituição", text: $search)
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(VitaColors.surfaceElevated.opacity(0.52))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        if filtered.isEmpty {
                            Text(search.isEmpty ? "Nenhuma instituição disponível" : "Nada encontrado")
                                .font(PixioTypo.caption)
                                .foregroundStyle(VitaColors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(filtered) { institution in
                                row(institution)
                                if institution.id != filtered.last?.id {
                                    Divider()
                                        .background(VitaColors.glassBorder.opacity(0.25))
                                        .padding(.leading, 34)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private func row(_ institution: QBankInstitution) -> some View {
        let isSelected = selectedIds.contains(institution.id)
        return Button {
            PixioHaptics.soft()
            if isSelected {
                selectedIds.remove(institution.id)
            } else {
                selectedIds.insert(institution.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(institution.name)
                        .font(PixioTypo.caption)
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.90))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let state = institution.state, !state.isEmpty {
                        Text(state)
                            .font(PixioTypo.micro)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()

                if let count = institution.count, count > 0 {
                    Text(formatNumber(count))
                        .font(PixioTypo.micro)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
