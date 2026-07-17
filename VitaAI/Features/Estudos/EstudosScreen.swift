import SwiftUI

// MARK: - EstudosScreen

struct EstudosScreen: View {
    @Environment(\.appContainer) private var container

    // Navigation callbacks — injected by AppRouter/MainTabView
    var onNavigateToCanvasConnect:    (() -> Void)?
    var onNavigateToNotebooks:         (() -> Void)?
    var onNavigateToMindMaps:          (() -> Void)?
    var onNavigateToFlashcardSession:  ((String) -> Void)?
    var onNavigateToFlashcardStats:    (() -> Void)?
    var onNavigateToFlashcardHome:     (() -> Void)?
    var onNavigateToPdfViewer:         ((URL) -> Void)?
    var onNavigateToSimulados:         (() -> Void)?
    var onNavigateToOsce:              (() -> Void)?
    var onNavigateToAtlas:             (() -> Void)?
    var onNavigateToCourseDetail:      ((String, String) -> Void)?
    var onNavigateToQBank:             (() -> Void)?
    var onNavigateToTranscricao:       (() -> Void)?
    var onNavigateToTrabalhos:         (() -> Void)?

    @State private var viewModel: EstudosViewModel?
    #if DEBUG
    @State private var isShowingGamePreview = false
    #endif

    var body: some View {
        Group {
            if let viewModel {
                #if DEBUG
                if isShowingGamePreview {
                    EstudosGamePreview(
                        viewModel: viewModel,
                        onClose: { isShowingGamePreview = false },
                        onNavigateToFlashcardSession: onNavigateToFlashcardSession,
                        onNavigateToFlashcardHome: onNavigateToFlashcardHome,
                        onNavigateToSimulados: onNavigateToSimulados,
                        onNavigateToCourseDetail: onNavigateToCourseDetail,
                        onNavigateToQBank: onNavigateToQBank,
                        onNavigateToTranscricao: onNavigateToTranscricao
                    )
                } else {
                    productionContent(viewModel)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            debugEntryButton
                        }
                }
                #else
                productionContent(viewModel)
                #endif
            } else {
                DashboardSkeleton()
                    .tint(VitaColors.accentHover)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModel(api: container.api, userEmail: container.authManager.userEmail)
                Task {
                    await viewModel?.load()
                    ScreenLoadContext.finish(for: "Estudos")
                }
            }
        }
        .trackScreen("Estudos")
    }

    private func productionContent(_ viewModel: EstudosViewModel) -> some View {
        EstudosContent(
            viewModel: viewModel,
            onNavigateToCanvasConnect:   onNavigateToCanvasConnect,
            onNavigateToNotebooks:        onNavigateToNotebooks,
            onNavigateToMindMaps:         onNavigateToMindMaps,
            onNavigateToFlashcardSession: onNavigateToFlashcardSession,
            onNavigateToFlashcardStats:   onNavigateToFlashcardStats,
            onNavigateToFlashcardHome:    onNavigateToFlashcardHome,
            onNavigateToPdfViewer:        onNavigateToPdfViewer,
            onNavigateToSimulados:        onNavigateToSimulados,
            onNavigateToOsce:             onNavigateToOsce,
            onNavigateToAtlas:            onNavigateToAtlas,
            onNavigateToCourseDetail:     onNavigateToCourseDetail,
            onNavigateToQBank:            onNavigateToQBank,
            onNavigateToTranscricao:      onNavigateToTranscricao,
            onNavigateToTrabalhos:        onNavigateToTrabalhos
        )
    }

    #if DEBUG
    private var debugEntryButton: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: VitaTokens.Animation.durationNormal)) {
                    isShowingGamePreview = true
                }
            } label: {
                Label("DEBUG", systemImage: "hammer.fill")
                    .font(VitaTypography.labelMedium)
                    .tracking(VitaTokens.Typography.letterSpacingWide)
                    .foregroundStyle(VitaColors.accentLight)
                    .padding(.horizontal, VitaTokens.Spacing.md)
                    .frame(minHeight: 44)
                    .glassCard(cornerRadius: VitaTokens.Radius.full)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("debug_estudos_preview")
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.xs)
        .background(VitaColors.surface.opacity(0.96))
    }
    #endif
}

