import SwiftUI

// MARK: - Recorder Area (timer + waveform + discipline/language pickers + record button)

struct TranscricaoRecorderArea: View {
    let elapsedSeconds: Int
    let isRecording: Bool
    let isPaused: Bool
    let audioLevels: [Float]
    @Binding var selectedDiscipline: String
    @Binding var selectedLanguage: String
    @Binding var transcribeWithAI: Bool
    let onToggle: () -> Void
    let onPauseResume: () -> Void
    let onDiscard: () -> Void
    /// Importar áudio existente (m4a/mp3/wav) — abre fileImporter da Apple.
    /// Sem popout: o picker da Apple É a UI. Por isso o chip não tem chevron.down.
    let onImportAudio: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDiscardConfirm = false

    private var recorderButtonWidth: CGFloat {
        horizontalSizeClass == .regular ? 200 : 155
    }

    private var isActive: Bool { isRecording || isPaused }

    var body: some View {
        VStack(spacing: 12) {
            // Timer gigante centralizado; caixa de ferramentas + Importar
            // ancorados à direita, na altura do cronômetro (Rafael 2026-07-01:
            // consolida Disciplina/Idioma/Modo numa caixa só — área limpa).
            ZStack {
                Text(formatTranscricaoElapsed(elapsedSeconds))
                    .font(.system(size: 54, weight: .bold, design: .default))
                    .tracking(-2)
                    .monospacedDigit()
                    .foregroundStyle(
                        isRecording
                            ? VitaColors.accentLight.opacity(0.95)
                            : Color.white.opacity(0.22)
                    )
                    .shadow(color: isRecording ? VitaColors.accent.opacity(0.4) : .clear, radius: 32)

                HStack(spacing: 8) {
                    Spacer()
                    TranscricaoToolbox(
                        selectedDiscipline: $selectedDiscipline,
                        selectedLanguage: $selectedLanguage,
                        transcribeWithAI: $transcribeWithAI,
                        disabled: isRecording
                    )
                    TranscricaoImportButton(disabled: isRecording, onImport: onImportAudio)
                }
                .padding(.trailing, 4)
            }

            // Status label secundário — só aparece enquanto gravando/pausado
            // (quando .idle o "Toque para gravar" do orb já cobre o estado).
            if isActive {
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                    .transition(.opacity)
            }

            // Orb/mascote CENTRAL como botão principal. Label "Toque para
            // gravar / parar" mais forte abaixo, sem duplicar o statusLabel.
            Button(action: onToggle) {
                VStack(spacing: 10) {
                    VitaTypingMascot(isRecording: isActive, size: recorderButtonWidth)

                    Text(mascotLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isActive
                                ? VitaColors.accentLight.opacity(0.85)
                                : Color.white.opacity(0.55)
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "Parar gravação" : "Iniciar gravação")

            // Waveform ao vivo — só aparece quando gravando.
            if isRecording || isPaused {
                LiveWaveformBars(levels: audioLevels, isActive: isRecording)
                    .frame(height: 36)
                    .transition(.opacity)
            }

            // Descartar + Pause/Resume + Stop enquanto gravando/pausado.
            // Padrão gold Otter/Voice Memos: trash icon separado pra abortar
            // sem salvar, stop principal pra finalizar, pause secundário.
            if isActive {
                HStack(spacing: 8) {
                    // Descartar — trash vermelho sutil, confirmation dialog.
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.90))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.12))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.32), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Descartar gravação")

                    TranscricaoPauseResumeButton(isPaused: isPaused, onTap: onPauseResume)

                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Parar")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(VitaColors.accentHover.opacity(0.90))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [VitaColors.accent.opacity(0.18), VitaColors.accent.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .vitaAlert(
                    isPresented: $showDiscardConfirm,
                    title: "Descartar gravação?",
                    message: "O áudio será deletado. Não dá pra desfazer.",
                    destructiveLabel: "Descartar",
                    cancelLabel: "Continuar gravando",
                    onConfirm: { onDiscard() }
                )
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var statusLabel: String {
        if isPaused { return "Pausado" }
        if isRecording { return "Gravando…" }
        return "Pronto para gravar"
    }

    private var mascotLabel: String {
        if isPaused { return "Toque para parar" }
        if isRecording { return "Toque para parar" }
        return "Toque para gravar"
    }
}

