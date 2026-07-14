import SwiftUI

// MARK: - DisciplineDetailScreen
// Follows FaculdadeHomeScreen/FaculdadeMateriasScreen pattern:
// - No custom background (VitaAmbientBackground handles it globally)
// - VitaGlassCard for sections
// - VitaColors tokens only
// - All data from API, sections show useful state even when empty

struct DisciplineDetailScreen: View {
    let disciplineId: String
    let disciplineName: String

    var onBack: (() -> Void)?
    var onNavigateToFlashcards: ((String) -> Void)?
    var onNavigateToQBank: (() -> Void)?
    var onNavigateToSimulado: (() -> Void)?
    /// Abre a sessão RECÉM-GERADA pelo Vita (deck de flashcards / sessão de
    /// questões) a partir do material da disciplina. Rafael 2026-07-14.
    var onOpenFlashcardDeck: ((String) -> Void)?
    var onOpenQbankSession: ((String) -> Void)?

    @State private var vm: DisciplineDetailViewModel?
    @State private var showColorPicker = false
    @State private var colorRefreshTrigger: UUID = UUID()
    @State private var activeTab: Int = 0  // 0=Arquivos 1=Trabalhos 2=Provas
    @State private var showAllArquivos = false
    @State private var showAllTrabalhos = false
    @State private var showAllProvas = false
    private let tabPreviewLimit = 5
    @State private var currentName: String = ""
    @State private var showRenameDiscipline = false
    @State private var renameText = ""
    @State private var showRenameProfessor = false
    @State private var renameProfText = ""
    @State private var docSearch = ""
    @State private var showAddSheet = false
    @State private var showDocPicker = false
    @State private var uploading = false
    @State private var studyDocTarget: VitaDocument?
    @State private var renameDocTarget: VitaDocument?
    @State private var renameDocText = ""
    @State private var deleteDocTarget: VitaDocument?
    @State private var studyToast: String?
    /// Qual estudo o Vita vai GERAR do material da disciplina (abre o picker).
    @State private var generateKind: GenerateStudyKind?

    private var displayName: String { currentName.isEmpty ? disciplineName : currentName }
    @Environment(\.appContainer) private var container