#if DEBUG
// MARK: - Estudos Game Preview

/// Laboratório visual do novo Estudos. Vive somente em builds Debug e usa as
/// mesmas fontes de dados e rotas da tela de produção; não existe conteúdo fake.
private struct EstudosGamePreview: View {
    @Bindable var viewModel: EstudosViewModel
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    let onClose: () -> Void
    let onNavigateToFlashcardSession: ((String) -> Void)?
    let onNavigateToFlashcardHome: (() -> Void)?
    let onNavigateToSimulados: (() -> Void)?
    let onNavigateToCourseDetail: ((String, String) -> Void)?
    let onNavigateToQBank: (() -> Void)?
    let onNavigateToTranscricao: (() -> Void)?

    private var disciplines: [AcademicSubject] { appData.canonicalDisciplines }
    private var recommendation: DashboardRecommendation? { viewModel.studyRecommendations.first }

    private let tools: [PreviewTool] = [
        .init(image: "tool-questoes", title: "Questões", subtitle: "Pratique e evolua", accent: VitaColors.toolQBank, route: .questions),
        .init(image: "tool-flashcards", title: "Flashcards", subtitle: "Reforce o que importa", accent: VitaColors.toolFlashcards, route: .flashcards),
        .init(image: "tool-simulados", title: "Simulados", subtitle: "Teste seus conhecimentos", accent: VitaColors.toolSimulados, route: .simulados),
        .init(image: "tool-transcricao", title: "Transcrição", subtitle: "Treine sua escuta", accent: VitaColors.toolTranscricao, route: .transcricao),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: VitaTokens.Spacing.xs) {
                roomHero
                continuationCard
                trainingSection
                disciplinesSection
            }
            .padding(.horizontal, VitaTokens.Spacing._2xl + VitaTokens.Spacing.xxs)
            .padding(.top, VitaTokens.Spacing.xs)
            .padding(.bottom, VitaTokens.Spacing.lg)
        }
        .background {
            VitaColors.surface
                .overlay(VitaColors.black.opacity(0.18))
                .ignoresSafeArea()
        }
        .overlay {
            RadialGradient(
                colors: [.clear, VitaColors.black.opacity(0.08), VitaColors.black.opacity(0.34)],
                center: .center,
                startRadius: 160,
                endRadius: 460
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .refreshable { await viewModel.load() }
        .accessibilityIdentifier("estudos_game_preview")
    }

    private var roomHero: some View {
        ZStack(alignment: .bottom) {
            Image("hero-estudos-room")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 104)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: VitaColors.surface.opacity(0.86), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Text("Sala de Estudos")
                .font(VitaTypography.headlineMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .shadow(color: VitaColors.black.opacity(0.85), radius: 8, x: 0, y: 3)
                .padding(.bottom, VitaTokens.Spacing.sm)
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                .stroke(VitaColors.glassBorder.opacity(0.82), lineWidth: 1)
        }
        .onLongPressGesture(minimumDuration: 0.8, perform: onClose)
        .accessibilityAction(named: "Fechar prévia") { onClose() }
    }

    private var continuationCard: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image("study-deck-continuation")
                .resizable()
                .scaledToFill()
                .frame(width: 118, height: 138)
                .clipped()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                Text("CONTINUAR ESTUDANDO")
                    .font(VitaTypography.labelSmall)
                    .tracking(VitaTokens.Typography.letterSpacingWide * 2)
                    .foregroundStyle(VitaColors.accentLight.opacity(0.82))

                Text(continuationTitle)
                    .font(VitaTypography.headlineSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack {
                    Text(continuationMetric.label)
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                    Spacer(minLength: 0)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(VitaColors.textWarm.opacity(0.08))
                        Capsule()
                            .fill(VitaColors.goldBarGradient)
                            .frame(width: proxy.size.width * continuationMetric.progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Spacer(minLength: 0)
                    Button(action: openContinuation) {
                        HStack(spacing: VitaTokens.Spacing.sm) {
                            Text(continuationButtonTitle)
                                .font(VitaTypography.titleMedium)
                                .foregroundStyle(VitaColors.surface)

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(VitaTypography.titleSmall)
                                .foregroundStyle(VitaColors.accentLight)
                                .frame(width: 28, height: 28)
                                .background(VitaColors.surface.opacity(0.72), in: Circle())
                                .overlay {
                                    Circle().stroke(VitaColors.accentLight.opacity(0.30), lineWidth: 1)
                                }
                        }
                        .padding(.leading, VitaTokens.Spacing.lg)
                        .padding(.trailing, VitaTokens.Spacing.xs)
                        .frame(width: 150, height: 36)
                        .background(
                            LinearGradient(
                                colors: [VitaColors.accentHover.opacity(0.78), VitaColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule().stroke(VitaColors.accentLight.opacity(0.72), lineWidth: 1)
                        }
                        .shadow(color: VitaColors.accent.opacity(0.30), radius: 12, x: 0, y: 4)
                    }
                    .buttonStyle(VitaButtonPressStyle())
                    .accessibilityIdentifier("preview_continue_studying")
                }
                .padding(.top, VitaTokens.Spacing.md)
            }
            .padding(.trailing, VitaTokens.Spacing.xl)
            .padding(.vertical, VitaTokens.Spacing.sm)
        }
        .frame(height: 148)
        .frame(maxWidth: .infinity)
        .background {
            previewPanel(cornerRadius: VitaTokens.Radius.xl)
                .overlay {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.xl - 3, style: .continuous)
                        .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                        .padding(3)
                }
        }
    }

    private var continuationTitle: String {
        recommendation?.title ?? continuationSubject?.preferredName ?? "Sua próxima sessão"
    }

    private var continuationButtonTitle: String {
        let label = recommendation?.ctaText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? "Continuar" : label
    }

    private var continuationSubject: AcademicSubject? {
        guard let subjectName = recommendation?.subjectName, !subjectName.isEmpty else {
            return disciplines.first
        }
        return disciplines.first {
            $0.preferredName.localizedCaseInsensitiveContains(subjectName)
                || subjectName.localizedCaseInsensitiveContains($0.preferredName)
        } ?? disciplines.first
    }

    private var continuationMetric: (label: String, progress: CGFloat) {
        if let subject = continuationSubject, let metric = disciplineMetric(subject), metric.progress > 0 {
            return (metric.label, metric.progress)
        }
        if let recommendation, recommendation.urgency > 0 {
            let value = min(max(CGFloat(recommendation.urgency) / 100, 0), 1)
            return ("Prioridade \(recommendation.urgency)%", value)
        }
        if viewModel.flashcardsDue > 0 {
            return ("\(viewModel.flashcardsDue) para revisar", min(CGFloat(viewModel.flashcardsDue) / 20, 1))
        }
        return ("Pronto para começar", 0.08)
    }

    private func openContinuation() {
        if let recommendation {
            let type = recommendation.type.lowercased()
            if type.contains("flash") {
                if recommendation.deckId.isEmpty {
                    onNavigateToFlashcardHome?()
                } else {
                    onNavigateToFlashcardSession?(recommendation.deckId)
                }
                return
            }
            if type.contains("simulad") {
                onNavigateToSimulados?()
                return
            }
            if type.contains("quest") || type.contains("qbank") {
                onNavigateToQBank?()
                return
            }
        }
        if let subject = continuationSubject {
            onNavigateToCourseDetail?(subject.id, subject.preferredName)
        } else {
            onNavigateToQBank?()
        }
    }

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            sectionHeader(icon: "dumbbell.fill", title: "TREINAR")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: VitaTokens.Spacing.sm), GridItem(.flexible())],
                spacing: VitaTokens.Spacing.sm
            ) {
                ForEach(tools) { tool in
                    Button { openTool(tool.route) } label: {
                        toolCard(tool)
                    }
                    .buttonStyle(VitaButtonPressStyle())
                    .accessibilityIdentifier("preview_tool_\(tool.route.rawValue)")
                }
            }
        }
    }

    private func toolCard(_ tool: PreviewTool) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(tool.image)
                .resizable()
                .scaledToFill()
                .saturation(0.86)
                .contrast(1.08)
                .brightness(-0.04)
                .frame(height: 106)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.38),
                    .init(color: VitaColors.surface.opacity(0.96), location: 0.74),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: VitaTokens.Spacing.xs) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.title)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text(tool.subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.accentLight.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(VitaColors.surface.opacity(0.72), in: Circle())
                    .overlay { Circle().stroke(tool.accent.opacity(0.65), lineWidth: 1) }
            }
            .padding(VitaTokens.Spacing.sm)
        }
        .frame(height: 106)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .stroke(tool.accent.opacity(0.48), lineWidth: 1)
        }
        .shadow(color: tool.accent.opacity(0.10), radius: 10, x: 0, y: 4)
    }

    private func openTool(_ route: PreviewToolRoute) {
        switch route {
        case .questions: onNavigateToQBank?()
        case .flashcards: onNavigateToFlashcardHome?()
        case .simulados: onNavigateToSimulados?()
        case .transcricao: onNavigateToTranscricao?()
        }
    }

    private var disciplinesSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            HStack {
                sectionHeader(icon: "books.vertical.fill", title: "MINHAS DISCIPLINAS")
                Spacer(minLength: 0)
                if !disciplines.isEmpty {
                    Button { router.navigate(to: .faculdadeDisciplinas) } label: {
                        HStack(spacing: VitaTokens.Spacing.xs) {
                            Text("Ver todas")
                            Image(systemName: "chevron.right")
                        }
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.accentLight.opacity(0.88))
                        .frame(height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }

            if disciplines.isEmpty {
                Text("Adiciona uma disciplina para começar.")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(VitaTokens.Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background { previewPanel(cornerRadius: VitaTokens.Radius.lg) }
            } else {
                ForEach(Array(disciplines.prefix(4).enumerated()), id: \.element.id) { index, subject in
                    disciplineRow(subject, index: index)
                }
            }
        }
        .padding(.top, VitaTokens.Spacing.sm)
    }

    private func disciplineRow(_ subject: AcademicSubject, index: Int) -> some View {
        let spec = DisciplineImages.iconSpec(for: subject.disciplineSlug ?? subject.name)
        let metric = disciplineMetric(subject)
        let color = disciplinePreviewColor(at: index)
        let symbol = disciplinePreviewSymbol(at: index, fallback: spec.symbol)

        return Button {
            onNavigateToCourseDetail?(subject.id, subject.preferredName)
        } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                previewFolderIcon(symbol: symbol, color: color)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: VitaTokens.Spacing.xs) {
                        Text(subject.preferredName)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let metric {
                            Text(metric.label)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.accentLight.opacity(0.84))
                        }
                        Image(systemName: "chevron.right")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.accentLight.opacity(0.68))
                    }

                    if let metric, metric.progress > 0 {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(VitaColors.textWarm.opacity(0.07))
                                Capsule()
                                    .fill(VitaColors.goldBarGradient)
                                    .frame(width: proxy.size.width * metric.progress)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .frame(height: 40)
            .background { previewPanel(cornerRadius: VitaTokens.Radius.lg) }
        }
        .buttonStyle(VitaButtonPressStyle())
        .accessibilityIdentifier("preview_subject_\(subject.id)")
    }

    private func previewFolderIcon(symbol: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                .fill(VitaColors.textPrimary.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                        .fill(color.opacity(0.72))
                }
                .frame(width: 34, height: 30)
                .offset(y: 2)

            RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                .fill(color.opacity(0.54))
                .frame(width: 27, height: 24)
                .offset(x: -3, y: -2)

            RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                .fill(color.opacity(0.78))
                .frame(width: 14, height: 6)
                .offset(x: -8, y: -13)

            Image(systemName: symbol)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.86))
                .offset(y: 3)
        }
        .frame(width: 40, height: 34)
        .shadow(color: color.opacity(0.18), radius: 5, x: 0, y: 3)
    }

    private func disciplinePreviewColor(at index: Int) -> Color {
        let colors = [VitaColors.dataIndigo, VitaColors.dataBlue, VitaColors.dataRed, VitaColors.toolFlashcards]
        return colors[index % colors.count]
    }

    private func disciplinePreviewSymbol(at index: Int, fallback: String) -> String {
        let symbols = ["brain.head.profile", "heart.fill", "flask.fill", "person.3.fill"]
        return symbols.indices.contains(index) ? symbols[index] : fallback
    }

    private func disciplineMetric(_ subject: AcademicSubject) -> (label: String, progress: CGFloat)? {
        let docs = viewModel.vitaDocuments.filter { $0.subjectId == subject.id }
        let totalPages = docs.reduce(0) { $0 + max($1.totalPages, 0) }
        let currentPages = docs.reduce(0) { $0 + min(max($1.currentPage, 0), max($1.totalPages, 0)) }
        if totalPages > 0 {
            return ("\(currentPages) de \(totalPages)", min(CGFloat(currentPages) / CGFloat(totalPages), 1))
        }
        if let finalGrade = subject.finalGrade {
            return ("\(String(format: "%.1f", finalGrade)) de 10", min(max(CGFloat(finalGrade) / 10, 0), 1))
        }
        if let attendance = subject.attendance {
            return ("\(Int(attendance.rounded()))%", min(max(CGFloat(attendance) / 100, 0), 1))
        }
        if let dashboardSubject = dashboardSubject(matching: subject),
           let vitaScore = dashboardSubject.vitaScore,
           vitaScore > 0 {
            let value = min(max(CGFloat(vitaScore) / 100, 0), 1)
            return ("\(Int(vitaScore.rounded()))%", value)
        }
        if let count = subject.questionCount, count > 0 {
            return ("\(count) questões", 0)
        }
        if !docs.isEmpty {
            return (docs.count == 1 ? "1 material" : "\(docs.count) materiais", 0)
        }
        return nil
    }

    private func dashboardSubject(matching subject: AcademicSubject) -> DashboardSubject? {
        viewModel.dashboardSubjects.first {
            if let subjectId = $0.subjectId, !subjectId.isEmpty, subjectId == subject.id { return true }
            let dashboardName = ($0.name ?? $0.shortName ?? "")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let subjectName = subject.preferredName
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return !dashboardName.isEmpty && (dashboardName.contains(subjectName) || subjectName.contains(dashboardName))
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(VitaTypography.labelMedium)
            Text(title)
                .font(VitaTypography.labelSmall)
                .tracking(VitaTokens.Typography.letterSpacingWide * 2)
        }
        .foregroundStyle(VitaColors.accentLight.opacity(0.82))
        .frame(height: 20)
    }

    private func previewPanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [VitaColors.surfaceElevated.opacity(0.94), VitaColors.surface.opacity(0.99)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            }
            .shadow(color: VitaColors.black.opacity(0.34), radius: 10, x: 0, y: 5)
    }
}