// MARK: - Toolbox (caixa de ferramentas: Disciplina + Idioma + Modo)
//
// Rafael 2026-07-01: consolida os 3 controles que antes eram chips soltos
// abaixo do gravador numa caixa única, ancorada à direita do cronômetro.
// Menu nativo (robusto/clean) — o botão usa o vocabulário visual dourado
// dos chips antigos (cápsula vidro + stroke accent).

struct TranscricaoToolbox: View {
    @Binding var selectedDiscipline: String
    @Binding var selectedLanguage: String
    @Binding var transcribeWithAI: Bool
    let disabled: Bool

    @State private var showSheet = false

    private var disciplineLabel: String {
        selectedDiscipline.isEmpty ? "Auto" : selectedDiscipline
    }
    private var languageLabel: String {
        (TranscricaoLanguagePicker.all.first { $0.code == selectedLanguage } ?? TranscricaoLanguagePicker.all[0]).label
    }

    var body: some View {
        // Botão-caixa (dourado, cápsula-vidro igual aos antigos chips).
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showSheet = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .overlay(Circle().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Opções da gravação")
        .sheet(isPresented: $showSheet) {
            PixioSettingsScaffold(title: "Opções da gravação") {
                PixioSettingsSection {
                    NavigationLink {
                        TranscricaoDisciplinaPicker(selected: $selectedDiscipline)
                    } label: {
                        navRow(icon: "book.closed.fill", label: "Disciplina", value: disciplineLabel)
                    }
                    .buttonStyle(.plain)
                    PixioSettingsDivider()
                    menuRow(icon: "globe", label: "Idioma", value: languageLabel) {
                        ForEach(TranscricaoLanguagePicker.all) { lang in
                            Button { selectedLanguage = lang.code } label: {
                                if selectedLanguage == lang.code {
                                    Label("\(lang.flag) \(lang.label)", systemImage: "checkmark")
                                } else {
                                    Text("\(lang.flag) \(lang.label)")
                                }
                            }
                        }
                    }
                    PixioSettingsDivider()
                    menuRow(icon: transcribeWithAI ? "cloud.fill" : "iphone", label: "Transcrição", value: transcribeWithAI ? "Cloud" : "Local") {
                        Button { transcribeWithAI = true } label: {
                            Label("VITACloud", systemImage: transcribeWithAI ? "checkmark" : "cloud.fill")
                        }
                        Button { transcribeWithAI = false } label: {
                            Label("Só no dispositivo", systemImage: !transcribeWithAI ? "checkmark" : "iphone")
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // Linha canon: ícone-tile + nome à esquerda; cápsula-menu dourada com o
    // valor à direita (padrão dos Ajustes — "cada opção é o seu próprio menu").
    @ViewBuilder
    private func menuRow<Menu: View>(icon: String, label: String, value: String, @ViewBuilder content: () -> Menu) -> some View {
        HStack(spacing: 14) {
            PixioSettingsIcon(icon: icon)
            Text(label)
                .font(PixioTypo.geist(size: 15, weight: .regular))
                .foregroundStyle(PixioColor.textLight)
            Spacer(minLength: 8)
            SwiftUI.Menu {
                content()
            } label: {
                HStack(spacing: 5) {
                    Text(value)
                        .font(PixioTypo.geist(size: 14, weight: .regular))
                        .foregroundStyle(VitaColors.accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(VitaColors.accent.opacity(0.08)))
            }
        }
        .padding(.vertical, 6)
    }

    // Linha de navegação (empurra sub-tela): ícone-tile + nome + valor +
    // chevron.right. Usada pela Disciplina (que abre busca + lista).
    @ViewBuilder
    private func navRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            PixioSettingsIcon(icon: icon)
            Text(label)
                .font(PixioTypo.geist(size: 15, weight: .regular))
                .foregroundStyle(PixioColor.textLight)
            Spacer(minLength: 8)
            Text(value)
                .font(PixioTypo.geist(size: 14, weight: .regular))
                .foregroundStyle(PixioColor.textLightMuted)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PixioColor.textLightFaint)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Disciplina Picker (sub-tela: auto-detectar + busca + lista canônica)
//
// Rafael 2026-07-02: fonte ÚNICA = catálogo do aluno em `/api/subjects`, lido
// via `AppDataManager.canonicalDisciplines` (o backend é quem decide a lista —
// "1 cérebro", igual regra MCP=app do Pixio). Sem mesclar `gradesResponse` nem
// deduplicar aqui. Auto-detectar (padrão) + campo de busca + lista alfabética.
// Digitar algo novo ADICIONA de verdade (POST /api/subjects); "Gerenciar"
// remove de verdade (DELETE /api/subjects/{id}, soft-delete).

struct TranscricaoDisciplinaPicker: View {
    @Binding var selected: String

    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var busy = false
    @State private var editing = false
    @State private var pendingRemoval: AcademicSubject? = nil

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    /// Catálogo canônico já pronto e ordenado (fonte única).
    private var all: [AcademicSubject] { appData.canonicalDisciplines }

    private var filtered: [AcademicSubject] {
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.preferredName.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Oferece criar quando o texto não bate exatamente com nenhuma existente.
    private var showCreate: Bool {
        !trimmed.isEmpty && !all.contains {
            $0.preferredName.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    var body: some View {
        PixioSettingsScaffold(title: "Disciplina") {
            PixioSearchField(text: $query, placeholder: "Buscar ou adicionar")

            // Auto-detectar (padrão) — escondido no modo Gerenciar.
            if !editing {
                PixioSettingsSection {
                    PixioSettingsRow(
                        icon: "sparkles",
                        accent: VitaColors.accent,
                        title: "Auto-detectar",
                        value: selected.isEmpty ? "Padrão" : nil,
                        verified: selected.isEmpty,
                        showChevron: false,
                        action: { selected = ""; dismiss() }
                    )
                }
            }

            // Adicionar disciplina nova a partir do que foi digitado.
            if showCreate && !editing {
                PixioSettingsSection {
                    PixioSettingsRow(
                        icon: "plus.circle.fill",
                        accent: VitaColors.accent,
                        title: "Adicionar \u{201C}\(trimmed)\u{201D}",
                        showChevron: false,
                        action: { addDiscipline(trimmed) }
                    )
                }
            }

            if !filtered.isEmpty {
                PixioSettingsSection(
                    trimmed.isEmpty ? "Minhas disciplinas" : nil,
                    addLabel: editing ? "Concluir" : "Gerenciar",
                    onAdd: { withAnimation { editing.toggle() } }
                ) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, subject in
                        PixioSettingsRow(
                            icon: editing ? "minus.circle.fill" : "book.closed.fill",
                            accent: VitaColors.accent,
                            title: subject.preferredName,
                            verified: !editing && selected == subject.preferredName,
                            showChevron: false,
                            destructive: editing,
                            action: {
                                if editing {
                                    pendingRemoval = subject
                                } else {
                                    selected = subject.preferredName
                                    dismiss()
                                }
                            }
                        )
                        if idx < filtered.count - 1 { PixioSettingsDivider() }
                    }
                }
            } else if !showCreate {
                emptyState
            }
        }
        .disabled(busy)
        .confirmationDialog(
            "Remover \(pendingRemoval?.preferredName ?? "")?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remover", role: .destructive) {
                if let subject = pendingRemoval { removeDiscipline(subject) }
            }
            Button("Cancelar", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Sai da sua lista de disciplinas. As gravações já feitas não são apagadas.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "books.vertical")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(PixioColor.textLightFaint)
                .padding(.bottom, 2)
            Text("Nenhuma disciplina ainda")
                .font(PixioTypo.geist(size: 15, weight: .regular))
                .foregroundStyle(PixioColor.textLight)
            Text("Digite acima para adicionar, ou sincronize suas matérias na Faculdade.")
                .font(PixioTypo.geist(size: 13, weight: .regular))
                .foregroundStyle(PixioColor.textLightMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 8)
    }

    private func addDiscipline(_ name: String) {
        busy = true
        Task {
            defer { busy = false }
            do {
                let created = try await appData.addManualDiscipline(name: name)
                selected = created.preferredName
                query = ""
                dismiss()
            } catch {
                NSLog("[disciplina] adicionar falhou: \(error)")
            }
        }
    }

    private func removeDiscipline(_ subject: AcademicSubject) {
        busy = true
        Task {
            defer { busy = false }
            if selected == subject.preferredName { selected = "" }
            try? await appData.removeDiscipline(id: subject.id)
        }
    }
}

// MARK: - Import Button (ao lado da caixa de ferramentas)

struct TranscricaoImportButton: View {
    let disabled: Bool
    let onImport: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onImport()
        }) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .overlay(Circle().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Importar áudio")
    }
}

// MARK: - Live Waveform Bars
//
// Reads the ViewModel's audioLevels (length = TranscricaoViewModel.waveformBarCount)
// and renders real-time bars. When idle/paused, bars drop to a subtle baseline.

struct LiveWaveformBars: View {
    let levels: [Float]
    let isActive: Bool

    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                let h: CGFloat = isActive
                    ? max(minHeight, minHeight + CGFloat(level) * (maxHeight - minHeight))
                    : minHeight + 2
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isActive
                            ? LinearGradient(
                                colors: [VitaColors.accent.opacity(0.55), VitaColors.accentLight.opacity(0.90)],
                                startPoint: .bottom, endPoint: .top
                              )
                            : LinearGradient(
                                colors: [VitaColors.accent.opacity(0.10)],
                                startPoint: .bottom, endPoint: .top
                              )
                    )
                    .frame(width: 2.5, height: h)
                    .animation(.easeOut(duration: 0.12), value: h)
            }
        }
    }
}

// MARK: - (legacy discipline chips — kept for recordings list filter, renamed)

private struct LegacyChips: View {
    let disciplines: [String]
    @Binding var selected: String
    let disabled: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(disciplines, id: \.self) { disc in
                    let isSelected = selected == disc
                    Button {
                        if !disabled {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selected = disc
                            }
                        }
                    } label: {
                        Text(disc)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(
                                isSelected
                                    ? VitaColors.accentHover.opacity(0.90)
                                    : VitaColors.textWarm.opacity(0.35)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.10)
                                            : Color.white.opacity(0.04)
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.30)
                                            : VitaColors.accent.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(disabled ? 0.5 : 1.0)
                }
            }
        }
    }
}

