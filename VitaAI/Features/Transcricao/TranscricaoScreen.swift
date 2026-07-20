import SwiftUI
import UIKit
import Sentry
import UniformTypeIdentifiers

private func openAppSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}

private struct PermissionBanner: View {
    let message: String
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    Button(action: onOpenSettings) {
                        Text("Abrir Ajustes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(VitaColors.accent.opacity(0.12))
                                    .overlay(Capsule().stroke(VitaColors.accent.opacity(0.25), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)

                    Button("Dispensar", action: onDismiss)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12).fill(VitaColors.accent.opacity(0.06))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.accent.opacity(0.22), lineWidth: 0.5)
        )
    }
}

/// Entry point for Transcrição feature. Owns the ViewModel, routes between phases.
///
/// Sub-screens live in separate files:
///   - TranscricaoShared.swift          (TealColors, TealBackground, StatusBadge, ModeToggle, ProcessingToast, ErrorPhase)
///   - TranscricaoRecorderContent.swift (RecorderArea, DisciplineChips, LiveTranscriptBox, RecordingsList, RecordingCard)
///   - TranscricaoDetailSheet.swift     (DetailSheet, AudioPlayer, PendingContent, TranscribedContent, ActionsMenu, DonePhase, Tabs)
struct TranscricaoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    let onBack: () -> Void
    var onOpenStudyPack: ((String, String) -> Void)? = nil

    @State private var viewModel: TranscricaoViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                TranscricaoContent(
                    viewModel: vm,
                    onBack: onBack,
                    api: container.api,
                    onOpenStudyPack: onOpenStudyPack
                )
            } else {
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear.ignoresSafeArea())
            }
        }
        .task {
            // 2026-04-23: trocado .onAppear por .task — SwiftUI re-dispara
            // .onAppear em múltiplos eventos (sheet dismiss, layout recalc,
            // tab switch), causando 6 chamadas a loadRecordings() por
            // abertura. `.task` dispara 1× por vida da view e cancela no
            // dismiss. Debounce de 2s no ViewModel cobre navigation retornada.
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient, api: container.api, gamificationEvents: container.gamificationEvents)
            }
            async let _ = viewModel?.loadRecordings()
            async let _ = viewModel?.loadFolders()
            // Garante o catálogo canônico de disciplinas (fonte da caixa de
            // opções) mesmo se o aluno abrir a transcrição direto. Guardado
            // por dentro — não recarrega se já veio no load do app.
            async let _ = appData.loadIfNeeded()
            SentrySDK.reportFullyDisplayed()
        }
        .onDisappear {
            // If the user is still recording, stop capture so the mic is
            // released; but NEVER reset the processing pipeline — upload /
            // transcribe / summary runs server-side and the list refresh on
            // re-enter will show the result. Calling reset() here was the
            // root cause of "ficou transcrevendo pra sempre".
            if viewModel?.phase == .recording {
                viewModel?.stopRecording()
            }
        }
        .trackScreen("Transcricao")
    }
}

// MARK: - Content

private struct TranscricaoFolderEditorRequest: Identifiable {
    let id = UUID()
    let folder: VitaAPI.StudioFolder?

    var title: String { folder == nil ? "Nova pasta" : "Editar pasta" }
}