private struct PreviewTool: Identifiable {
    let image: String
    let title: String
    let subtitle: String
    let accent: Color
    let route: PreviewToolRoute
    var id: String { route.rawValue }
}

private enum PreviewToolRoute: String {
    case questions
    case flashcards
    case simulados
    case transcricao
}

#endif

// MARK: - Content

private struct EstudosContent: View {
    @Bindable var viewModel: EstudosViewModel
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router
    @Environment(\.appContainer) private var container

    // Ação rápida "o Vita monta do material" em cada material recente (mesmo
    // motor vLLM do StudyMaterialPicker, mas já gerando aquele arquivo). Rafael 2026-07-14.
    enum QuickGenKind: String { case flashcards, questoes }
    struct QuickGen: Identifiable {
        let doc: VitaDocument
        let kind: QuickGenKind
        var id: String { doc.id + kind.rawValue }
    }
    @State private var quickGen: QuickGen?

    let onNavigateToCanvasConnect:    (() -> Void)?
    let onNavigateToNotebooks:         (() -> Void)?
    let onNavigateToMindMaps:          (() -> Void)?
    let onNavigateToFlashcardSession:  ((String) -> Void)?
    let onNavigateToFlashcardStats:    (() -> Void)?
    let onNavigateToFlashcardHome:     (() -> Void)?
    let onNavigateToPdfViewer:         ((URL) -> Void)?
    let onNavigateToSimulados:         (() -> Void)?
    let onNavigateToOsce:              (() -> Void)?
    let onNavigateToAtlas:             (() -> Void)?
    let onNavigateToCourseDetail:      ((String, String) -> Void)?
    let onNavigateToQBank:             (() -> Void)?
    let onNavigateToTranscricao:       (() -> Void)?
    let onNavigateToTrabalhos:         (() -> Void)?