// MARK: - Live Transcript Box

struct TranscricaoLiveTranscriptBox: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(VitaColors.accent.opacity(0.20)).frame(width: 10, height: 10)
                    Circle().fill(VitaColors.accent).frame(width: 6, height: 6)
                        .opacity(0.85)
                }
                Text("AO VIVO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(VitaColors.accentLight)
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                if text.isEmpty {
                    Text("Ouvindo… fale algo.")
                        .font(.system(size: 12, weight: .medium))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(14)
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

// MARK: - List view mode (chips: Todas / Favoritas / Pastas)

/// Sub-view filter aplicado pelas chips horizontais no header. Combina
/// com `selectedFilter` (disciplina, do filtro avançado) — ambos têm que
/// passar pra gravação aparecer.
enum TranscricaoListView: Equatable {
    case all
    case favorites
    case folder(id: String)
}

// MARK: - Recordings List Section (data from API)

struct TranscricaoRecordingsListSection: View {
    let recordings: [TranscricaoEntry]
    let isLoading: Bool
    @Binding var selectedFilter: String?
    let filterChips: [String]
    @Binding var listView: TranscricaoListView
    let folders: [VitaAPI.StudioFolder]
    let onCreateFolder: () -> Void
    let onTap: (TranscricaoEntry) -> Void
    let onDelete: (TranscricaoEntry) -> Void
    /// Context menu action: dispara geração direto (summary, flashcards, questions,
    /// concepts, mindmap). Sem precisar abrir sheet + tab de ações.
    var onGenerate: ((TranscricaoEntry, String) -> Void)? = nil
    /// Swipe right quick-action: favorita gravação.
    var onFavorite: ((TranscricaoEntry) -> Void)? = nil
    /// Long press → renomear. Abre alert inline sem precisar entrar no detail.
    var onRename: ((TranscricaoEntry, String) -> Void)? = nil
    /// Renomear pasta (long-press → "Renomear"). Backend: PATCH /api/studio/folders/:id
    var onRenameFolder: ((VitaAPI.StudioFolder, String) -> Void)? = nil
    /// Excluir pasta (long-press → "Excluir"). Gravações dentro vão pra "Sem pasta".
    /// Backend: DELETE /api/studio/folders/:id
    var onDeleteFolder: ((VitaAPI.StudioFolder) -> Void)? = nil
    /// Compartilhar pasta — abre share sheet com texto resumindo gravações.
    var onShareFolder: ((VitaAPI.StudioFolder) -> Void)? = nil

    @State private var renamingRec: TranscricaoEntry? = nil
    @State private var renameValue: String = ""
    @State private var renamingFolder: VitaAPI.StudioFolder? = nil
    @State private var renameFolderValue: String = ""
    @State private var deletingFolder: VitaAPI.StudioFolder? = nil

    private func normalizedFolderKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private func subjectValue(_ value: String, matches candidates: [String]) -> Bool {
        let valueKey = normalizedFolderKey(value)
        guard !valueKey.isEmpty else { return false }
        return candidates.contains { candidate in
            let candidateKey = normalizedFolderKey(candidate)
            guard !candidateKey.isEmpty else { return false }
            return valueKey == candidateKey ||
                (min(valueKey.count, candidateKey.count) >= 5 &&
                    (valueKey.hasPrefix(candidateKey) || candidateKey.hasPrefix(valueKey)))
        }
    }

    private func recordings(in folder: VitaAPI.StudioFolder) -> [TranscricaoEntry] {
        recordings.filter { recording in
            if recording.folderId == folder.id { return true }
            guard folder.isSubjectFolder, let discipline = recording.discipline else { return false }
            return subjectValue(
                discipline,
                matches: [
                    folder.name,
                    folder.subjectName ?? "",
                    folder.disciplineSlug ?? "",
                    folder.subjectKey ?? "",
                ]
            )
        }
    }

    private func applyingDisciplineFilter(to items: [TranscricaoEntry]) -> [TranscricaoEntry] {
        guard let filter = selectedFilter else { return items }
        return items.filter { subjectValue($0.discipline ?? "", matches: [filter]) }
    }

    private var filteredRecordings: [TranscricaoEntry] {
        var items = recordings
        // Step 1 — view principal (Todas / Favoritas / pasta expandida).
        switch listView {
        case .all:
            break
        case .favorites:
            items = items.filter { $0.favorite == true }
        case .folder(let id):
            if let folder = folders.first(where: { $0.id == id }) {
                items = recordings(in: folder)
            } else {
                items = []
            }
        }
        return applyingDisciplineFilter(to: items)
    }

    // Group recordings by date bucket.
    private func groupedRecordings(for items: [TranscricaoEntry]) -> [(key: String, recordings: [TranscricaoEntry])] {
        let cal = Calendar.current
        let now = Date()

        var today: [TranscricaoEntry] = []
        var thisWeek: [TranscricaoEntry] = []
        var older: [TranscricaoEntry] = []

        for rec in items {
            let date = rec.parsedDate ?? .distantPast
            if cal.isDateInToday(date) {
                today.append(rec)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                thisWeek.append(rec)
            } else {
                older.append(rec)
            }
        }

        var result: [(key: String, recordings: [TranscricaoEntry])] = []
        if !today.isEmpty { result.append(("Hoje", today)) }
        if !thisWeek.isEmpty { result.append(("Esta semana", thisWeek)) }
        if !older.isEmpty { result.append(("Anteriores", older)) }
        return result
    }

    @State private var showFilterSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: "GRAVAÇÕES · N" + botão filtro à direita (padrão Apple
            // Mail/Notes). Quando filtro ativo, mostra pill removível.
            HStack(spacing: 6) {
                Text("GRAVAÇÕES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .tracking(0.5)

                if !recordings.isEmpty {
                    // Mostra count do filtro ativo (não total absoluto), pra
                    // chip "Favoritas" mostrar 0 quando não tem favoritas etc.
                    Text("· \(filteredRecordings.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .tracking(0.5)
                }

                Spacer()

                // Pill removível mostrando filtro ativo.
                if let active = selectedFilter {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 9, weight: .semibold))
                            Text(active)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .opacity(0.6)
                        }
                        .foregroundStyle(VitaColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.30), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onCreateFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.accentLight)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VitaColors.accent.opacity(0.10)))
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nova pasta")

                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: selectedFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            selectedFilter == nil
                                ? VitaColors.textWarm.opacity(0.45)
                                : VitaColors.accentLight
                        )
                }
                .buttonStyle(.plain)
                // vita-modals-ignore: TranscricaoFilterSheet é sheet com NavigationStack+searchable+List, NÃO cabe em VitaBubble
                .sheet(isPresented: $showFilterSheet) {
                    TranscricaoFilterSheet(
                        disciplines: filterChips,
                        selected: $selectedFilter
                    )
                }
            }
            .padding(.horizontal, 16)

            // Filtros principais e, abaixo de GRAVAÇÕES, a árvore de pastas.
            // Pastas deixam de competir com filtros dentro do carrossel.
            viewModeChips

            if !folders.isEmpty {
                folderRows
            }

            if isLoading {
                ProgressView()
                    .tint(TealColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if case .folder = listView {
                // A gravação da pasta selecionada vive imediatamente abaixo
                // da própria linha expansível, não duplicada no fim da seção.
                EmptyView()
            } else if filteredRecordings.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.12), VitaColors.accent.opacity(0.03)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(VitaColors.accent.opacity(0.55))
                    }

                    Text("Nenhuma gravação ainda")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text("Grave sua aula e a IA transcreve, resume,\ne cria flashcards automaticamente.")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
            } else {
                // Date-grouped recordings
                VStack(spacing: 4) {
                    ForEach(groupedRecordings(for: filteredRecordings), id: \.key) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.key.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                                .tracking(0.8)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(group.recordings) { rec in
                                VitaCardRow(
                                    onTap: { onTap(rec) },
                                    onSwipeRight: { onFavorite?(rec) },
                                    onSwipeLeft: { onDelete(rec) }
                                ) {
                                    TealGlassRecordingCard(recording: rec)
                                }
                                    .padding(.horizontal, 16)
                                    // Long press → context menu com todas ações quick-access.
                                    // Pattern Apple Mail/Photos: hold revela menu contextual
                                    // sem precisar abrir sheet inteiro.
                                    .contextMenu {
                                        // Ver detalhes (mesmo que tap)
                                        Button {
                                            onTap(rec)
                                        } label: {
                                            Label("Ver detalhes", systemImage: "doc.text.magnifyingglass")
                                        }

                                        // Toggle favorito — mesmo callback do swipe right.
                                        // Label muda dinâmico conforme estado atual.
                                        if let onFavorite {
                                            Button {
                                                onFavorite(rec)
                                            } label: {
                                                Label(
                                                    rec.favorite == true ? "Remover dos favoritos" : "Favoritar",
                                                    systemImage: rec.favorite == true ? "star.slash" : "star"
                                                )
                                            }
                                        }

                                        // Renomear inline — sem precisar abrir sheet
                                        Button {
                                            renameValue = rec.title
                                            renamingRec = rec
                                        } label: {
                                            Label("Renomear", systemImage: "pencil")
                                        }

                                        Divider()

                                        // Gerar conteúdo — 5 ações direto, sem sheet
                                        if rec.isTranscribed, let onGenerate {
                                            Button {
                                                onGenerate(rec, "summary")
                                            } label: {
                                                Label("Gerar resumo", systemImage: "doc.text")
                                            }
                                            Button {
                                                onGenerate(rec, "flashcards")
                                            } label: {
                                                Label("Gerar flashcards", systemImage: "rectangle.stack")
                                            }
                                            Button {
                                                onGenerate(rec, "questions")
                                            } label: {
                                                Label("Gerar questões", systemImage: "questionmark.circle")
                                            }
                                            Button {
                                                onGenerate(rec, "concepts")
                                            } label: {
                                                Label("Extrair conceitos-chave", systemImage: "key")
                                            }
                                            Button {
                                                onGenerate(rec, "mindmap")
                                            } label: {
                                                Label("Gerar mindmap", systemImage: "point.3.connected.trianglepath.dotted")
                                            }

                                            Divider()
                                        }

                                        // Excluir (destructive, sempre disponível)
                                        Button(role: .destructive) {
                                            onDelete(rec)
                                        } label: {
                                            Label("Excluir", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        // vita-modals-ignore: TextField inline no .alert — VitaAlert não suporta input de texto
        .alert(
            "Renomear gravação",
            isPresented: Binding(
                get: { renamingRec != nil },
                set: { if !$0 { renamingRec = nil } }
            )
        ) {
            TextField("Título", text: $renameValue)
            Button("Cancelar", role: .cancel) { renamingRec = nil }
            Button("Salvar") {
                let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let rec = renamingRec, !trimmed.isEmpty {
                    onRename?(rec, trimmed)
                }
                renamingRec = nil
            }
            .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        // vita-modals-ignore: TextField inline no .alert — VitaAlert não suporta input de texto
        .alert(
            "Renomear pasta",
            isPresented: Binding(
                get: { renamingFolder != nil },
                set: { if !$0 { renamingFolder = nil } }
            )
        ) {
            TextField("Nome da pasta", text: $renameFolderValue)
            Button("Cancelar", role: .cancel) { renamingFolder = nil }
            Button("Salvar") {
                let trimmed = renameFolderValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let folder = renamingFolder, !trimmed.isEmpty, trimmed != folder.name {
                    onRenameFolder?(folder, trimmed)
                }
                renamingFolder = nil
            }
            .disabled(renameFolderValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .vitaAlert(
            isPresented: Binding(
                get: { deletingFolder != nil },
                set: { if !$0 { deletingFolder = nil } }
            ),
            title: "Excluir pasta?",
            message: deletingFolder.map { f in
                "A pasta \"\(f.name)\" será apagada. As gravações dentro voltam pra \"Todas\" — nada é deletado."
            },
            destructiveLabel: "Excluir pasta",
            cancelLabel: "Cancelar",
            onConfirm: {
                if let folder = deletingFolder {
                    onDeleteFolder?(folder)
                }
                deletingFolder = nil
            }
        )
    }

    /// Scroll horizontal de chips — apenas Todas / Favoritas. Pastas agora
    /// formam uma árvore vertical expansível abaixo de GRAVAÇÕES.
    /// Padrão D4 carved: inactive = warm dark glass + gold border 22%; active =
    /// gold accent 18% fill + gold border 45% + accentLight foreground (NÃO
    /// gold opaco com texto preto). Alinhamento horizontal idêntico aos
    /// cards/header (16pt) — primeiro chip alinha com edge das gravações.
    @ViewBuilder
    private var viewModeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                viewChip(
                    label: "Todas",
                    icon: "tray.full",
                    isSelected: listView == .all
                ) { listView = .all }

                viewChip(
                    label: "Favoritas",
                    icon: "star.fill",
                    isSelected: listView == .favorites
                ) { listView = .favorites }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var folderRows: some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            ForEach(folders) { folder in
                folderRow(folder)
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    @ViewBuilder
    private func folderRow(_ folder: VitaAPI.StudioFolder) -> some View {
        let isExpanded = listView == .folder(id: folder.id)
        let allFolderRecordings = recordings(in: folder)
        let visibleFolderRecordings = applyingDisciplineFilter(to: allFolderRecordings)

        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.easeInOut(duration: 0.22)) {
                    listView = isExpanded ? .all : .folder(id: folder.id)
                }
            } label: {
                HStack(spacing: VitaTokens.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .fill(VitaColors.accent.opacity(isExpanded ? 0.18 : 0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                                    .stroke(VitaColors.glassBorder, lineWidth: 0.5)
                            )

                        Image(systemName: folder.icon ?? "folder.fill")
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(isExpanded ? VitaColors.accentLight : VitaColors.accent)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                        Text(folder.name)
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        Text(allFolderRecordings.count == 1 ? "1 áudio" : "\(allFolderRecordings.count) áudios")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    Spacer(minLength: VitaTokens.Spacing.sm)

                    Image(systemName: "chevron.right")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(isExpanded ? VitaColors.accentLight : VitaColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(VitaTokens.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(folder.name), \(allFolderRecordings.count) áudios")
            .accessibilityValue(isExpanded ? "Expandida" : "Recolhida")

            if isExpanded {
                Divider()
                    .overlay(VitaColors.glassBorder)
                    .padding(.horizontal, VitaTokens.Spacing.md)

                if visibleFolderRecordings.isEmpty {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Image(systemName: "waveform")
                            .foregroundStyle(VitaColors.accent.opacity(0.65))
                        Text(selectedFilter == nil ? "Nenhum áudio nesta pasta" : "Nenhum áudio com este filtro")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(VitaTokens.Spacing.lg)
                } else {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        ForEach(groupedRecordings(for: visibleFolderRecordings), id: \.key) { group in
                            Text(group.key.uppercased())
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.sectionLabel)
                                .tracking(0.8)
                                .padding(.horizontal, VitaTokens.Spacing.md)
                                .padding(.top, VitaTokens.Spacing.sm)

                            ForEach(group.recordings) { rec in
                                VitaCardRow(
                                    onTap: { onTap(rec) },
                                    onSwipeRight: { onFavorite?(rec) },
                                    onSwipeLeft: { onDelete(rec) }
                                ) {
                                    TealGlassRecordingCard(recording: rec)
                                }
                                .padding(.horizontal, VitaTokens.Spacing.sm)
                                .contextMenu {
                                    Button { onTap(rec) } label: {
                                        Label("Ver detalhes", systemImage: "doc.text.magnifyingglass")
                                    }
                                    if let onFavorite {
                                        Button { onFavorite(rec) } label: {
                                            Label(
                                                rec.favorite == true ? "Remover dos favoritos" : "Favoritar",
                                                systemImage: rec.favorite == true ? "star.slash" : "star"
                                            )
                                        }
                                    }
                                    Button {
                                        renameValue = rec.title
                                        renamingRec = rec
                                    } label: {
                                        Label("Renomear", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { onDelete(rec) } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.bottom, VitaTokens.Spacing.sm)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .stroke(isExpanded ? VitaColors.accent.opacity(0.34) : VitaColors.glassBorder, lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.18), radius: VitaTokens.Elevation.lg, y: VitaTokens.Elevation.sm)
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
        .contextMenu {
            Button {
                renameFolderValue = folder.name
                renamingFolder = folder
            } label: {
                Label("Renomear", systemImage: "pencil")
            }
            if onShareFolder != nil {
                Button { onShareFolder?(folder) } label: {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                }
            }
            Divider()
            Button(role: .destructive) {
                deletingFolder = folder
            } label: {
                Label("Excluir", systemImage: "trash")
            }
        }
    }

    private func viewChip(
        label: String?,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        }) {
            HStack(spacing: label == nil ? 0 : 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
            }
            // Foreground: accentLight quando selecionado (não preto opaco),
            // textWarm 0.65 quando inactive — sutil mas legível.
            .foregroundStyle(
                isSelected
                    ? VitaColors.accentLight
                    : VitaColors.textWarm.opacity(0.65)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Background D4 carved: warm dark gradient base, com gold tint
            // mais forte quando selected.
            .background(
                ZStack {
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 30/255, green: 22/255, blue: 15/255).opacity(0.92),
                                Color(red: 14/255, green: 10/255, blue: 7/255).opacity(0.92)
                            ],
                            startPoint: UnitPoint(x: 0.5, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 1)
                        )
                    )
                    if isSelected {
                        Capsule().fill(VitaColors.accent.opacity(0.18))
                    }
                }
            )
            // Border: gold 22% inactive, gold 45% selected — D4 carved.
            .overlay(
                Capsule().strokeBorder(
                    Color(red: 200/255, green: 160/255, blue: 80/255).opacity(isSelected ? 0.45 : 0.22),
                    lineWidth: isSelected ? 1 : 0.8
                )
            )
            .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Teal Glass Recording Card

struct TealGlassRecordingCard: View {
    let recording: TranscricaoEntry

    private var displayStatus: RecordingStatus {
        if recording.hasFailed { return .failed }
        return recording.isTranscribed ? .transcribed : .pending
    }

    /// Sempre retorna uma string — se LLM não classificou ou disciplina vazia,
    /// cai pra "OUTROS" (pasta default, pattern iOS Notes/Arquivos/Lembretes).
    /// Evita card "órfão" sem contexto visual.
    private var disciplineDisplay: String {
        let trimmed = (recording.discipline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "Outros" : trimmed).uppercased()
    }

    /// Sanitiza título: se backend gravou UUID como título (bug — algumas
    /// gravações subiam sem título e o backend caía no ID), substitui por
    /// "Gravação". Regex pega UUID v4 padrão.
    private var titleDisplay: String {
        let t = recording.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Gravação" }
        // UUID v4: 8-4-4-4-12 hex chars
        if t.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil {
            return "Gravação"
        }
        return t
    }

    var body: some View {
        HStack(spacing: 14) {
            // Mic icon in glass circle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.15 : 0.32),
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.06 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 6, y: 3)

                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.92))
            }
            .opacity(displayStatus == .pending ? 0.5 : 1.0)

            // Text block
            VStack(alignment: .leading, spacing: 3) {
                // Discipline header (sempre presente, fallback "Outros")
                // iOS pattern: Notes/Voice Memos mostram pasta/categoria antes do título
                Text(disciplineDisplay)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.9)
                    .lineLimit(1)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))

                Text(titleDisplay)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)

                // Metadata row: date · duration · size
                HStack(spacing: 5) {
                    let dateStr = recording.relativeDate
                    if !dateStr.isEmpty {
                        Label(dateStr, systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let duration = recording.duration, !duration.isEmpty {
                        if !dateStr.isEmpty {
                            Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        }
                        Text(duration)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let size = recording.formattedSize {
                        Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }
                }
                .labelStyle(.titleOnly)
            }

            Spacer()

            // Status badge only — chevron removed (data+duration já fica
            // abaixo do título, indicador visual de tappable é o próprio
            // glassCard com hover state).
            TranscricaoStatusBadge(status: displayStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16)
    }
}

// `abbreviateDiscipline` moved to TranscricaoControls.swift (shared with pickers).