@MainActor
private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void
    let api: VitaAPI
    var onOpenStudyPack: ((String, String) -> Void)? = nil

    @Environment(\.appData) private var appData
    @State private var selectedMode: TranscricaoRecordingMode = .offline
    // `selectedDiscipline` lives on the ViewModel so it flows into the upload
    // payload (R2 metadata + backend) without a second piece of state.
    @State private var selectedFilter: String? = nil
    @State private var selectedRecording: TranscricaoEntry? = nil
    /// Estado interno da biblioteca: visão geral, favoritas ou pasta expandida.
    @State private var listView: TranscricaoListView = .library
    @State private var folderEditor: TranscricaoFolderEditorRequest? = nil
    /// Toast visual (appear + auto-dismiss) pra quick-actions (gerar, favoritar).
    /// Sem Sheets/Alerts — UX pattern Instagram/WhatsApp.
    @State private var toastMessage: String? = nil
    // O seletor de arquivo da Apple É a UI do importar — sem tela nossa no meio.
    @State private var showFileImporter = false

    /// Disciplinas do aluno — fonte canônica ÚNICA (`/api/subjects` via
    /// `AppDataManager.canonicalDisciplines`, já ordenada). Sem mesclar
    /// `gradesResponse` nem deduplicar no cliente: o backend unifica portal +
    /// manuais e é a única verdade (Rafael 2026-07-02).
    private var disciplines: [String] {
        appData.canonicalDisciplines.map(\.preferredName)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VitaScreenHeader(title: "Transcrição", onBack: onBack)

                switch viewModel.phase {
                case .error:
                    TranscricaoErrorPhase(
                        message: viewModel.errorMessage ?? "Erro desconhecido",
                        onRetry: { viewModel.reset() }
                    )

                default:
                    // idle, recording, paused — tudo mostra a mesma lista. O
                    // pipeline cloud roda 100% em background, sem toast no
                    // topo. Cards da lista (locais) carregam o spinner de
                    // "transcrevendo" via `cloudStatus`.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Banner de permissão negada — sutil, com CTA de
                            // "Abrir Ajustes". Só aparece quando user negou
                            // mic/speech na primeira vez. Some ao conceder.
                            if let banner = viewModel.permissionBanner {
                                PermissionBanner(
                                    message: banner,
                                    onOpenSettings: openAppSettings,
                                    onDismiss: { viewModel.permissionBanner = nil }
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // Recorder card (mode toggle + recorder area)
                            VStack(spacing: 10) {
                                TranscricaoModeToggle(selected: $selectedMode)
                                    .disabled(viewModel.phase == .recording)

                                TranscricaoRecorderArea(
                                    elapsedSeconds: (viewModel.phase == .recording || viewModel.phase == .paused) ? viewModel.elapsedSeconds : 0,
                                    isRecording: viewModel.phase == .recording,
                                    isPaused: viewModel.phase == .paused,
                                    audioLevels: viewModel.audioLevels,
                                    selectedDiscipline: Binding(
                                        get: { viewModel.selectedDiscipline },
                                        set: { viewModel.selectedDiscipline = $0 }
                                    ),
                                    selectedLanguage: Binding(
                                        get: { viewModel.selectedLanguage },
                                        set: { viewModel.selectedLanguage = $0 }
                                    ),
                                    transcribeWithAI: Binding(
                                        get: { viewModel.transcribeWithAI },
                                        set: { viewModel.transcribeWithAI = $0 }
                                    ),
                                    onToggle: {
                                        if viewModel.phase == .recording || viewModel.phase == .paused {
                                            viewModel.stopRecording()
                                        } else {
                                            Task { await viewModel.startRecording() }
                                        }
                                    },
                                    onPauseResume: {
                                        if viewModel.phase == .recording {
                                            viewModel.pauseRecording()
                                        } else if viewModel.phase == .paused {
                                            viewModel.resumeRecording()
                                        }
                                    },
                                    onDiscard: {
                                        viewModel.discardRecording()
                                    },
                                    onImportAudio: {
                                        showFileImporter = true
                                    }
                                )
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 16)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                            // (Chip Cloud/Só local foi pra dentro do recorder card
                            //  como 3º botão abaixo do idioma — Rafael pediu a
                            //  reorganização em 2026-04-24.)

                            // Live transcript — SEMPRE aparece em modo "Ao Vivo"
                            // enquanto gravando (mesmo vazio, com placeholder
                            // "Ouvindo…"). Antes só aparecia quando já tinha
                            // texto — user ficava sem feedback visual achando
                            // que o modo live não funcionava. Usa on-device
                            // SFSpeechRecognizer, zero rede.
                            if viewModel.phase == .recording && selectedMode == .live {
                                TranscricaoLiveTranscriptBox(text: viewModel.liveTranscript)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .transition(.opacity)
                            }

                            // Rascunhos locais + uploads em background — cada
                            // card mostra cloudStatus ("Enviando", "Transcrevendo",
                            // "Resumindo…") via spinner/badge. Quando ready,
                            // entry migra pra lista cloud automaticamente.
                            if !viewModel.localRecordings.isEmpty {
                                TranscricaoLocalDraftsSection(
                                    drafts: viewModel.localRecordings,
                                    onTranscribe: { draft in
                                        Task { await viewModel.promoteLocalToCloud(id: draft.id) }
                                    },
                                    onDelete: { draft in
                                        withAnimation { viewModel.deleteLocalRecording(id: draft.id) }
                                    }
                                )
                                .padding(.top, 10)
                            }

                            // Recordings list (cloud)
                            TranscricaoRecordingsListSection(
                                recordings: viewModel.recordings,
                                isLoading: viewModel.recordingsLoading,
                                selectedFilter: $selectedFilter,
                                filterChips: disciplines,
                                listView: $listView,
                                folders: viewModel.folders,
                                onCreateFolder: {
                                    folderEditor = TranscricaoFolderEditorRequest(folder: nil)
                                },
                                onTap: { rec in selectedRecording = rec },
                                onDelete: { rec in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation {
                                        viewModel.removeRecordingLocally(id: rec.id)
                                    }
                                    Task {
                                        do {
                                            try await api.deleteStudioSource(id: rec.id)
                                        } catch {
                                            NSLog("[Transcricao] DELETE failed for %@: %@", rec.id, error.localizedDescription)
                                            await MainActor.run { showToast("Falha ao apagar — recarregando") }
                                            await viewModel.loadRecordings(force: true)
                                        }
                                    }
                                },
                                onGenerate: { rec, type in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    let typeLabel: String = {
                                        switch type {
                                        case "summary": return "resumo"
                                        case "flashcards": return "flashcards"
                                        case "questions": return "questões"
                                        case "concepts": return "conceitos-chave"
                                        case "mindmap": return "mindmap"
                                        default: return type
                                        }
                                    }()
                                    showToast("Gerando \(typeLabel)…")
                                    Task {
                                        do {
                                            _ = try await api.generateStudioOutput(
                                                sourceId: rec.id,
                                                outputType: type
                                            )
                                            await viewModel.loadRecordings(force: true)
                                            await MainActor.run { showToast("✓ \(typeLabel.capitalized) pronto") }
                                        } catch {
                                            NSLog("[Transcricao] onGenerate error: %@", error.localizedDescription)
                                            await MainActor.run { showToast("Falha ao gerar \(typeLabel)") }
                                        }
                                    }
                                },
                                onFavorite: { rec in
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    let willBeFavorite = !(rec.favorite ?? false)
                                    showToast(willBeFavorite ? "⭐ Favoritado" : "Removido dos favoritos")
                                    viewModel.toggleFavoriteOnRecording(id: rec.id)
                                },
                                onRename: { rec, newTitle in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.renameRecording(id: rec.id, newTitle: newTitle)
                                    showToast("✓ Renomeado")
                                },
                                onMove: { rec, folderID, disciplineSlug in
                                    let destination = folderID.flatMap { targetID in
                                        viewModel.folders.first(where: { $0.id == targetID })?.name
                                    } ?? disciplineSlug ?? "Gravações"
                                    Task {
                                        let moved = await viewModel.moveRecording(
                                            id: rec.id,
                                            folderId: folderID,
                                            disciplineSlug: disciplineSlug
                                        )
                                        await MainActor.run {
                                            if moved {
                                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                showToast("✓ Movido para \(destination)")
                                            } else {
                                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                showToast("Falha ao mover gravação")
                                            }
                                        }
                                    }
                                },
                                onEditFolder: { folder in
                                    folderEditor = TranscricaoFolderEditorRequest(folder: folder)
                                },
                                onDeleteFolder: { folder in
                                    if listView == .folder(id: folder.id) { listView = .library }
                                    Task {
                                        let deleted = await viewModel.deleteFolder(id: folder.id)
                                        await MainActor.run {
                                            showToast(deleted ? "✓ Pasta excluída" : "Falha ao excluir pasta")
                                        }
                                    }
                                }
                            )
                            .padding(.top, VitaTokens.Spacing.lg)
                        }
                        .padding(.bottom, 120)
                    }
                    .refreshable { await viewModel.loadRecordings(force: true) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Importar áudio de fora. `.audio` cobre m4a/mp3/wav/aac; o ViewModel
        // converte pra m4a quando precisa e reusa o mesmo envio da gravação.
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await viewModel.importAudio(from: url) }
            case .failure(let error):
                toastMessage = "Não foi possível abrir o arquivo: \(error.localizedDescription)"
            }
        }
        // Detail sheet when tapping a recording.
        // presentationDetents fixado em .large: precisa mostrar TODAS as ações
        // (gerar resumo/flashcards/questões/conceitos/mindmap) sem scroll
        // escondendo opções. drag indicator visível pra user saber que é sheet.
        .sheet(item: $selectedRecording) { rec in
            VitaSheet(detents: [.large]) {
                TranscricaoDetailSheet(
                    recording: rec,
                    onRenamed: { newTitle in
                        Task { await viewModel.loadRecordings(force: true) }
                        _ = newTitle
                    },
                    onDeleted: {
                        withAnimation { viewModel.removeRecordingLocally(id: rec.id) }
                    },
                    onStudyPackCreated: { sessionId, mode in
                        selectedRecording = nil
                        onOpenStudyPack?(sessionId, mode)
                    }
                )
            }
        }
        .sheet(item: $folderEditor) { request in
            VitaSheet(title: request.title, detents: [.medium, .large]) {
                TranscricaoFolderEditorSheet(
                    folder: request.folder,
                    subjects: appData.canonicalDisciplines,
                    onCancel: { folderEditor = nil },
                    onSave: { name, subjectId in
                        folderEditor = nil
                        saveFolder(request: request, name: name, subjectId: subjectId)
                    }
                )
            }
        }
        // Auto-abre sheet quando transcrição acabou de processar (ready).
        // UX pattern Otter/Airgram: "sua gravação tá pronta — toca o que quer
        // fazer". Evita o user ter que caçar a gravação na lista pra abrir.
        .onChange(of: viewModel.justCompletedRecordingId) { _, newId in
            guard let newId else { return }
            if let rec = viewModel.recordings.first(where: { $0.id == newId }) {
                selectedRecording = rec
                viewModel.justCompletedRecordingId = nil
            }
        }
        // Toast overlay — feedback visual de quick-actions (gerar, favoritar).
        .overlay(alignment: .top) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.4), lineWidth: 0.6))
                    )
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        // Disciplinas vêm do catálogo canônico (appData.canonicalDisciplines,
        // = /api/subjects). Fonte única — sem chamada extra nem merge local.
    }

    private func saveFolder(
        request: TranscricaoFolderEditorRequest,
        name: String,
        subjectId: String?
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            if let folder = request.folder {
                guard trimmed != folder.name else { return }
                let renamed = await viewModel.renameFolder(id: folder.id, name: trimmed)
                showToast(renamed ? "✓ Pasta renomeada" : "Falha ao renomear pasta")
                return
            }

            if let subjectId {
                // O backend mantém uma pasta canônica por disciplina. Atrelar
                // usa essa pasta em vez de criar uma duplicata concorrente.
                guard let subjectFolder = viewModel.folders.first(where: { $0.subjectId == subjectId }) else {
                    showToast("Não foi possível vincular essa disciplina")
                    await viewModel.loadFolders()
                    return
                }
                let renamed: Bool
                if subjectFolder.name == trimmed {
                    renamed = true
                } else {
                    renamed = await viewModel.renameFolder(id: subjectFolder.id, name: trimmed)
                }
                if renamed {
                    listView = .folder(id: subjectFolder.id)
                    showToast("✓ Pasta vinculada à disciplina")
                } else {
                    showToast("Falha ao salvar pasta")
                }
                return
            }

            if let folder = await viewModel.createFolder(name: trimmed) {
                listView = .folder(id: folder.id)
                showToast("✓ Pasta criada")
            } else {
                showToast("Falha ao criar pasta")
            }
        }
    }

    /// Mostra toast por 1.8s. Chamar via MainActor.run se vier de Task background.
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) {
                toastMessage = nil
            }
        }
    }
}