    // Design tokens — matching FaculdadeHomeScreen
    private var goldPrimary: Color { VitaColors.accentHover }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    private struct StudyDisciplineRow: Identifiable {
        let id: String
        let title: String
        let rawName: String
        let finalGrade: Double?
        let attendance: Double?
    }

    /// Subjects shown in Estudos merge portal grades with the canonical Vita
    /// disciplines. Portal rows carry grade/frequency; Vita-only rows prevent
    /// mapped topics like Patologia from disappearing when the portal current
    /// semester payload does not include them.
    private var studyDisciplines: [StudyDisciplineRow] {
        // Fonte única: matérias em curso (`/api/subjects` via canonicalDisciplines),
        // já ordenadas e com as notas (finalGrade/attendance) embutidas. Sem
        // mesclar gradesResponse nem deduplicar no cliente (Rafael 2026-07-02).
        appData.canonicalDisciplines.map { subject in
            StudyDisciplineRow(
                id: subject.id,
                title: subject.preferredName,
                rawName: subject.name,
                finalGrade: subject.finalGrade,
                attendance: subject.attendance
            )
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Ferramentas — cards de IMAGEM no topo (Rafael 2026-07-15: o
                // hero saiu; voltaram as artes tool-* que a gente já tinha).
                ferramentasSection
                    .padding(.horizontal, 16)

                // 3. Disciplinas atuais — vertical list, Faculdade card pattern
                disciplinasSection
                    .padding(.horizontal, 16)

                // 4. Materiais recentes — horizontal scroll
                materiaisSection
                    .padding(.horizontal, 16)

                // 5. Trabalhos pendentes
                trabalhosSection
                    .padding(.horizontal, 16)

                // 6. Sessões recentes
                sessoesSection
                    .padding(.horizontal, 16)

                // Sem clearance: passa por trás da TabBar Liquid Glass.
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(item: $quickGen) { g in
            // Reusa o MESMO motor vLLM (StudyMaterialPicker), mas já gerando o
            // material tocado — sem escolher nada. Cai direto na sessão gerada.
            StudyMaterialPicker(
                title: g.kind == .flashcards ? "Criar flashcards" : "Criar questões",
                actionVerb: g.kind == .flashcards ? "Gerar flashcards" : "Gerar questões",
                onGenerate: { sourceIds in
                    let pack = try await container.api.generateStudyPack(
                        sourceIds: sourceIds,
                        mode: "practice",
                        includeQuestions: g.kind == .questoes,
                        includeFlashcards: g.kind == .flashcards
                    )
                    if g.kind == .flashcards {
                        let deckId = pack.flashcardDeckId ?? ""
                        return .init(
                            label: "\(pack.counts.flashcards) flashcards criados",
                            open: { onNavigateToFlashcardSession?(deckId) }
                        )
                    } else {
                        let sid = pack.qbankSessionId ?? ""
                        return .init(
                            label: "\(pack.counts.questions) questões criadas",
                            open: { router.navigate(to: .qbankSession(sessionId: sid)) }
                        )
                    }
                },
                autoStartDocument: g.doc
            )
        }
    }

    // MARK: - 1. Ferramentas Section

    // Ferramentas = cards de IMAGEM (arte tool-*), componente único StudyToolsGrid.
    private var ferramentasSection: some View {
        StudyToolsGrid(
            onQuestoes: { onNavigateToQBank?() },
            onFlashcards: { onNavigateToFlashcardHome?() },
            onSimulados: { onNavigateToSimulados?() },
            onTranscricao: { onNavigateToTranscricao?() },
            onAtlas: { onNavigateToAtlas?() }
        )
    }

    // MARK: - 3. Disciplinas Section

    private var disciplinasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("DISCIPLINAS ATUAIS")
                Spacer()
                if !studyDisciplines.isEmpty {
                    Button {
                        router.navigate(to: .faculdadeDisciplinas)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            if studyDisciplines.isEmpty {
                estudosEmptyRow(icon: "graduationcap", message: "Conecte seu portal para ver suas disciplinas")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(studyDisciplines.prefix(4))) { subject in
                        Button {
                            onNavigateToCourseDetail?(subject.id, subject.title)
                        } label: {
                            disciplinaCard(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func disciplinaCard(_ subject: StudyDisciplineRow) -> some View {
        let color = SubjectColors.colorFor(subject: subject.rawName)
        let shortName = subject.title
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if let grade = subject.finalGrade {
                        disciplinaMiniStat("Nota", value: String(format: "%.1f", grade))
                    }
                    if let freq = subject.attendance {
                        disciplinaMiniStat("Freq", value: String(format: "%.0f%%", freq))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textWarm.opacity(0.20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Mesmo card canônico das outras linhas da tela (trabalhoRow/activityRow):
        // chrome inline duplicado = as linhas divergiam do DS. (unificação 2026-07-03)
        .glassCard(cornerRadius: 12)
    }

    private func disciplinaMiniStat(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textDim)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.70))
        }
    }

    // MARK: - 4. Materiais Recentes Section

    private var materiaisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MATERIAIS RECENTES")

            if viewModel.vitaDocuments.isEmpty {
                estudosEmptyRow(icon: "doc.text", message: "Conecte seu portal para ver materiais")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.vitaDocuments.prefix(8)) { document in
                            MaterialCard(
                                document: document,
                                onTap: {
                                    router.navigate(to: .pdfViewer(
                                        url: "\(AppConfig.apiBaseURL)/documents/\(document.id)/file",
                                        title: document.title.isEmpty ? document.fileName : document.title,
                                        documentId: document.id,
                                        studioSourceId: document.studioSourceId
                                    ))
                                },
                                onGenerate: { kind in quickGen = QuickGen(doc: document, kind: kind) }
                            )
                        }
                    }
                    .padding(.horizontal, 1) // prevent clipping shadows
                }
            }
        }
    }

