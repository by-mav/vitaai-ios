import SwiftUI
import Sentry

// MARK: - Simulados catalog

struct SimuladoBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoBuilderViewModel?
    @State private var selectedTab: SimuladoCatalogTab = .explore
    @State private var searchText = ""
    @State private var selectedCategory: OfficialExamCategory?
    @State private var selectedYears: Set<Int> = []
    @State private var selectedAuthorities: Set<String> = []
    @State private var selectedStates: Set<String> = []
    @State private var selectedStatus: OfficialExamStatusFilter?
    @State private var sortOrder: OfficialExamSort = .newest
    @State private var activeSheet: SimuladoSheet?
    @State private var qbankSimuladoSessionId: String?

    let onBack: () -> Void
    let onSessionCreated: (String) -> Void
    let onOpenAttempt: (SimuladoAttemptEntry) -> Void

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(StudyShellTheme.simulados.primaryLight)
            }
        }
        .onAppear {
            guard vm == nil else { return }
            let viewModel = SimuladoBuilderViewModel(api: container.api, dataManager: container.dataManager)
            vm = viewModel
            viewModel.boot()
            SentrySDK.reportFullyDisplayed()
        }
        .navigationBarHidden(true)
        .trackScreen("SimuladoBuilder")
    }

    @ViewBuilder
    private func content(vm: SimuladoBuilderViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                catalogTabs
                    .padding(.top, 12)

                switch selectedTab {
                case .explore:
                    exploreContent(vm: vm)
                case .mine:
                    attemptsContent(
                        attempts: vm.state.recentAttempts,
                        emptyTitle: "Seus simulados aparecerão aqui",
                        emptyMessage: "Use o botão + para montar um simulado com seu material.",
                        icon: "rectangle.stack.badge.plus"
                    )
                case .history:
                    attemptsContent(
                        attempts: vm.state.recentAttempts.filter { $0.finishedAt != nil },
                        emptyTitle: "Nenhum simulado concluído",
                        emptyMessage: "Quando você finalizar uma prova, o resultado ficará salvo aqui.",
                        icon: "clock.arrow.circlepath"
                    )
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.clear)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .filters:
                OfficialExamFilterSheet(
                    availableYears: vm.state.officialExamFacets?.years ?? [],
                    availableAuthorities: vm.state.officialExamFacets?.authorities ?? [],
                    availableStates: vm.state.officialExamFacets?.states.map(\.rawValue) ?? [],
                    selectedCategory: selectedCategory,
                    selectedYears: selectedYears,
                    selectedAuthorities: selectedAuthorities,
                    selectedStates: selectedStates,
                    selectedStatus: selectedStatus,
                ) { category, years, authorities, states, status in
                    selectedCategory = category
                    selectedYears = years
                    selectedAuthorities = authorities
                    selectedStates = states
                    selectedStatus = status
                    refreshCatalog(vm: vm)
                }
            case .studio:
                StudyMaterialPicker(title: "Montar simulado", actionVerb: "Montar simulado") { sourceIds in
                    let pack = try await container.api.generateStudyPack(
                        sourceIds: sourceIds,
                        mode: "simulado",
                        includeQuestions: true,
                        includeFlashcards: false
                    )
                    let sessionId = pack.qbankSessionId ?? ""
                    return .init(
                        label: "\(pack.counts.questions) questões no simulado",
                        open: { qbankSimuladoSessionId = sessionId }
                    )
                }
            case .exam(let exam):
                OfficialExamDetailSheet(exam: exam) {
                    activeSheet = nil
                    if exam.attemptStatus == .inProgress, let sessionId = exam.sessionId {
                        qbankSimuladoSessionId = sessionId
                        return
                    }
                    vm.selectOfficialExam(slug: exam.slug)
                    Task {
                        await Task.yield()
                        if let id = await vm.createCatalogSession() {
                            qbankSimuladoSessionId = id
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { qbankSimuladoSessionId != nil },
            set: { if !$0 { qbankSimuladoSessionId = nil } }
        )) {
            if let sessionId = qbankSimuladoSessionId {
                QBankCoordinatorScreen(
                    onBack: { qbankSimuladoSessionId = nil },
                    onHome: { qbankSimuladoSessionId = nil },
                    initialSessionId: sessionId,
                    initialMode: .simulado
                )
            }
        }
        .alert(
            "Você já tem um treino em aberto",
            isPresented: Binding(
                get: { vm.state.openSessionConflict != nil },
                set: { if !$0 { vm.state.openSessionConflict = nil } }
            ),
            presenting: vm.state.openSessionConflict
        ) { open in
            Button("Encerrar e iniciar o simulado", role: .destructive) {
                Task {
                    if let id = await vm.createCatalogSession(abandonExisting: true) {
                        qbankSimuladoSessionId = id
                    }
                }
            }
            Button("Cancelar", role: .cancel) { vm.state.openSessionConflict = nil }
        } message: { open in
            let name = open.title.map { " (\($0))" } ?? ""
            Text("Há um treino de \(open.typeLabel)\(name) em andamento. Iniciar o simulado vai encerrá-lo.")
        }
        .onChange(of: searchText) { _, _ in
            refreshCatalog(vm: vm)
        }
    }

    private var header: some View {
        VitaScreenHeader(title: "Simulados", onBack: onBack) {
            Button(action: { activeSheet = .studio }) {
                Image(systemName: "plus")
                    .font(PixioTypo.sans(size: 18, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(StudyShellTheme.simulados.primaryLight))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Montar simulado do meu material")
        }
    }

    private var catalogTabs: some View {
        HStack(spacing: 0) {
            ForEach(SimuladoCatalogTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 12) {
                        Text(tab.label)
                            .font(PixioTypo.sans(size: 15, weight: .semibold))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? StudyShellTheme.simulados.primaryLight
                                    : VitaColors.textSecondary
                            )
                            .frame(maxWidth: .infinity)

                        Capsule()
                            .fill(
                                selectedTab == tab
                                    ? StudyShellTheme.simulados.primaryLight
                                    : Color.clear
                            )
                            .frame(height: 3)
                            .padding(.horizontal, 10)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.glassBorder.opacity(0.55))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func exploreContent(vm: SimuladoBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            searchAndFilterBar
                .padding(.horizontal, 16)
                .padding(.top, 20)

            categoryRail(vm: vm)
                .padding(.top, 12)

            if hasSecondaryFilters {
                activeFilterChips
                    .padding(.top, 12)
            }

            let exams = vm.state.officialExams
            catalogSummary(count: vm.state.officialExamTotal, vm: vm)
                .padding(.horizontal, 16)
                .padding(.top, hasSecondaryFilters ? 14 : 8)

            if vm.state.officialExamsLoading && vm.state.officialExams.isEmpty {
                loadingRows
            } else if let error = vm.state.officialExamsError,
                      vm.state.officialExams.isEmpty {
                catalogEmptyState(
                    title: "Não foi possível carregar os simulados",
                    message: error,
                    icon: "wifi.exclamationmark",
                    actionTitle: "Tentar novamente",
                    action: { vm.retryOfficialExamCatalog() }
                )
            } else if exams.isEmpty {
                catalogEmptyState(
                    title: "Nenhum simulado encontrado",
                    message: "Tente remover um filtro ou buscar por outro termo.",
                    icon: "doc.text.magnifyingglass",
                    actionTitle: activeFilterCount > 0 ? "Limpar filtros" : nil,
                    action: { clearOfficialFilters(vm: vm) }
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(exams) { exam in
                        OfficialExamCatalogRow(exam: exam) {
                            activeSheet = .exam(exam)
                        }
                        .onAppear {
                            vm.loadMoreOfficialExamsIfNeeded(currentExam: exam)
                        }
                        Divider()
                            .overlay(VitaColors.glassBorder.opacity(0.45))
                            .padding(.leading, 96)
                    }
                    if vm.state.officialExamsLoadingMore {
                        ProgressView()
                            .tint(StudyShellTheme.simulados.primaryLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
            }
        }
    }

    private func categoryRail(vm: SimuladoBuilderViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(label: "Todos", icon: "square.grid.2x2", selected: selectedCategory == nil) {
                    selectedCategory = nil
                    refreshCatalog(vm: vm)
                }
                ForEach(OfficialExamCategory.allCases) { category in
                    categoryButton(
                        label: category.label,
                        icon: category.iconName,
                        selected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                        refreshCatalog(vm: vm)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryButton(
        label: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(PixioTypo.sans(size: 11, weight: .semibold))
                Text(label)
                    .font(PixioTypo.sans(size: 12, weight: .semibold))
            }
            .foregroundStyle(selected ? StudyShellTheme.simulados.primaryLight : VitaColors.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(
                    selected
                        ? StudyShellTheme.simulados.primary.opacity(0.18)
                        : VitaColors.surfaceElevated.opacity(0.45)
                )
            )
            .overlay(
                Capsule().stroke(
                    selected
                        ? StudyShellTheme.simulados.primaryLight.opacity(0.5)
                        : VitaColors.glassBorder.opacity(0.55),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(PixioTypo.sans(size: 17, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)

                TextField("Buscar instituição, prova ou ano", text: $searchText)
                    .font(PixioTypo.sans(size: 15))
                    .foregroundStyle(VitaColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpar busca")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .fill(VitaColors.surfaceElevated.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                    .stroke(VitaColors.glassBorder.opacity(0.65), lineWidth: 1)
            )

            Button(action: { activeSheet = .filters }) {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(PixioTypo.sans(size: 15, weight: .semibold))
                    Text("Filtros")
                        .font(PixioTypo.sans(size: 14, weight: .semibold))
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(PixioTypo.sans(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.surface)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(StudyShellTheme.simulados.primaryLight))
                    }
                }
                .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                .padding(.horizontal, 13)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                        .fill(StudyShellTheme.simulados.primary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                        .stroke(StudyShellTheme.simulados.primaryLight.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeFilterCount == 0 ? "Filtros" : "Filtros, \(activeFilterCount) ativos")
        }
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedYears.sorted(by: >), id: \.self) { year in
                    RemovableCatalogChip(label: "\(year)") {
                        selectedYears.remove(year)
                        vmRefreshFromEnvironment()
                    }
                }
                ForEach(selectedAuthorities.sorted(), id: \.self) { authority in
                    RemovableCatalogChip(label: authority) {
                        selectedAuthorities.remove(authority)
                        vmRefreshFromEnvironment()
                    }
                }
                ForEach(selectedStates.sorted(), id: \.self) { state in
                    RemovableCatalogChip(label: "⚑ \(state)") {
                        selectedStates.remove(state)
                        vmRefreshFromEnvironment()
                    }
                }
                if let selectedStatus {
                    RemovableCatalogChip(label: selectedStatus.label) {
                        self.selectedStatus = nil
                        vmRefreshFromEnvironment()
                    }
                }
                Button("Limpar") {
                    selectedYears.removeAll()
                    selectedAuthorities.removeAll()
                    selectedStates.removeAll()
                    selectedStatus = nil
                    vmRefreshFromEnvironment()
                }
                    .font(PixioTypo.sans(size: 13, weight: .semibold))
                    .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
        }
    }

    private func catalogSummary(count: Int, vm: SimuladoBuilderViewModel) -> some View {
        HStack {
            Text(count == 1 ? "1 simulado" : "\(count) simulados")
                .font(PixioTypo.sans(size: 13, weight: .medium))
                .foregroundStyle(VitaColors.textSecondary)

            Spacer()

            Menu {
                ForEach(OfficialExamSort.allCases) { option in
                    Button {
                        sortOrder = option
                        refreshCatalog(vm: vm)
                    } label: {
                        Label(option.label, systemImage: sortOrder == option ? "checkmark" : option.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sortOrder.label)
                    Image(systemName: "chevron.down")
                        .font(PixioTypo.sans(size: 10, weight: .bold))
                }
                .font(PixioTypo.sans(size: 13, weight: .medium))
                .foregroundStyle(VitaColors.textSecondary)
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 14)
    }

    private var loadingRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
                        .fill(VitaColors.glassBg)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 4)  // ds-allow: raio 4 ja e o padrao visual desta tela; sem token exato
                            .fill(VitaColors.glassBg)
                            .frame(width: 190, height: 15)
                        RoundedRectangle(cornerRadius: 4)  // ds-allow: raio 4 ja e o padrao visual desta tela; sem token exato
                            .fill(VitaColors.glassBg)
                            .frame(width: 230, height: 11)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private func attemptsContent(
        attempts: [SimuladoAttemptEntry],
        emptyTitle: String,
        emptyMessage: String,
        icon: String
    ) -> some View {
        if attempts.isEmpty {
            catalogEmptyState(
                title: emptyTitle,
                message: emptyMessage,
                icon: icon,
                actionTitle: selectedTab == .mine ? "Montar simulado" : nil,
                action: { activeSheet = .studio }
            )
            .padding(.top, 28)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(attempts) { attempt in
                    SimuladoBuilderAttemptCard(attempt: attempt) {
                        if attempt.origin == "native" {
                            onOpenAttempt(attempt)
                        } else {
                            qbankSimuladoSessionId = attempt.id
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }

    private func catalogEmptyState(
        title: String,
        message: String,
        icon: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(PixioTypo.sans(size: 30, weight: .light))
                .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.8))
                .frame(width: 58, height: 58)
                .background(Circle().fill(StudyShellTheme.simulados.primary.opacity(0.16)))
            Text(title)
                .font(PixioTypo.sans(size: 16, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(PixioTypo.sans(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(PixioTypo.sans(size: 13, weight: .semibold))
                    .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 44)
    }

    private var activeFilterCount: Int {
        (selectedCategory == nil ? 0 : 1)
            + selectedYears.count
            + selectedAuthorities.count
            + selectedStates.count
            + (selectedStatus == nil ? 0 : 1)
    }

    private var hasSecondaryFilters: Bool {
        !selectedYears.isEmpty || !selectedAuthorities.isEmpty || !selectedStates.isEmpty || selectedStatus != nil
    }

    private func clearOfficialFilters(vm: SimuladoBuilderViewModel) {
        selectedCategory = nil
        selectedYears.removeAll()
        selectedAuthorities.removeAll()
        selectedStates.removeAll()
        selectedStatus = nil
        refreshCatalog(vm: vm)
    }

    private func refreshCatalog(vm: SimuladoBuilderViewModel) {
        vm.updateOfficialExamCatalog(
            search: searchText,
            stages: selectedCategory?.catalogStages ?? [],
            years: Array(selectedYears),
            authorities: Array(selectedAuthorities),
            states: Array(selectedStates),
            statuses: selectedStatus.map { [$0.rawValue] } ?? [],
            sort: sortOrder.rawValue
        )
    }

    private func vmRefreshFromEnvironment() {
        guard let vm else { return }
        refreshCatalog(vm: vm)
    }
}

// MARK: - Catalog types

private enum SimuladoCatalogTab: String, CaseIterable, Identifiable {
    case explore
    case mine
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .explore: return "Explorar"
        case .mine: return "Meus"
        case .history: return "Histórico"
        }
    }
}

private enum OfficialExamSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case authority

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Mais recentes"
        case .oldest: return "Mais antigas"
        case .authority: return "Por banca"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .authority: return "textformat.abc"
        }
    }
}

private enum OfficialExamStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Não iniciadas"
        case .inProgress: return "Em andamento"
        case .completed: return "Concluídas"
        }
    }
}

private enum SimuladoSheet: Identifiable {
    case filters
    case studio
    case exam(ListOfficialQbankExams200ResponseExamsInner)

    var id: String {
        switch self {
        case .filters: return "filters"
        case .studio: return "studio"
        case .exam(let exam): return "exam-\(exam.slug)"
        }
    }
}

// MARK: - Official exam catalog row

private struct OfficialExamCatalogRow: View {
    let exam: ListOfficialQbankExams200ResponseExamsInner
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                authorityTag

                VStack(alignment: .leading, spacing: 5) {
                    Text(shortTitle)
                        .font(PixioTypo.sans(size: 15, weight: .bold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(exam.category?.label ?? exam.stage.capitalized)
                            .font(PixioTypo.sans(size: 10, weight: .semibold))
                            .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)  // ds-allow: raio 5 ja e o padrao visual desta tela; sem token exato
                                    .fill(StudyShellTheme.simulados.primary.opacity(0.18))
                            )

                        if let stateCode {
                            BrazilianStateFlagLabel(code: stateCode)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(exam.questionSelectionLabel)
                            .lineLimit(1)

                        if let durationText {
                            Text("•")
                            Text(durationText)
                        }

                    }
                    .font(PixioTypo.sans(size: 11))
                    .foregroundStyle(VitaColors.textSecondary)

                    statusLine
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(PixioTypo.sans(size: 12, weight: .bold))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(shortTitle), \(exam.questionSelectionLabel)")
        .accessibilityHint("Abre os detalhes do simulado")
    }

    private var authorityTag: some View {
        RoundedRectangle(cornerRadius: 10)  // ds-allow: raio 10 ja e o padrao visual desta tela; sem token exato
            .fill(VitaColors.surfaceElevated.opacity(0.92))
            .frame(width: 40, height: 40)
            .overlay(
                Text(authorityInitials)
                    .font(PixioTypo.sans(size: authorityInitials.count > 4 ? 8 : 10, weight: .bold))
                    .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)  // ds-allow: raio 10 ja e o padrao visual desta tela; sem token exato
                    .stroke(StudyShellTheme.simulados.primary.opacity(0.24), lineWidth: 1)
            )
    }

    private var authorityInitials: String {
        if let code = exam.authorityCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty {
            return String(code.prefix(6)).uppercased()
        }
        let trimmed = exam.authority.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 6 { return trimmed.uppercased() }
        let initials = trimmed
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return initials.isEmpty ? String(trimmed.prefix(6)).uppercased() : String(initials.prefix(6)).uppercased()
    }

    private var shortTitle: String {
        let prefix = exam.title
            .components(separatedBy: "—")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? exam.authority
        return prefix.contains("\(exam.year)") ? prefix : "\(prefix) \(exam.year)"
    }

    private var durationText: String? {
        guard let minutes = exam.timeLimitMinutes else { return nil }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(minutes) min" }
        return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)"
    }

    private var stateCode: String? { exam.state?.rawValue }

    @ViewBuilder
    private var statusLine: some View {
        switch exam.attemptStatus {
        case .notStarted:
            EmptyView()
        case .inProgress:
            HStack(spacing: 8) {
                Text("Em andamento")
                    .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                ProgressView(
                    value: Double(exam.answeredQuestions),
                    total: Double(max(1, exam.questionCount))
                )
                .tint(StudyShellTheme.simulados.primaryLight)
                Text("\(exam.answeredQuestions)/\(exam.questionCount)")
            }
            .font(PixioTypo.sans(size: 11, weight: .medium))
        case .completed:
            Label("Concluída", systemImage: "checkmark.circle.fill")
                .font(PixioTypo.sans(size: 11, weight: .medium))
                .foregroundStyle(VitaColors.dataGreen)
        }
    }
}

private struct BrazilianStateFlagLabel: View {
    let code: String

    private var normalizedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        HStack(spacing: 4) {
            Image("StateFlag\(normalizedCode)")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .accessibilityHidden(true)

            Text(normalizedCode)
        }
        .font(PixioTypo.sans(size: 9, weight: .bold))
        .foregroundStyle(VitaColors.textSecondary)
        .accessibilityLabel("Estado \(normalizedCode)")
    }
}

private struct RemovableCatalogChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 7) {
                Text(label)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(PixioTypo.sans(size: 10, weight: .bold))
            }
            .font(PixioTypo.sans(size: 12, weight: .semibold))
            .foregroundStyle(StudyShellTheme.simulados.primaryLight)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Capsule().fill(StudyShellTheme.simulados.primary.opacity(0.14)))
            .overlay(
                Capsule().stroke(StudyShellTheme.simulados.primaryLight.opacity(0.42), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remover filtro \(label)")
    }
}

