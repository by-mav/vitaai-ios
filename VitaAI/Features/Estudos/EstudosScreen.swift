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

    var body: some View {
        Group {
            if let viewModel {
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
}

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
                cabecalhoEstudos
                    .padding(.horizontal, 16)

                // Materiais no TOPO: é de onde se arrasta. Ficar no rodapé
                // escondia a interação inteira (mockup do Rafael 2026-07-23).
                materiaisSection
                    .padding(.horizontal, 16)

                ferramentasSection
                    .padding(.horizontal, 16)

                rodapeProgresso
                    .padding(.horizontal, 16)

                // Disciplinas e Materiais saíram daqui: disciplina mora na
                // Rotina (com adicionar manual/portal) e material tem porta
                // própria em Documentos. Estudos = so o que e estudar.

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
            onAtlas: { onNavigateToAtlas?() },
            onSoltarMaterial: { docId, f in soltouMaterial(docId, f) }
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

    // MARK: - Cabeçalho

    private var cabecalhoEstudos: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Estudos")
                .font(VitaTypography.headlineLarge)
                .foregroundStyle(VitaColors.textPrimary)
            Text("Arraste seus materiais para gerar recursos")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Meus materiais (origem do arrasto)

    private var materiaisSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            HStack {
                Text("Meus materiais")
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !viewModel.vitaDocuments.isEmpty {
                    Button {
                        onNavigateToPdfViewer != nil ? () : ()
                        router.navigate(to: .faculdadeDocumentos)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver tudo").font(VitaTypography.labelMedium)
                            Image(systemName: "chevron.right").font(VitaTypography.labelSmall)
                        }
                        .foregroundStyle(VitaColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.vitaDocuments.isEmpty {
                estudosEmptyRow(icon: "doc.text",
                                message: "Seus PDFs e materiais do portal aparecem aqui")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VitaTokens.Spacing.md) {
                        ForEach(viewModel.vitaDocuments.prefix(10)) { doc in
                            cartaoMaterial(doc)
                                .draggable(doc.id) {
                                    cartaoMaterial(doc).frame(width: 150).opacity(0.92)
                                }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(VitaTokens.Spacing.lg)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func cartaoMaterial(_ doc: VitaDocument) -> some View {
        let nome = doc.title.isEmpty ? doc.fileName : doc.title
        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: iconeDoMaterial(doc))
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                            .fill(VitaColors.accent.opacity(0.12))
                    )
                Spacer(minLength: 0)
                // pega-pra-arrastar: sinaliza que o card sai do lugar
                Image(systemName: "line.3.horizontal")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            Text(nome)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(detalheDoMaterial(doc))
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(VitaTokens.Spacing.md)
        .frame(width: 152, height: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.surfaceCard.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(VitaColors.glassBorder, lineWidth: 0.75)
        )
    }

    private func iconeDoMaterial(_ doc: VitaDocument) -> String {
        let n = (doc.fileName.isEmpty ? doc.title : doc.fileName).lowercased()
        if n.hasSuffix(".pdf") { return "doc.richtext" }
        if doc.source == "canvas" { return "link" }
        return "doc.text"
    }

    private func detalheDoMaterial(_ doc: VitaDocument) -> String {
        if doc.totalPages > 0 {
            return "\(doc.totalPages) página\(doc.totalPages == 1 ? "" : "s")"
        }
        if let s = doc.subjectName, !s.isEmpty { return s }
        return doc.source == "canvas" ? "Do portal" : "Enviado por você"
    }

    /// Soltou um material em cima de uma ferramenta.
    private func soltouMaterial(_ docId: String, _ ferramenta: StudyToolsGrid.Ferramenta) {
        guard let doc = viewModel.vitaDocuments.first(where: { $0.id == docId }) else { return }
        switch ferramenta {
        case .flashcards:
            quickGen = QuickGen(doc: doc, kind: .flashcards)
        case .questoes, .simulados:
            quickGen = QuickGen(doc: doc, kind: .questoes)
        case .transcricao:
            // Transcrição nasce de áudio, não de PDF: abre o material em vez de
            // fingir que gerou alguma coisa.
            router.navigate(to: .pdfViewer(
                url: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file",
                title: doc.title.isEmpty ? doc.fileName : doc.title,
                documentId: doc.id,
                studioSourceId: doc.studioSourceId
            ))
        }
    }

    // MARK: - Rodapé (números reais desta tela)

    private var rodapeProgresso: some View {
        HStack(spacing: VitaTokens.Spacing.lg) {
            numeroDoRodape(valor: "\(viewModel.flashcardsDue)",
                           rotulo: viewModel.flashcardsDue == 1 ? "card para revisar" : "cards para revisar")
            Rectangle()
                .fill(VitaColors.textWarm.opacity(0.08))
                .frame(width: 1, height: 30)
            // A sequencia abre a tela da ofensiva: calendario, plantao coberto
            // e marcos. E o unico lugar do app onde a chama e tocavel hoje.
            Button {
                router.navigate(to: .ofensiva)
            } label: {
                numeroDoRodape(valor: "\(viewModel.streakDays)",
                               rotulo: viewModel.streakDays == 1 ? "dia seguido" : "dias seguidos")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre sua ofensiva")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing.lg)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func numeroDoRodape(valor: String, rotulo: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(VitaTypography.headlineSmall)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(VitaColors.accent)
            Text(rotulo)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            sectionHeader("CONTINUE DE ONDE PAROU")

            if viewModel.recentActivity.isEmpty {
                estudosEmptyRow(icon: "clock", message: "Suas sessões aparecem aqui quando você começar a estudar")
            } else {
                // UM card so — antes eram varios cartoezinhos empilhados no pe
                // da tela, que ninguem via.
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentActivity.prefix(4).enumerated()), id: \.offset) { idx, activity in
                        activityRow(activity)
                        if idx < min(viewModel.recentActivity.count, 4) - 1 {
                            Rectangle()
                                .fill(VitaColors.textWarm.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
                .glassCard(cornerRadius: VitaTokens.Radius.lg)
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
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
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