    // MARK: - 5. Trabalhos Section

    private var trabalhosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("TRABALHOS PENDENTES")
                Spacer()
                if !viewModel.trabalhosPending.isEmpty || !viewModel.trabalhosOverdue.isEmpty {
                    Button { onNavigateToTrabalhos?() } label: {
                        HStack(spacing: 3) {
                            Text("Ver todos")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            let preview = Array((viewModel.trabalhosOverdue + viewModel.trabalhosPending).prefix(3))
            if preview.isEmpty {
                estudosEmptyRow(icon: "checkmark.circle", message: "Nenhum trabalho pendente")
            } else {
                VStack(spacing: 8) {
                    ForEach(preview) { item in
                        trabalhoRow(item)
                    }
                }
            }
        }
    }

    private func trabalhoRow(_ item: TrabalhoItem) -> some View {
        let isOverdue = (item.daysUntil ?? 0) < 0
        let barColor: Color = isOverdue ? VitaColors.dataRed : VitaColors.accent

        return HStack(spacing: 10) {
            Rectangle()
                .fill(barColor)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)
                Text(item.subjectName)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(textDim)
                    .lineLimit(1)
            }

            Spacer()

            if let days = item.daysUntil {
                Text(trabalhoDaysLabel(days))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(barColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 12)
    }

    private func trabalhoDaysLabel(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d atrasado" }
        if days == 0 { return "Hoje" }
        if days == 1 { return "Amanhã" }
        return "Em \(days)d"
    }

    // MARK: - 6. Sessões Recentes Section

    private var sessoesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SESSÕES RECENTES")

            if viewModel.recentActivity.isEmpty {
                estudosEmptyRow(icon: "clock", message: "Nenhuma sessão recente")
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.recentActivity) { activity in
                        activityRow(activity)
                    }
                }
            }
        }
    }

    private func activityRow(_ activity: ActivityFeedItem) -> some View {
        let icon = activityIcon(for: activity.action)
        let title = activity.action.replacingOccurrences(of: "_", with: " ").capitalized
        let timeStr = relativeTime(from: activity.createdAt)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(goldPrimary.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(goldPrimary.opacity(0.06), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.60))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.85))
                if activity.xpAwarded > 0 {
                    Text("+\(activity.xpAwarded) XP")
                        .font(.system(size: 9.5))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()

            Text(timeStr)
                .font(.system(size: 9.5))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard(cornerRadius: 12)
    }

    private func activityIcon(for action: String) -> String {
        let a = action.lowercased()
        if a.contains("flashcard") { return "rectangle.on.rectangle.angled" }
        if a.contains("qbank") || a.contains("question") { return "checkmark.square" }
        if a.contains("simulado") { return "text.badge.checkmark" }
        return "display"
    }

    private func relativeTime(from isoString: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: isoString)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: isoString)
        }
        guard let d = date else { return "" }
        let interval = Date().timeIntervalSince(d)
        if interval < 3600 { return "\(Int(interval / 60))min" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 172800 { return "Ontem" }
        return "\(Int(interval / 86400))d"
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(VitaColors.sectionLabel)
    }

    private func estudosEmptyRow(icon: String, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(goldPrimary.opacity(0.35))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Material Card (horizontal scroll cell)

private struct MaterialCard: View {
    let document: VitaDocument
    let onTap: () -> Void
    let onGenerate: (EstudosContent.QuickGenKind) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.accentHover.opacity(0.08))
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.accentHover.opacity(0.70))
                }
                .frame(height: 72)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title.isEmpty ? document.fileName : document.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.90))
                        .lineLimit(2)
                    Text(document.subjectName ?? "")
                        .font(.system(size: 9.5))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.surfaceCard.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            // ✦ = "o Vita monta estudo DESTE material" (direto, sem entrar).
            // Overlay por cima do card: pega o toque do ✦; o resto abre o material.
            Menu {
                Button { onGenerate(.flashcards) } label: {
                    Label("Fazer flashcards", systemImage: "rectangle.on.rectangle.angled")
                }
                Button { onGenerate(.questoes) } label: {
                    Label("Fazer questões", systemImage: "list.bullet.clipboard")
                }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold)) // ds-allow: botão de ação rápida — área de toque
                    .foregroundStyle(VitaColors.surface)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(VitaColors.accentHover))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
            .padding(6)
        }
        .accessibilityLabel(document.title.isEmpty ? document.fileName : document.title)
    }
}