// MARK: - Filter sheet

private struct OfficialExamFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let availableYears: [Int]
    let availableAuthorities: [String]
    let availableStates: [String]
    let onApply: (OfficialExamCategory?, Set<Int>, Set<String>, Set<String>, OfficialExamStatusFilter?) -> Void

    @State private var category: OfficialExamCategory?
    @State private var years: Set<Int>
    @State private var authorities: Set<String>
    @State private var states: Set<String>
    @State private var status: OfficialExamStatusFilter?
    @State private var authoritySearch = ""

    init(
        availableYears: [Int],
        availableAuthorities: [String],
        availableStates: [String],
        selectedCategory: OfficialExamCategory?,
        selectedYears: Set<Int>,
        selectedAuthorities: Set<String>,
        selectedStates: Set<String>,
        selectedStatus: OfficialExamStatusFilter?,
        onApply: @escaping (OfficialExamCategory?, Set<Int>, Set<String>, Set<String>, OfficialExamStatusFilter?) -> Void
    ) {
        self.availableYears = availableYears
        self.availableAuthorities = availableAuthorities
        self.availableStates = availableStates
        self.onApply = onApply
        _category = State(initialValue: selectedCategory)
        _years = State(initialValue: selectedYears)
        _authorities = State(initialValue: selectedAuthorities)
        _states = State(initialValue: selectedStates)
        _status = State(initialValue: selectedStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 11) {
                        filterSectionTitle("Tipo de prova")
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(OfficialExamCategory.allCases) { option in
                                filterChip(
                                    label: option.label,
                                    icon: option.iconName,
                                    selected: category == option
                                ) {
                                    category = category == option ? nil : option
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        filterSectionTitle("Ano")
                        if availableYears.isEmpty {
                            filterUnavailable("Os anos aparecerão quando o catálogo carregar.")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableYears, id: \.self) { year in
                                        filterChip(
                                            label: "\(year)",
                                            selected: years.contains(year)
                                        ) {
                                            toggle(year, in: &years)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        filterSectionTitle("Estado")
                        if availableStates.isEmpty {
                            filterUnavailable("Os estados aparecerão quando o catálogo carregar.")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableStates, id: \.self) { state in
                                        filterChip(
                                            label: state,
                                            icon: "flag.fill",
                                            selected: states.contains(state)
                                        ) {
                                            toggle(state, in: &states)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        filterSectionTitle("Instituição ou banca")
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(VitaColors.textTertiary)
                            TextField("Buscar instituição", text: $authoritySearch)
                                .font(PixioTypo.sans(size: 13))
                                .foregroundStyle(VitaColors.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10)  // ds-allow: raio 10 ja e o padrao visual desta tela; sem token exato
                                .fill(VitaColors.surfaceElevated.opacity(0.62))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)  // ds-allow: raio 10 ja e o padrao visual desta tela; sem token exato
                                .stroke(VitaColors.glassBorder.opacity(0.65), lineWidth: 1)
                        )

                        if filteredAuthorities.isEmpty {
                            filterUnavailable("Nenhuma instituição encontrada.")
                        } else {
                            LazyVStack(spacing: 5) {
                                ForEach(filteredAuthorities, id: \.self) { authority in
                                    Button {
                                        toggle(authority, in: &authorities)
                                    } label: {
                                        HStack {
                                            Text(authority)
                                                .font(PixioTypo.sans(size: 13, weight: .medium))
                                                .lineLimit(1)
                                            Spacer()
                                            if authorities.contains(authority) {
                                                Image(systemName: "checkmark")
                                                    .font(PixioTypo.sans(size: 12, weight: .bold))
                                            }
                                        }
                                        .foregroundStyle(
                                            authorities.contains(authority)
                                                ? Color.white
                                                : VitaColors.textSecondary
                                        )
                                        .padding(.horizontal, 12)
                                        .frame(height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 9)  // ds-allow: raio 9 ja e o padrao visual desta tela; sem token exato
                                                .fill(
                                                    authorities.contains(authority)
                                                        ? StudyShellTheme.simulados.primary.opacity(0.72)
                                                        : VitaColors.surfaceElevated.opacity(0.48)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 9)  // ds-allow: raio 9 ja e o padrao visual desta tela; sem token exato
                                                .stroke(VitaColors.glassBorder.opacity(0.55), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        filterSectionTitle("Status")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(label: "Todas", selected: status == nil) {
                                    status = nil
                                }
                                ForEach(OfficialExamStatusFilter.allCases) { option in
                                    filterChip(label: option.label, selected: status == option) {
                                        status = status == option ? nil : option
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            Button {
                onApply(category, years, authorities, states, status)
                dismiss()
            } label: {
                Text("Aplicar filtros")
                .font(PixioTypo.sans(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 13)  // ds-allow: raio 13 ja e o padrao visual desta tela; sem token exato
                        .fill(StudyShellTheme.simulados.primaryLight)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .presentationDetents([.fraction(0.82), .large])
        .presentationDragIndicator(.visible)
    }

    private var filterHeader: some View {
        HStack(spacing: 12) {
            Text("Filtrar simulados")
                .font(PixioTypo.sans(size: 18, weight: .bold))
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
            Button("Limpar", action: clear)
                .font(PixioTypo.sans(size: 12, weight: .semibold))
                .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                .disabled(!hasDraftFilters)
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(PixioTypo.sans(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(VitaColors.surfaceElevated))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar filtros")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private func filterSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(PixioTypo.sans(size: 11, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(VitaColors.sectionLabel)
    }

    private func filterChip(
        label: String,
        icon: String? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(PixioTypo.sans(size: 10, weight: .semibold))
                }
                Text(label)
                    .font(PixioTypo.sans(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? StudyShellTheme.simulados.primaryLight : VitaColors.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(
                    selected
                        ? StudyShellTheme.simulados.primary.opacity(0.28)
                        : VitaColors.surfaceElevated.opacity(0.48)
                )
            )
            .overlay(
                Capsule().stroke(
                    selected
                        ? StudyShellTheme.simulados.primaryLight.opacity(0.52)
                        : VitaColors.glassBorder.opacity(0.55),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func filterUnavailable(_ message: String) -> some View {
        Text(message)
            .font(PixioTypo.sans(size: 12))
            .foregroundStyle(VitaColors.textTertiary)
    }

    private var filteredAuthorities: [String] {
        let query = authoritySearch
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !query.isEmpty else { return availableAuthorities }
        return availableAuthorities.filter {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(query)
        }
    }

    private var hasDraftFilters: Bool {
        category != nil || !years.isEmpty || !authorities.isEmpty || !states.isEmpty || status != nil
    }

    private func clear() {
        category = nil
        years.removeAll()
        authorities.removeAll()
        states.removeAll()
        status = nil
    }

    private func toggle<Value: Hashable>(_ value: Value, in set: inout Set<Value>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

// MARK: - Official exam detail

private struct OfficialExamDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exam: ListOfficialQbankExams200ResponseExamsInner
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            exam.category?.label ?? exam.stage.capitalized,
                            systemImage: exam.category?.iconName ?? "doc.text.fill"
                        )
                            .font(PixioTypo.sans(size: 11, weight: .bold))
                            .foregroundStyle(StudyShellTheme.simulados.primaryLight)

                        Text(exam.authority)
                            .font(PixioTypo.sans(size: 24, weight: .bold))
                            .foregroundStyle(VitaColors.textPrimary)

                        Text(detailIdentityLine)
                            .font(PixioTypo.sans(size: 14))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    HStack(spacing: 10) {
                        detailMetric(value: "\(exam.questionCount)", label: "questões", icon: "list.number")
                        detailMetric(value: durationText, label: "duração", icon: "timer")
                        if exam.isBankBlock {
                            detailMetric(value: "\(exam.availableQuestions)", label: "no bloco", icon: "square.stack.3d.up")
                        } else {
                            detailMetric(value: "Integral", label: "formato", icon: "doc.text")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            exam.isBankBlock ? "Classificação do bloco" : "O que será preservado",
                            systemImage: exam.isBankBlock ? "tag.fill" : "checkmark.seal.fill"
                        )
                            .font(PixioTypo.sans(size: 15, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        if exam.isBankBlock {
                            detailLine("Tipo: \(exam.category?.label ?? exam.stage.capitalized)")
                            detailLine("Instituição: \(exam.tags.institution)")
                            detailLine("Ano: \(exam.tags.year)")
                            if let state = exam.state?.rawValue {
                                detailLine("Estado: \(state)")
                            }
                            detailLine(selectionExplanation)
                            detailLine("Gabarito e resultado geral ao finalizar")
                        } else {
                            detailLine("Ordem original das questões")
                            detailLine("Gabarito oficial da prova")
                            detailLine("Resultado geral ao finalizar")
                        }
                    }
                    .padding(16)
                    .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
                }
                .padding(20)
            }
            .background(VitaColors.surface.ignoresSafeArea())
            .navigationTitle(exam.isBankBlock ? "Detalhes do simulado" : "Detalhes da prova")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(startButtonTitle)
                    }
                    .font(PixioTypo.sans(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                            .fill(StudyShellTheme.simulados.primaryLight)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var durationText: String {
        guard let minutes = exam.timeLimitMinutes else { return "Livre" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(minutes) min" }
        return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)"
    }

    private var detailIdentityLine: String {
        [exam.authorityCode, exam.state?.rawValue, String(exam.year)]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    private var startButtonTitle: String {
        let noun = exam.isBankBlock ? "simulado" : "prova"
        switch exam.attemptStatus {
        case .notStarted: return "Iniciar \(noun)"
        case .inProgress: return "Continuar \(noun)"
        case .completed: return "Refazer \(noun)"
        }
    }

    private var selectionExplanation: String {
        if exam.availableQuestions > exam.questionCount {
            return "\(exam.questionCount) questões selecionadas entre \(exam.availableQuestions) disponíveis"
        }
        return "Todas as \(exam.questionCount) questões deste bloco serão usadas"
    }

    private func detailMetric(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(PixioTypo.sans(size: 14, weight: .semibold))
                .foregroundStyle(StudyShellTheme.simulados.primaryLight)
            Text(value)
                .font(PixioTypo.sans(size: 17, weight: .bold))
                .foregroundStyle(VitaColors.textPrimary)
            Text(label)
                .font(PixioTypo.sans(size: 11))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .vitaGlassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
    }

    private func detailLine(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(PixioTypo.sans(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.dataGreen)
            Text(text)
                .font(PixioTypo.sans(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
        }
    }
}

// MARK: - Existing attempts

private struct SimuladoBuilderAttemptCard: View {
    let attempt: SimuladoAttemptEntry
    let onTap: () -> Void

    private var isFinished: Bool { attempt.finishedAt != nil }
    private var scoreDisplay: String {
        if isFinished { return "\(Int(attempt.score * 100))%" }
        return "\(attempt.correctQ)/\(attempt.totalQ)"
    }

    private var dateDisplay: String {
        guard let raw = attempt.startedAt, raw.count >= 10 else { return "" }
        let parts = String(raw.prefix(10)).split(separator: "-")
        guard parts.count == 3 else { return "" }
        let months = ["", "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        if let month = Int(parts[1]), month > 0, month <= 12 {
            return "\(parts[2]) \(months[month])"
        }
        return "\(parts[2])/\(parts[1])"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md)
                        .fill(StudyShellTheme.simulados.primary.opacity(0.20))
                    Image(systemName: isFinished ? "checkmark.square" : "clock")
                        .font(PixioTypo.sans(size: 16, weight: .medium))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(attempt.title.isEmpty ? (attempt.subject ?? "Simulado") : attempt.title)
                        .font(PixioTypo.sans(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(attempt.totalQ) questões" + (dateDisplay.isEmpty ? "" : " · \(dateDisplay)"))
                        .font(PixioTypo.sans(size: 11))
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(scoreDisplay)
                        .font(PixioTypo.sans(size: 16, weight: .bold))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight)
                    Text(isFinished ? "Concluído" : "Em andamento")
                        .font(PixioTypo.sans(size: 9, weight: .semibold))
                        .foregroundStyle(isFinished ? VitaColors.dataGreen : StudyShellTheme.simulados.primaryLight)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}