private struct TranscricaoFolderEditorSheet: View {
    let folder: VitaAPI.StudioFolder?
    let subjects: [AcademicSubject]
    let onCancel: () -> Void
    let onSave: (String, String?) -> Void

    @State private var name: String
    @State private var selectedSubjectId: String?
    @FocusState private var nameFocused: Bool

    init(
        folder: VitaAPI.StudioFolder?,
        subjects: [AcademicSubject],
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String?) -> Void
    ) {
        self.folder = folder
        self.subjects = subjects
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: folder?.name ?? "")
        _selectedSubjectId = State(initialValue: folder?.subjectId)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var linkedSubjectName: String? {
        guard let selectedSubjectId else { return folder?.subjectName }
        return subjects.first(where: { $0.id == selectedSubjectId })?.preferredName ?? folder?.subjectName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            fieldSection

            if folder == nil {
                disciplineSection
            } else {
                folderContext
            }

            Spacer(minLength: VitaTokens.Spacing.sm)

            HStack(spacing: VitaTokens.Spacing.sm) {
                VitaButton(
                    text: "Cancelar",
                    action: onCancel,
                    variant: .ghost,
                    size: .md
                )
                Spacer(minLength: 0)
                VitaButton(
                    text: folder == nil ? "Criar pasta" : "Salvar",
                    action: { onSave(trimmedName, folder == nil ? selectedSubjectId : folder?.subjectId) },
                    variant: .primary,
                    size: .md,
                    isEnabled: !trimmedName.isEmpty,
                    leadingSystemImage: folder == nil ? "folder.badge.plus" : "checkmark"
                )
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.bottom, VitaTokens.Spacing.xl)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                nameFocused = true
            }
        }
    }

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            sectionLabel("NOME")

            TextField("Nome da pasta", text: $name)
                .font(VitaTypography.bodyLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                        .fill(VitaColors.glassBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                        .stroke(nameFocused ? VitaColors.accent.opacity(0.45) : VitaColors.glassBorder, lineWidth: 0.75)
                )
        }
    }

    private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            sectionLabel("DISCIPLINA · OPCIONAL")

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    disciplineRow(id: nil, title: "Sem disciplina", icon: "folder")

                    ForEach(subjects) { subject in
                        Divider()
                            .overlay(VitaColors.glassBorder)
                            .padding(.leading, 48)
                        disciplineRow(
                            id: subject.id,
                            title: subject.preferredName,
                            icon: "book.closed"
                        )
                    }
                }
            }
            .frame(maxHeight: 230)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .fill(VitaColors.glassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .stroke(VitaColors.glassBorder, lineWidth: 0.5)
            )

            Text("Ao escolher uma disciplina, o Vita usa a pasta acadêmica já vinculada a ela.")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var folderContext: some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: linkedSubjectName == nil ? "folder" : "book.closed")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(VitaColors.accent.opacity(0.10)))

            VStack(alignment: .leading, spacing: 1) {
                sectionLabel(linkedSubjectName == nil ? "PASTA PERSONALIZADA" : "DISCIPLINA VINCULADA")
                Text(linkedSubjectName ?? "Sem disciplina")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(VitaColors.glassBorder, lineWidth: 0.5)
        )
    }

    private func disciplineRow(id: String?, title: String, icon: String) -> some View {
        let selected = selectedSubjectId == id
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            selectedSubjectId = id
            if id != nil, trimmedName.isEmpty {
                name = title
            }
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(selected ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(VitaTypography.labelSmall)
            .fontWeight(.semibold)
            .kerning(0.8)
            .foregroundStyle(VitaColors.sectionLabel)
    }
}
