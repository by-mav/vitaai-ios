import PhotosUI
import SwiftUI
import Sentry

// MARK: - FlashcardBuilderScreen — Fase 5 reescrita gold-standard
//
// Tela única que substitui o builder embutido em FlashcardsListScreen.
// Composição vertical com mode selector visivel inline (Revisao/Especifico/Novos),
// lente operacional só quando mode=.specific, decks grid embaixo, e CTA sticky.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.3 + §11.3
//
// Layout vertical mirror do QBankBuilderScreen mas com diff por pagina conforme
// spec §11.3:
//   Hero → Mode → (Lente só se Specific) → Tags → Especialidades → [colapsadas]
//   → Limite → Decks Grid → CTA

struct FlashcardBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: FlashcardBuilderViewModel?
    // Default state §11.2 — colapsadas: Origem
    // (Instituições, Anos quando A7 publicar wrappers ficam colapsados também;
    // Avançadas (AdvancedSection) já é collapsible nativo com default false)
    /// Baralhos marcados pra estudar juntos (Cardiologia + Medicina de Família...). Rafael 2026-07-10.
    @State private var selectedDeckIds: Set<String> = []
    @State private var showStudioImport = false
    /// Gaveta do "+" — "Selecione o que você quer fazer" (Rafael 2026-07-19).
    @State private var showCreateHub = false
    @State private var showCreateDeck = false
    /// "Criar com o Vita" — hub dos 6 caminhos de criação assistida.
    @State private var showCreateWithVita = false
    @State private var showPasteNotes = false
    @State private var showNotesCamera = false
    @State private var showNotesPhotoLibrary = false
    @State private var notesPhotoItem: PhotosPickerItem?
    /// Foto capturada → StudyMaterialPicker em modo auto-upload (sheet por item).
    @State private var notesPhotoUpload: NotesPhotoUpload?

    private struct NotesPhotoUpload: Identifiable {
        let id = UUID()
        let file: StudyMaterialPicker.AutoUploadFile
    }
    @State private var deckSearch: String = ""
    @State private var showSessionSettings = false
    /// Quando vem de DisciplineDetailScreen → flashcardHome(subjectId), pré-seleciona
    /// essa disciplina e abre em mode `.specific`. nil = comportamento padrão (mode `.due`).
    var initialSubjectId: String? = nil
    let onBack: () -> Void
    let onOpenDeck: (String) -> Void
    /// Abre "Explorar decks pré-fabricados" (rota .flashcardExplore).
    var onExplore: () -> Void = {}
    /// Abre a Transcrição (Gravar aula / Arquivo de áudio do "Criar com o Vita").
    var onOpenTranscricao: () -> Void = {}
    /// Abre a sessão de uma disciplina da Biblioteca: recebe o id da sessão que o
    /// servidor montou (a fila já está no `FlashcardMultiDeckHandoff`).
    let onOpenDisciplineSession: (_ sessionId: String) -> Void
    /// Toque numa disciplina em andamento — trava a linha e evita sessão dupla.
    @State private var openingDisciplineSlug: String? = nil

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(StudyShellTheme.flashcards.primaryLight)
            }
        }
        .onAppear {
            if vm == nil {
                vm = FlashcardBuilderViewModel(api: container.api)
                vm?.boot()
                vm?.setInitialSubject(slug: initialSubjectId)
                SentrySDK.reportFullyDisplayed()
            } else {
                // Voltou da sessao (VM viva): re-busca stats+decks pra "hoje"/
                // "pendentes" refletirem as revisoes recem-feitas.
                Task { await vm?.refresh() }
            }
        }
        .navigationBarHidden(true)
        .trackScreen("FlashcardBuilder")
    }

    @ViewBuilder
    private func content(vm: FlashcardBuilderViewModel) -> some View {
        VStack(spacing: 0) {
            appBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GlassTextField(
                        placeholder: "Buscar baralhos",
                        text: $deckSearch,
                        icon: "magnifyingglass"
                    )
                    deckList(vm: vm)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedDeckIds.isEmpty {
                StickyBottomCTA(
                    title: "Estudar selecionados",
                    count: selectedCardsCount(vm: vm),
                    isLoading: false,
                    isCreating: false,
                    theme: .flashcards,
                    action: {
                        FlashcardMultiDeckHandoff.shared.set(Array(selectedDeckIds))
                        if let first = selectedDeckIds.first { onOpenDeck(first) }
                    }
                )
            }
            // Sem selecao nao ha sticky: o hero e o unico CTA primario da tela
            // (havia dois "Estudar agora" competindo — Rafael 2026-07-12).
        }
        .background(Color.clear)
        .sheet(isPresented: $showStudioImport) {
            StudyMaterialPicker(title: "Criar flashcards", actionVerb: "Gerar flashcards") { sourceIds in
                let pack = try await container.api.generateStudyPack(
                    sourceIds: sourceIds, mode: "practice",
                    includeQuestions: false, includeFlashcards: true
                )
                let deckId = pack.flashcardDeckId ?? ""
                return .init(label: "\(pack.counts.flashcards) flashcards criados", open: { onOpenDeck(deckId) })
            }
        }
        .sheet(isPresented: $showSessionSettings) {
            FlashcardSettingsV2Sheet()
        }
        .sheet(isPresented: $showCreateDeck) {
            CreateDeckSheet(
                onCreated: { Task { await vm.refresh() } },
                onCreatedDeck: { deckId, _ in onOpenDeck(deckId) }
            )
        }
        .sheet(isPresented: $showCreateHub) {
            FlashcardCreateHubSheet(
                onCreateDeck: { showCreateDeck = true },
                onExplore: { onExplore() },
                onMagicImport: { showCreateWithVita = true }
            )
        }
        .sheet(isPresented: $showCreateWithVita) {
            CreateWithVitaSheet(
                onPDF: { showStudioImport = true },
                onRecordLecture: { onOpenTranscricao() },
                onAudioFile: { onOpenTranscricao() },
                onPhoto: { captureNotesPhoto() },
                onPaste: { showPasteNotes = true }
            )
        }
        .sheet(isPresented: $showPasteNotes) {
            PasteNotesSheet(onOpenDeck: { deckId in onOpenDeck(deckId) })
        }
        // vita-modals-ignore: câmera é UI de sistema (mesmo padrão do ExamUploadSheet)
        .sheet(isPresented: $showNotesCamera) {
            CameraPickerView { image in handleNotesPhoto(image) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showNotesPhotoLibrary, selection: $notesPhotoItem, matching: .images)
        .onChange(of: notesPhotoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                defer { notesPhotoItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                handleNotesPhoto(image)
            }
        }
        .sheet(item: $notesPhotoUpload) { payload in
            StudyMaterialPicker(
                title: "Fotografar anotações",
                actionVerb: "Gerar flashcards",
                onGenerate: { sourceIds in
                    let pack = try await container.api.generateStudyPack(
                        sourceIds: sourceIds, mode: "practice",
                        includeQuestions: false, includeFlashcards: true
                    )
                    let deckId = pack.flashcardDeckId ?? ""
                    return .init(label: "\(pack.counts.flashcards) flashcards criados", open: { onOpenDeck(deckId) })
                },
                autoUploadFile: payload.file
            )
        }
    }

    /// Câmera quando existe (aparelho); galeria como fallback (simulador/iPad
    /// sem câmera) — o motor é o mesmo (imagem → studio/upload → Vision).
    private func captureNotesPhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showNotesCamera = true
        } else {
            showNotesPhotoLibrary = true
        }
    }

    /// Foto → JPEG (o backend só aceita png/jpeg/webp; HEIC da galeria vira JPEG
    /// aqui) → StudyMaterialPicker em modo auto-upload (reusa progresso/done).
    private func handleNotesPhoto(_ image: UIImage) {
        showNotesCamera = false
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let file = StudyMaterialPicker.AutoUploadFile(
            data: data,
            fileName: "anotacoes-\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg"
        )
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            notesPhotoUpload = NotesPhotoUpload(file: file)
        }
    }

    // MARK: - App bar (titulo + criar + ajustes) — mockup Rafael 2026-07-10

    private var appBar: some View {
        VitaScreenHeader(title: "Baralhos", onBack: onBack) {
            appBarButton(icon: "plus") { showCreateHub = true }
        }
        .padding(.bottom, VitaTokens.Spacing.sm)
    }

    private func appBarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))  // ds-allow: icone da app bar (area de toque)
                .foregroundStyle(icon == "plus" ? VitaColors.surface : VitaColors.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(icon == "plus" ? VitaColors.accent : VitaColors.glassBg)
                )
                .overlay(
                    Circle().stroke(icon == "plus" ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero (N para revisar + ilustracao de cards + Estudar agora)

    private func deckList(vm: FlashcardBuilderViewModel) -> some View {
        let q = deckSearch.trimmingCharacters(in: .whitespaces).lowercased()
        // A Biblioteca vem pela ARVORE (area → disciplina), nao pelos decks: o deck
        // "Medicina" tem 6.391 cards de Reumato+Nefro+Cardio+... e virava UMA linha
        // ("Medicina, 6.391 cartoes") escondendo tudo. Os do aluno seguem por deck —
        // sao dele, com o nome que ele deu.
        let areas = (vm.state.library?.areas ?? []).compactMap { area -> FlashcardLibraryArea? in
            guard !q.isEmpty else { return area }
            let discs = area.disciplines.filter { $0.name.lowercased().contains(q) }
            guard !discs.isEmpty || area.name.lowercased().contains(q) else { return nil }
            var hit = area
            if !area.name.lowercased().contains(q) { hit.disciplines = discs }
            return hit
        }
        let mine = vm.state.decks
            .filter { !($0.userId ?? "").isEmpty }
            .filter { q.isEmpty || cleanDeckTitle($0.title).lowercased().contains(q) }
            .sorted {
                cleanDeckTitle($0.title).localizedCaseInsensitiveCompare(cleanDeckTitle($1.title)) == .orderedAscending
            }

        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            if vm.state.decksLoading && vm.state.library == nil && vm.state.decks.isEmpty {
                groupsSkeleton
            } else if areas.isEmpty && mine.isEmpty {
                deckListEmpty(failed: vm.state.libraryFailed)
            } else {
                if let lib = vm.state.library, !areas.isEmpty {
                    deckSectionHeader("BIBLIOTECA VITA", count: lib.totalCards, unit: "cards")
                    ForEach(areas) { area in
                        libraryAreaBlock(area)
                    }
                }
                if !mine.isEmpty {
                    deckSectionHeader("MEUS BARALHOS", count: mine.count)
                        .padding(.top, areas.isEmpty ? 0 : VitaTokens.Spacing.md)
                    ForEach(mine) { deckRowV2($0) }
                }
            }
        }
    }

    /// Uma área da árvore: rótulo + as disciplinas dela, cada uma com seu ícone
    /// e a contagem real de cards classificados.
    @ViewBuilder
    private func libraryAreaBlock(_ area: FlashcardLibraryArea) -> some View {
        Text(area.name.uppercased())
            .font(VitaTypography.labelSmall)
            .kerning(0.8)
            .foregroundStyle(VitaColors.textTertiary)
            .padding(.horizontal, VitaTokens.Spacing.xs)
            .padding(.top, VitaTokens.Spacing.sm)
        ForEach(area.disciplines) { disc in
            libraryDisciplineRow(disc)
        }
    }

    private func libraryDisciplineRow(_ disc: FlashcardLibraryDiscipline) -> some View {
        Button(action: { openDiscipline(disc) }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                DisciplineIconBadge(name: disc.slug, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(disc.name)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text(disc.due > 0 ? "\(disc.total) cartões · \(disc.due) pra revisar" : "\(disc.total) cartões")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(disc.due > 0 ? VitaColors.accent : VitaColors.textSecondary)
                }
                Spacer()
                if openingDisciplineSlug == disc.slug {
                    // Montar a fila é uma ida ao servidor: sem isto o toque não
                    // dá sinal nenhum e o aluno toca de novo (sessão dupla).
                    ProgressView().tint(VitaColors.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))  // ds-allow: chevron da linha
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.vertical, VitaTokens.Spacing.sm)
            .padding(.horizontal, VitaTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(openingDisciplineSlug != nil)
    }

    /// Pede a fila da disciplina ao servidor e navega pra sessão.
    private func openDiscipline(_ disc: FlashcardLibraryDiscipline) {
        guard let vm, openingDisciplineSlug == nil else { return }
        openingDisciplineSlug = disc.slug
        Task { @MainActor in
            defer { openingDisciplineSlug = nil }
            if let sessionId = await vm.openDiscipline(slug: disc.slug, title: disc.name, due: disc.due) {
                onOpenDisciplineSession(sessionId)
            }
        }
    }

    private func deckSectionHeader(
        _ title: String,
        count: Int,
        unit: String? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(VitaTypography.labelMedium)
                .kerning(1.1)
                .foregroundStyle(VitaColors.sectionLabel)
            Spacer()
            Text(unit.map { "\(count) \($0)" } ?? "\(count)")
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, VitaTokens.Spacing.xs)
        .padding(.bottom, VitaTokens.Spacing.xs)
    }

    private func deckRowV2(_ deck: FlashcardDeckEntry) -> some View {
        Button(action: { onOpenDeck(deck.id) }) {
            HStack(spacing: VitaTokens.Spacing.md) {
                deckIconTile(deck)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cleanDeckTitle(deck.title))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(deck.cardCount) cartões")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer(minLength: VitaTokens.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.vertical, VitaTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Badge redondo da disciplina: glifo semântico sobre círculo com gradiente da
    /// cor da disciplina + highlight especular no topo + glow colorido (profundidade).
    private func deckIconTile(_ deck: FlashcardDeckEntry) -> some View {
        let spec = DisciplineImages.iconSpec(for: deck.disciplineSlug ?? deck.title)
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [spec.color.opacity(0.95), spec.color.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            Image(systemName: spec.symbol)
                .font(.system(size: 21, weight: .semibold))  // ds-allow: glifo do ícone (não é texto)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
        }
        .frame(width: 50, height: 50)
        .shadow(color: spec.color.opacity(0.35), radius: 5, y: 3)
    }

    private func deckListEmpty(failed: Bool) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Image(
                systemName: failed
                    ? "exclamationmark.arrow.triangle.2.circlepath"
                    : (deckSearch.isEmpty ? "books.vertical" : "magnifyingglass")
            )
                .font(.system(size: 30))  // ds-allow: icone empty state
                .foregroundStyle(VitaColors.textTertiary)
            Text(
                failed
                    ? "Não foi possível carregar a biblioteca"
                    : (deckSearch.isEmpty ? "Nenhum baralho por aqui" : "Nada encontrado")
            )
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing._2xl)
    }

    /// Soma de cards dos baralhos marcados (pro CTA "Estudar selecionados").
    private func selectedCardsCount(vm: FlashcardBuilderViewModel) -> Int {
        vm.visibleDecks().filter { selectedDeckIds.contains($0.id) }.reduce(0) { $0 + $1.cardCount }
    }

    /// Limpa ruído do gerador antigo: "Treino: " e " - Flashcards".
    private func cleanDeckTitle(_ raw: String) -> String {
        var t = raw
        if t.hasPrefix("Treino: ") { t = String(t.dropFirst(8)) }
        for suffix in [" - Flashcards", " \u{2014} Flashcards"] {
            if t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { idx in
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
                    if idx < 3 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

}