    // Tokens — same as FaculdadeHomeScreen
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    /// O que o Vita gera do material escolhido na disciplina.
    private enum GenerateStudyKind: String, Identifiable {
        case flashcards, questoes
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let vm {
                if vm.isLoading {
                    DashboardSkeleton()
                        .tint(VitaColors.accent)
                        .padding(.top, 100)
                } else if let error = vm.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.dataAmber)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(textWarm)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 32)
                } else {
                    VStack(spacing: 14) {
                        heroCard(vm: vm)
                        unifiedCard(vm: vm)
                        studyCard(vm: vm)
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                DashboardSkeleton()
                    .tint(VitaColors.accent)
                    .padding(.top, 100)
            }
        }
        .onAppear {
            if vm == nil {
                vm = DisciplineDetailViewModel(
                    api: container.api,
                    disciplineId: disciplineId,
                    disciplineName: disciplineName,
                    dataManager: container.dataManager
                )
            }
        }
        .refreshable { await vm?.load() }
        .task {
            await vm?.load()
            ScreenLoadContext.finish(for: "DisciplineDetail")
        }
        .trackScreen("DisciplineDetail", extra: ["subject_id": disciplineId])
        .alert("Renomear disciplina", isPresented: $showRenameDiscipline) {
            TextField("Nome da disciplina", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                let n = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                currentName = n
                Task { await container.dataManager.renameSubject(id: disciplineId, displayName: n.isEmpty ? nil : n) }
            }
        }
        .alert("Renomear professor", isPresented: $showRenameProfessor) {
            TextField("Professor", text: $renameProfText)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                let n = renameProfText.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    await container.dataManager.renameProfessor(id: disciplineId, professor: n.isEmpty ? nil : n)
                    await vm?.load()
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            // Apresentação IDÊNTICA à gaveta canônica (VitaTabBar): sheet direto,
            // sem VitaSheet por fora (que dava chrome duplo/torto). Rafael 2026-07-13.
            VitaAddSheet(onSelect: { kind in
                showAddSheet = false
                handleAddKind(kind)
            })
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .presentationDetents([.height(360)])
            .presentationBackground(.clear)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDocPicker) {
            PdfTabDocumentPicker { url in
                showDocPicker = false
                uploadPickedPdf(url)
            }
        }
        .sheet(item: $generateKind) { kind in
            // O aluno escolhe o material da disciplina e o Vita GERA na hora
            // (flashcards ou questões) — igual o Treinar, acessível pela disciplina.
            // Abre já com a pasta desta disciplina ligada.
            StudyMaterialPicker(
                title: kind == .flashcards ? "Criar flashcards" : "Criar questões",
                actionVerb: kind == .flashcards ? "Gerar flashcards" : "Gerar questões",
                onGenerate: { sourceIds in
                    let pack = try await container.api.generateStudyPack(
                        sourceIds: sourceIds,
                        mode: "practice",
                        includeQuestions: kind == .questoes,
                        includeFlashcards: kind == .flashcards
                    )
                    if kind == .flashcards {
                        let deckId = pack.flashcardDeckId ?? ""
                        return .init(
                            label: "\(pack.counts.flashcards) flashcards criados",
                            open: { onOpenFlashcardDeck?(deckId) }
                        )
                    } else {
                        let sid = pack.qbankSessionId ?? ""
                        return .init(
                            label: "\(pack.counts.questions) questões criadas",
                            open: { onOpenQbankSession?(sid) }
                        )
                    }
                },
                initialSubjectName: displayName
            )
        }
        .confirmationDialog("Criar estudo deste arquivo", isPresented: Binding(get: { studyDocTarget != nil }, set: { if !$0 { studyDocTarget = nil } }), titleVisibility: .visible) {
            Button("Flashcards") { if let d = studyDocTarget { studyFromDoc(d, wantFlashcards: true) }; studyDocTarget = nil }
            Button("Questões") { if let d = studyDocTarget { studyFromDoc(d, wantFlashcards: false) }; studyDocTarget = nil }
            Button("Cancelar", role: .cancel) { studyDocTarget = nil }
        }
        .alert("Renomear arquivo", isPresented: Binding(get: { renameDocTarget != nil }, set: { if !$0 { renameDocTarget = nil } })) {
            TextField("Nome", text: $renameDocText)
            Button("Cancelar", role: .cancel) { renameDocTarget = nil }
            Button("Salvar") {
                if let d = renameDocTarget {
                    let n = renameDocText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !n.isEmpty { Task { try? await container.api.renameDocument(id: d.id, title: n); await vm?.load() } }
                }
                renameDocTarget = nil
            }
        }
        .confirmationDialog("Excluir este arquivo?", isPresented: Binding(get: { deleteDocTarget != nil }, set: { if !$0 { deleteDocTarget = nil } }), titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                if let d = deleteDocTarget { Task { try? await container.api.deleteDocument(id: d.id); await vm?.load() } }
                deleteDocTarget = nil
            }
            Button("Cancelar", role: .cancel) { deleteDocTarget = nil }
        }
        .overlay(alignment: .bottom) {
            if let toast = studyToast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))  // ds-allow: fontes cruas — padrão desta tela
                    .foregroundStyle(VitaColors.surface)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(VitaColors.accent))
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        withAnimation { studyToast = nil }
                    }
            }
        }
    }

    // "+" da disciplina: gaveta canônica escopada. Documento/Prova sobem um PDF
    // direto pra ESTA disciplina (aparece em Arquivos). Transcrição/Nota abrem
    // os fluxos existentes. Rafael 2026-07-13.
    private func handleAddKind(_ kind: VitaAddSheet.Kind) {
        switch kind {
        case .documento, .prova: showDocPicker = true
        case .transcricao: router.navigate(to: .transcricao)
        case .nota: router.navigate(to: .transcricao)
        }
    }

    private func uploadPickedPdf(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        let data = try? Data(contentsOf: url)
        if didAccess { url.stopAccessingSecurityScopedResource() }
        guard let data else { return }
        let name = url.lastPathComponent
        uploading = true
        Task {
            _ = try? await container.api.uploadDocument(fileData: data, fileName: name, subjectId: disciplineId)
            await vm?.load()
            uploading = false
        }
    }

    // Menu "..." (long-press) canônico por arquivo (C). Renomear/Favoritar/
    // Compartilhar/Excluir ligados nos endpoints que já existem.
    @ViewBuilder
    private func docContextMenu(_ doc: VitaDocument) -> some View {
        Button {
            renameDocText = doc.title.isEmpty ? doc.fileName : doc.title
            renameDocTarget = doc
        } label: { Label("Renomear", systemImage: "pencil") }

        Button {
            Task {
                try? await container.api.toggleDocumentFavorite(id: doc.id)
                await vm?.load()
            }
        } label: {
            Label(doc.isFavorite ? "Desfavoritar" : "Favoritar",
                  systemImage: doc.isFavorite ? "star.slash" : "star")
        }

        if let url = URL(string: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file") {
            ShareLink(item: url) { Label("Compartilhar", systemImage: "square.and.arrow.up") }
        }

        Button(role: .destructive) { deleteDocTarget = doc } label: {
            Label("Excluir", systemImage: "trash")
        }
    }

    // Gera material de estudo a partir de UM arquivo (B). Prepara a fonte e
    // dispara o study pack (flashcards ou questões).
    private func studyFromDoc(_ doc: VitaDocument, wantFlashcards: Bool) {
        Task {
            studyToast = wantFlashcards ? "Gerando flashcards…" : "Gerando questões…"
            guard let src = try? await container.api.ensureDocumentStudySource(documentId: doc.id) else {
                studyToast = "Não deu pra preparar o material"
                return
            }
            _ = try? await container.api.generateStudyPack(
                sourceIds: [src.studioSourceId],
                title: doc.title.isEmpty ? doc.fileName : doc.title,
                includeQuestions: !wantFlashcards,
                includeFlashcards: wantFlashcards
            )
            studyToast = wantFlashcards ? "Flashcards criados de \(doc.title.isEmpty ? doc.fileName : doc.title)"
                                        : "Questões criadas de \(doc.title.isEmpty ? doc.fileName : doc.title)"
        }
    }

    // MARK: - Hero Card

    private func heroCard(vm: DisciplineDetailViewModel) -> some View {
        let color = vm.subjectColor
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.045),
                    Color(red: 0.05, green: 0.035, blue: 0.022)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [color.opacity(0.22), Color.clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 140
            )

            Image(systemName: "book.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(color.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 16)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(vm.subjectStatus))
                            .frame(width: 5, height: 5)
                        Text(statusLabel(vm.subjectStatus))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(statusColor(vm.subjectStatus))
                    }
                    .padding(.bottom, 6)

                    Button {
                        renameText = displayName
                        showRenameDiscipline = true
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Text(displayName)
                                .font(.system(size: 20, weight: .bold))  // ds-allow: fontes cruas — padrão desta tela
                                .foregroundStyle(Color.white)
                                .kerning(-0.4)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                                .foregroundStyle(goldMuted.opacity(0.45))
                                .padding(.top, 5)
                        }
                    }
                    .buttonStyle(.plain)

                    // Workload + absences info
                    HStack(spacing: 12) {
                        if let wl = vm.workload, wl > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0fh", wl))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(goldMuted.opacity(0.65))
                        }
                        if let freq = vm.attendance {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0f%% freq", freq))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(freq >= 90 ? VitaColors.dataGreen.opacity(0.85) : freq >= 75 ? goldMuted.opacity(0.75) : VitaColors.dataRed.opacity(0.85))
                        }
                        if let abs = vm.absences {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.minus")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0f faltas", abs))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(abs > 10 ? VitaColors.dataRed.opacity(0.85) : goldMuted.opacity(0.65))
                        }
                    }
                    .padding(.top, 4)

                    // Professor + room
                    HStack(spacing: 12) {
                        Button {
                            renameProfText = vm.professorName ?? ""
                            showRenameProfessor = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))  // ds-allow: fontes cruas — padrão desta tela
                                Text(vm.professorName ?? "Adicionar professor")
                                    .font(.system(size: 11, weight: .medium))  // ds-allow: fontes cruas — padrão desta tela
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.system(size: 8))  // ds-allow: fontes cruas — padrão desta tela
                            }
                            .foregroundStyle(goldMuted.opacity(0.80))
                        }
                        .buttonStyle(.plain)
                        if let room = vm.room {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 9))
                                Text(room)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(goldMuted.opacity(0.65))
                        }
                    }
                    .padding(.top, 2)

                    // Horários (movido pro hero — antes era card separado)
                    if !vm.subjectSchedule.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 9))  // ds-allow: fontes cruas — padrão desta tela
                            Text(scheduleSummary(vm.subjectSchedule))
                                .font(.system(size: 11, weight: .medium, design: .rounded))  // ds-allow: fontes cruas — padrão desta tela
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(goldMuted.opacity(0.75))
                        .padding(.top, 4)
                    }

                    // Average
                    if let avg = vm.currentAverage {
                        let allGraded = vm.gradeSlots.allSatisfy { $0.value != nil }
                        HStack(spacing: 4) {
                            Text(allGraded ? "Média:" : "Média parcial:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(goldMuted.opacity(0.55))
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(gradeColor(normalized: avg))
                        }
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Color picker trigger — bottom trailing
            Button {
                showColorPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                    Circle()
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 14)
            .padding(.bottom, 12)
            .vitaBubble(isPresented: $showColorPicker, arrowEdge: .bottom) {
                SubjectColorPicker(subjectName: disciplineName) { _ in
                    colorRefreshTrigger = UUID()
                }
                .frame(width: 280)
            }
        }
        .frame(minHeight: 172)
        .id(colorRefreshTrigger)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            goldPrimary.opacity(0.40),
                            goldPrimary.opacity(0.10),
                            goldPrimary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private func vitaScoreBadge(score: Int) -> some View {
        let tierColor: Color = {
            if score >= 80 { return VitaColors.dataAmber }
            if score >= 60 { return VitaColors.dataGreen }
            if score >= 40 { return VitaColors.accent }
            return VitaColors.dataRed
        }()
        return ZStack {
            Circle()
                .fill(tierColor.opacity(0.15))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(tierColor.opacity(0.50), lineWidth: 1.5)
                .frame(width: 52, height: 52)
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tierColor)
                Text("VITA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(tierColor.opacity(0.80))
            }
        }
    }

    // MARK: - Unified card (Arquivos · Trabalhos · Provas)
    // Rafael 2026-07-13: um card só pra disciplina, com tabs em cima. Reusa os
    // builders de linha (docCategorySection/trabalhoRow/examRow) — sem duplicar.

    @ViewBuilder
    private func unifiedCard(vm: DisciplineDetailViewModel) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    VitaSubTabBar(titles: ["Arquivos", "Trabalhos", "Provas"], selected: $activeTab)
                    Button { showAddSheet = true } label: {
                        Image(systemName: uploading ? "arrow.up.circle" : "plus")
                            .font(.system(size: 15, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                            .foregroundStyle(goldPrimary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(VitaColors.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(uploading)
                    .padding(.trailing, 14)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)

                Rectangle().fill(glassBorder).frame(height: 0.5)

                Group {
                    switch activeTab {
                    case 1: trabalhosInner(vm: vm)
                    case 2: provasInner(vm: vm)
                    default: arquivosInner(vm: vm)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func arquivosInner(vm: DisciplineDetailViewModel) -> some View {
        let allDocs = vm.subjectDocuments
        if allDocs.isEmpty {
            emptyTab(icon: "folder", text: "Nenhum arquivo ainda")
        } else {
            let q = docSearch.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespaces)
            let filtered = q.isEmpty ? allDocs : allDocs.filter {
                ($0.title.isEmpty ? $0.fileName : $0.title)
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(q)
            }
            VStack(alignment: .leading, spacing: 0) {
                if allDocs.count > 6 { docSearchField }
                if q.isEmpty {
                    let cats = categorizedDocs(allDocs)
                    let shown = showAllArquivos ? cats : capCategories(cats, limit: tabPreviewLimit)
                    tabCount(allDocs.count, singular: "arquivo", plural: "arquivos")
                    ForEach(shown) { cat in docCategorySection(cat) }
                    if allDocs.count > tabPreviewLimit {
                        verMaisRow(total: allDocs.count, expanded: showAllArquivos) { showAllArquivos.toggle() }
                    }
                } else if filtered.isEmpty {
                    emptyTab(icon: "magnifyingglass", text: "Nada encontrado")
                } else {
                    tabCount(filtered.count, singular: "resultado", plural: "resultados")
                    ForEach(categorizedDocs(filtered)) { cat in docCategorySection(cat) }
                }
            }
        }
    }

    private var docSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))  // ds-allow: fontes cruas — padrão desta tela
                .foregroundStyle(textDim)
            TextField("Buscar arquivo...", text: $docSearch)
                .font(.system(size: 13))  // ds-allow: fontes cruas — padrão desta tela
                .foregroundStyle(textPrimary)
                .autocorrectionDisabled()
            if !docSearch.isEmpty {
                Button { docSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))  // ds-allow: fontes cruas — padrão desta tela
                        .foregroundStyle(textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitaColors.glassBg))  // ds-allow: campo de busca
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(glassBorder, lineWidth: 0.5))  // ds-allow: campo de busca
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func trabalhosInner(vm: DisciplineDetailViewModel) -> some View {
        let items = vm.subjectTrabalhos
        if items.isEmpty {
            emptyTab(icon: "doc.badge.clock", text: "Nenhum trabalho ainda")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    tabCountText(items.count, singular: "trabalho", plural: "trabalhos")
                    Spacer()
                    if !vm.trabalhosPending.isEmpty {
                        Text("\(vm.trabalhosPending.count) pendente\(vm.trabalhosPending.count > 1 ? "s" : "")")
                            .font(.system(size: 10, weight: .bold))  // ds-allow: fontes cruas — padrão desta tela
                            .foregroundStyle(VitaColors.dataAmber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(VitaColors.dataAmber.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                let shown = showAllTrabalhos ? items : Array(items.prefix(tabPreviewLimit))
                ForEach(Array(shown.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { rowDivider }
                    Button {
                        router.navigate(to: .trabalhoDetail(id: item.id))
                    } label: {
                        trabalhoRow(item)
                    }
                    .buttonStyle(.plain)
                }
                if items.count > tabPreviewLimit {
                    verMaisRow(total: items.count, expanded: showAllTrabalhos) {
                        showAllTrabalhos.toggle()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func provasInner(vm: DisciplineDetailViewModel) -> some View {
        let allExams = vm.subjectExams
        let hasNothing = !vm.hasAnyGrade && allExams.isEmpty && vm.nextExam == nil
        if hasNothing {
            emptyTab(icon: "checkmark.seal", text: "Nenhuma prova registrada ainda")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                gradesInner(vm: vm)
                if let exam = vm.nextExam {
                    nextExamInline(exam)
                }
                if !allExams.isEmpty {
                    let shownExams = showAllProvas ? allExams : Array(allExams.prefix(tabPreviewLimit))
                    VStack(alignment: .leading, spacing: 0) {
                        tabCount(allExams.count, singular: "avaliação", plural: "avaliações")
                        ForEach(Array(shownExams.enumerated()), id: \.element.id) { idx, exam in
                            if idx > 0 { rowDivider }
                            examRow(exam)
                        }
                        if allExams.count > tabPreviewLimit {
                            verMaisRow(total: allExams.count, expanded: showAllProvas) {
                                showAllProvas.toggle()
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Unified helpers

    private var rowDivider: some View {
        Rectangle().fill(glassBorder).frame(height: 0.5).padding(.horizontal, 16)
    }

    // Preview curto: mostra só os primeiros N docs (somando categorias), o resto
    // fica atrás do "Ver todos" pra não esticar o card e enterrar o "Estudar".
    private func capCategories(_ cats: [DocCategory], limit: Int) -> [DocCategory] {
        var remaining = limit
        var out: [DocCategory] = []
        for c in cats {
            if remaining <= 0 { break }
            let take = Array(c.docs.prefix(remaining))
            out.append(DocCategory(label: c.label, icon: c.icon, color: c.color, docs: take))
            remaining -= take.count
        }
        return out
    }

    @ViewBuilder
    private func verMaisRow(total: Int, expanded: Bool, toggle: @escaping () -> Void) -> some View {
        rowDivider
        Button(action: toggle) {
            HStack(spacing: 6) {
                Text(expanded ? "Ver menos" : "Ver todos (\(total))")
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))  // ds-allow: fontes cruas — padrão desta tela
            }
            .foregroundStyle(goldPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabCount(_ n: Int, singular: String, plural: String) -> some View {
        HStack {
            tabCountText(n, singular: singular, plural: plural)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func tabCountText(_ n: Int, singular: String, plural: String) -> some View {
        Text("\(n) \(n == 1 ? singular : plural)".uppercased())
            .font(.system(size: 10, weight: .bold))  // ds-allow: fontes cruas — padrão desta tela
            .tracking(0.6)
            .foregroundStyle(textDim)
    }

    @ViewBuilder
    private func emptyTab(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))  // ds-allow: fontes cruas — padrão desta tela
                .foregroundStyle(textDim)
            Text(text)
                .font(.system(size: 12))  // ds-allow: fontes cruas — padrão desta tela
                .foregroundStyle(textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func scheduleSummary(_ blocks: [AgendaClassBlock]) -> String {
        blocks.map { b in
            let d = Self.dayNames[max(0, min(6, b.dayOfWeek))]
            return "\(d) \(b.startTime)–\(b.endTime)"
        }.joined(separator: "   ·   ")
    }

    // MARK: - Grades (Notas — dentro da tab Provas)

    @ViewBuilder
    private func gradesInner(vm: DisciplineDetailViewModel) -> some View {
        VStack(spacing: 12) {
                HStack {
                    Text("Notas")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    if vm.hasGradeRisk {
                        Text("RISCO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(VitaColors.dataRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(VitaColors.dataRed.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let att = vm.attendance {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f%%", att))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(att >= 75 ? VitaColors.dataGreen : VitaColors.dataRed)
                    }
                }

                // Headers
                HStack(spacing: 0) {
                    ForEach(vm.gradeSlots, id: \.label) { slot in
                        Text(slot.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textDim)
                            .frame(maxWidth: .infinity)
                    }
                    Text("Final")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textDim)
                        .frame(maxWidth: .infinity)
                }

                Rectangle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(height: 0.5)

                // Values: "1.3/2 (6.5)" format with color based on normalized value
                HStack(spacing: 0) {
                    ForEach(vm.gradeSlots, id: \.label) { slot in
                        gradeSlotCell(value: slot.value, weight: slot.weight)
                    }
                    gradeCell(vm.finalGrade, maxValue: 10)
                }

                if !vm.hasAnyGrade {
                    Text("Nenhuma nota registrada ainda")
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .padding(.top, 4)
                }
        }
        .padding(.horizontal, 16)
    }

    /// Grade slot cell showing "value/weight (normalized)" e.g. "1.3/2 (6.5)"
    private func gradeSlotCell(value: Double?, weight: Double) -> some View {
        VStack(spacing: 2) {
            if let v = value {
                let norm = DisciplineDetailViewModel.normalized(v, weight: weight)
                Text(String(format: "%.1f/%.0f", v, weight))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: norm))
                Text("(\(String(format: "%.1f", norm)))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: norm).opacity(0.7))
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(textDim)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Simple grade cell for finalGrade (already on 0-10 scale)
    private func gradeCell(_ val: Double?, maxValue: Double) -> some View {
        VStack(spacing: 2) {
            Text(val.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(val.map { gradeColor(normalized: ($0 / maxValue) * 10.0) } ?? textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradeColor(normalized: Double) -> Color {
        if normalized >= 7.0 { return VitaColors.dataGreen }
        if normalized >= 5.0 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    // Dias da semana (0=Dom..6=Sáb) — usado no resumo de horários do hero.
    private static let dayNames = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    // MARK: - Next Exam (destaque dentro da tab Provas)

    private func nextExamInline(_ exam: ExamEntry) -> some View {
        let urgencyColor: Color = {
            if exam.daysUntil <= 0 { return VitaColors.dataRed }
            if exam.daysUntil <= 3 { return VitaColors.dataAmber }
            if exam.daysUntil <= 7 { return VitaColors.accent }
            return VitaColors.dataGreen
        }()
        return VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(urgencyColor)
                            Text("Próxima Prova")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(max(0, exam.daysUntil))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(urgencyColor)
                            Text(exam.daysUntil == 1 ? "dia" : "dias")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(urgencyColor.opacity(0.75))
                        }
                    }

                    Text(exam.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textPrimary)

                    if !exam.date.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundStyle(urgencyColor.opacity(0.80))
                            Text(formatDate(exam.date, format: "dd 'de' MMMM · HH:mm"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textWarm.opacity(0.60))
                        }
                    }

                    if let notes = exam.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(textWarm.opacity(0.55))
                            .lineLimit(3)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(urgencyColor.opacity(0.06)))  // ds-allow: destaque proxima prova
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: destaque proxima prova
                        .stroke(urgencyColor.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 16)
    }

    // MARK: - All Exams / Trabalhos / Documents — builders de linha reusados nas tabs

    private func examRow(_ exam: ExamEntry) -> some View {
        let isPast = exam.daysUntil < 0
        return HStack(spacing: 10) {
            Circle()
                .fill(isPast ? textDim : VitaColors.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(exam.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if !exam.date.isEmpty {
                    Text(formatDate(exam.date, format: "dd/MM/yyyy"))
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }

            Spacer()

            if let result = exam.result {
                Text(String(format: "%.1f", result))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: result))
            } else if !isPast {
                Text("\(exam.daysUntil)d")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(exam.daysUntil <= 7 ? VitaColors.dataAmber : textDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func trabalhoRow(_ item: TrabalhoItem) -> some View {
        let statusColor: Color = {
            if item.submitted { return VitaColors.dataGreen }
            if let d = item.daysUntil, d < 0 { return VitaColors.dataRed }
            if item.status == "graded" { return VitaColors.accent }
            if let d = item.daysUntil, d <= 3 { return VitaColors.dataAmber }
            return goldMuted
        }()
        let statusText: String = {
            if item.submitted { return "ENTREGUE" }
            if let d = item.daysUntil, d < 0 { return "ATRASADO" }
            if item.status == "graded" { return "CORRIGIDO" }
            return "PENDENTE"
        }()

        return HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if let date = item.dueDate {
                    let fmt = DateFormatter()
                    let _ = { fmt.locale = Locale(identifier: "pt_BR"); fmt.dateFormat = "dd/MM" }()
                    Text(fmt.string(from: date))
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Study Section (always visible)

    private func studyCard(vm: DisciplineDetailViewModel) -> some View {
        let progress = vm.subjectProgress
        return VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Estudar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Spacer()
                    if let p = progress, p.hoursSpent > 0 {
                        Text(String(format: "%.1fh estudadas", p.hoursSpent))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(textDim)
                    }
                }

                studyRow(
                    icon: "rectangle.on.rectangle.angled",
                    title: "Flashcards",
                    detail: "O Vita monta do seu material",
                    badge: nil,
                    badgeColor: .clear
                ) {
                    // O Vita GERA flashcards do material que o aluno escolher
                    // (slide/prova da disciplina) — não lista prateleira. Rafael 2026-07-14.
                    generateKind = .flashcards
                }

                Rectangle().fill(glassBorder).frame(height: 0.5)

                studyRow(
                    icon: "list.bullet.clipboard",
                    title: "Questões",
                    detail: "O Vita cria do seu material",
                    badge: nil,
                    badgeColor: .clear
                ) {
                    generateKind = .questoes
                }

                Rectangle().fill(glassBorder).frame(height: 0.5)

                studyRow(
                    icon: "clock.badge.checkmark",
                    title: "Simulados",
                    detail: simuladoDetail(vm),
                    badge: nil,
                    badgeColor: .clear
                ) {
                    onNavigateToSimulado?()
                }
            }
            .padding(16)
        }
    }

    private func flashcardDetail(_ vm: DisciplineDetailViewModel) -> String {
        if vm.flashcardsDue > 0 {
            return "\(vm.flashcardsDue) para revisar · \(vm.flashcardsTotal) total"
        } else if vm.flashcardsTotal > 0 {
            return "\(vm.flashcardsTotal) cards"
        }
        return "Iniciar flashcards"
    }

    private func questoesDetail(_ vm: DisciplineDetailViewModel) -> String {
        if let p = vm.subjectProgress, p.questionCount > 0 {
            let pct = Int(p.accuracy * 100)
            return "\(p.questionCount) respondidas · \(pct)% acerto"
        }
        return "Iniciar questões"
    }

    private func simuladoDetail(_ vm: DisciplineDetailViewModel) -> String {
        if let p = vm.subjectProgress, p.questionCount > 0 {
            return "Treinar com prova cronometrada"
        }
        return "Iniciar simulado"
    }

    private func studyRow(icon: String, title: String, detail: String, badge: String?, badgeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.accent.opacity(0.80))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.accent.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textDim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Documents (grouped by type)

    private struct DocCategory: Identifiable {
        var id: String { label }
        let label: String
        let icon: String
        let color: Color
        let docs: [VitaDocument]
    }

    private func categorizedDocs(_ docs: [VitaDocument]) -> [DocCategory] {
        var planos: [VitaDocument] = []
        var slides: [VitaDocument] = []
        var provas: [VitaDocument] = []
        var outros: [VitaDocument] = []

        for doc in docs {
            let t = doc.title.lowercased()
            if t.contains("plano") || t.contains("cronograma") || t.contains("ementa") || t.contains("syllabus") {
                planos.append(doc)
            } else if t.contains("apresenta") || t.contains("aula") || t.contains("slide") || t.contains("pptx") || doc.fileName.lowercased().hasSuffix(".pptx") {
                slides.append(doc)
            } else if t.contains("prova") || t.contains("ade") || t.contains("avaliação") || t.contains("simulado") || t.contains("gabarito") {
                provas.append(doc)
            } else {
                outros.append(doc)
            }
        }

        var result: [DocCategory] = []
        if !planos.isEmpty { result.append(DocCategory(label: "Planos de Ensino", icon: "list.clipboard", color: VitaColors.accent, docs: planos)) }
        if !slides.isEmpty { result.append(DocCategory(label: "Aulas & Slides", icon: "doc.richtext", color: VitaColors.dataAmber, docs: slides)) }
        if !provas.isEmpty { result.append(DocCategory(label: "Provas & Avaliações", icon: "checkmark.seal", color: VitaColors.dataRed, docs: provas)) }
        if !outros.isEmpty { result.append(DocCategory(label: "Outros Materiais", icon: "doc.text", color: goldPrimary, docs: outros)) }
        return result
    }

    @Environment(Router.self) private var router

    private func docCategorySection(_ cat: DocCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(cat.color.opacity(0.80))
                Text(cat.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(cat.color.opacity(0.65))
                Spacer()
                Text("\(cat.docs.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textDim)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ForEach(Array(cat.docs.enumerated()), id: \.element.id) { idx, doc in
                if idx > 0 {
                    Rectangle().fill(glassBorder).frame(height: 0.5)
                        .padding(.horizontal, 16)
                }
                HStack(spacing: 6) {
                    Button {
                        router.navigate(to: .pdfViewer(
                            url: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file",
                            title: doc.title,
                            documentId: doc.id,
                            studioSourceId: doc.studioSourceId
                        ))
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: docIcon(doc.fileName))
                                .font(.system(size: 12, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                                .foregroundStyle(cat.color.opacity(0.80))
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 6).fill(cat.color.opacity(0.10)))  // ds-allow: ícone do arquivo

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(doc.title.isEmpty ? doc.fileName : doc.title)
                                        .font(.system(size: 12, weight: .medium))  // ds-allow: fontes cruas — padrão desta tela
                                        .foregroundStyle(textPrimary)
                                        .lineLimit(1)
                                    if doc.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))  // ds-allow: fontes cruas — padrão desta tela
                                            .foregroundStyle(VitaColors.dataAmber)
                                    }
                                }
                                if let date = doc.displayDate {
                                    Text(formatDate(date, format: "dd/MM/yyyy"))
                                        .font(.system(size: 10))  // ds-allow: fontes cruas — padrão desta tela
                                        .foregroundStyle(textDim)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // ✦ criar estudo deste arquivo (B)
                    Button { studyDocTarget = doc } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                            .foregroundStyle(cat.color.opacity(0.9))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))  // ds-allow: fontes cruas — padrão desta tela
                        .foregroundStyle(textDim)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contextMenu { docContextMenu(doc) }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateStr: String, format: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
        guard let d = date else { return dateStr }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = format
        return fmt.string(from: d)
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "aprovado": return VitaColors.dataGreen
        case "reprovado": return VitaColors.dataRed
        default: return goldPrimary
        }
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "aprovado": return "APROVADO"
        case "reprovado": return "REPROVADO"
        case "cursando": return "CURSANDO"
        default: return "DISCIPLINA"
        }
    }

    private func docIcon(_ fileName: String) -> String {
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.text"
        case "ppt", "pptx": return "doc.richtext"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells"
        case "jpg", "jpeg", "png": return "photo"
        default: return "doc"
        }
    }
}
