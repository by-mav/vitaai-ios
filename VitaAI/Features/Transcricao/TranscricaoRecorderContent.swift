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
        VStack(spacing: 10) {
            // Timer gigante centralizado; caixa de ferramentas + Importar
            // ancorados à direita, na altura do cronômetro (Rafael 2026-07-01:
            // consolida Disciplina/Idioma/Modo numa caixa só — área limpa).
            ZStack {
                Text(formatTranscricaoElapsed(elapsedSeconds))
                    .font(VitaTypography.displayLarge)
                    .fontWeight(.bold)
                    .tracking(-1)
                    .monospacedDigit()
                    .foregroundStyle(
                        isRecording
                            ? VitaColors.accentLight.opacity(0.95)
                            : Color.white.opacity(0.22)
                    )
                    .shadow(color: isRecording ? VitaColors.accent.opacity(0.4) : .clear, radius: 32)

                HStack(spacing: VitaTokens.Spacing.sm) {
                    Spacer()
                    TranscricaoToolbox(
                        selectedDiscipline: $selectedDiscipline,
                        selectedLanguage: $selectedLanguage,
                        transcribeWithAI: $transcribeWithAI,
                        disabled: isRecording
                    )
                    TranscricaoImportButton(disabled: isRecording, onImport: onImportAudio)
                }
                .padding(.trailing, VitaTokens.Spacing.xs)
            }

            // Status label secundário — só aparece enquanto gravando/pausado
            // (quando .idle o "Toque para gravar" do orb já cobre o estado).
            if isActive {
                Text(statusLabel)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.accentLight.opacity(0.72))
                    .transition(.opacity)
            }

            // Orb/mascote CENTRAL como botão principal. Label "Toque para
            // gravar / parar" mais forte abaixo, sem duplicar o statusLabel.
            Button(action: onToggle) {
                VStack(spacing: 10) {
                    VitaTypingMascot(isRecording: isActive, size: recorderButtonWidth)

                    Text(mascotLabel)
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            isActive
                                ? VitaColors.accentLight.opacity(0.85)
                                : VitaColors.textSecondary
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
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.accentLight)
                .frame(width: 30, height: 30)
                .background(Circle().fill(VitaColors.glassBg))
                .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.5))
                .frame(width: 44, height: 44)
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
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.accentLight)
                .frame(width: 30, height: 30)
                .background(Circle().fill(VitaColors.glassBg))
                .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.5))
                .frame(width: 44, height: 44)
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

// MARK: - Library view mode (biblioteca / favoritas / pasta)

/// Sub-view filter aplicado pelas chips horizontais no header. Combina
/// com `selectedFilter` (disciplina, do filtro avançado) — ambos têm que
/// passar pra gravação aparecer.
enum TranscricaoListView: Equatable {
    case library
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
    /// Move a gravação para uma pasta, disciplina ou para a biblioteca geral.
    /// Os dois destinos são mutuamente exclusivos; nil/nil remove a organização.
    var onMove: ((TranscricaoEntry, String?, String?) -> Void)? = nil
    /// Abre o drawer canônico de edição da pasta.
    var onEditFolder: ((VitaAPI.StudioFolder) -> Void)? = nil
    /// Excluir pasta pelo menu visível. Gravações dentro vão pra lista geral.
    /// Backend: DELETE /api/studio/folders/:id
    var onDeleteFolder: ((VitaAPI.StudioFolder) -> Void)? = nil
    /// Compartilhar pasta — abre share sheet com texto resumindo gravações.
    var onShareFolder: ((VitaAPI.StudioFolder) -> Void)? = nil

    @State private var renamingRec: TranscricaoEntry? = nil
    @State private var renameValue: String = ""
    @State private var movingRec: TranscricaoEntry? = nil
    @State private var deletingRec: TranscricaoEntry? = nil
    @State private var deletingFolder: VitaAPI.StudioFolder? = nil
    @State private var activeDropFolderID: String? = nil
    @State private var simulatorFolderOverrides: [String: String] = [:]
    @State private var simulatorUnfiledRecordingIDs: Set<String> = []

    /// Preview visual somente no Simulator/Debug. Usa as pastas que vieram da
    /// API, mas nunca persiste nem envia estes áudios ao servidor.
    private var libraryRecordings: [TranscricaoEntry] {
        #if DEBUG
        #if targetEnvironment(simulator)
        return recordings + simulatorPreviewRecordings
        #else
        return recordings
        #endif
        #else
        return recordings
        #endif
    }

    #if DEBUG
    #if targetEnvironment(simulator)
    private var simulatorPreviewRecordings: [TranscricaoEntry] {
        let folderSamples: [[(String, String, Bool)]] = [
            [
                ("Farmacocinética — aula 04", "48 min", false),
                ("Anti-hipertensivos", "36 min", true),
                ("Revisão de antimicrobianos", "52 min", false),
            ],
            [
                ("Consulta centrada na pessoa", "41 min", true),
                ("Atenção primária — território", "29 min", false),
            ],
            [
                ("Lesões corporais", "44 min", false),
                ("Ética e responsabilidade médica", "33 min", false),
            ],
        ]
        let formatter = ISO8601DateFormatter()
        let now = Date()

        return Array(folders.prefix(folderSamples.count).enumerated()).flatMap { folderIndex, folder in
            folderSamples[folderIndex].enumerated().map { itemIndex, sample in
                var entry = TranscricaoEntry()
                let previewID = "simulator-preview-\(folder.id)-\(itemIndex)"
                entry.id = previewID
                entry.title = sample.0
                entry.duration = sample.1
                entry.status = "ready"
                if simulatorUnfiledRecordingIDs.contains(previewID) {
                    entry.discipline = nil
                    entry.folderId = nil
                } else if let overrideFolderID = simulatorFolderOverrides[previewID],
                   let overrideFolder = folders.first(where: { $0.id == overrideFolderID }) {
                    entry.discipline = overrideFolder.subjectName ?? overrideFolder.name
                    entry.folderId = overrideFolderID
                } else {
                    entry.discipline = folder.subjectName ?? folder.name
                    entry.folderId = folder.id
                }
                entry.fileName = "preview-\(folderIndex)-\(itemIndex).m4a"
                entry.fileSize = 4_800_000 + (folderIndex * 900_000) + (itemIndex * 600_000)
                entry.createdAt = formatter.string(
                    from: Calendar.current.date(
                        byAdding: .hour,
                        value: -(folderIndex * 30 + itemIndex * 4),
                        to: now
                    ) ?? now
                )
                entry.favorite = sample.2
                return entry
            }
        }
    }
    #endif
    #endif

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
        libraryRecordings.filter { recording in
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

    private func belongsToAnyFolder(_ recording: TranscricaoEntry) -> Bool {
        if let folderID = recording.folderId,
           folders.contains(where: { $0.id == folderID }) {
            return true
        }
        guard let discipline = recording.discipline else { return false }
        return folders.contains { folder in
            guard folder.isSubjectFolder else { return false }
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

    private var filteredRecordings: [TranscricaoEntry] {
        var items = libraryRecordings
        // Step 1 — biblioteca, favoritas ou pasta expandida.
        switch listView {
        case .library:
            items = items.filter { !belongsToAnyFolder($0) }
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

    private var headerRecordingCount: Int {
        switch listView {
        case .favorites:
            return applyingDisciplineFilter(to: libraryRecordings.filter { $0.favorite == true }).count
        case .library, .folder:
            return applyingDisciplineFilter(to: libraryRecordings).count
        }
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
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(alignment: .leading, spacing: 0) {
                libraryHeader
                    .frame(minHeight: VitaTokens.Spacing._4xl + VitaTokens.Spacing.xs)

                if let active = selectedFilter {
                    libraryDivider
                    activeFilterTag(active)
                }

                if !folders.isEmpty, listView != .favorites {
                    libraryDivider
                    folderRows
                }

                if isLoading {
                    libraryDivider
                    ProgressView()
                        .tint(TealColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VitaTokens.Spacing._2xl)
                } else if case .folder = listView {
                    // A gravação da pasta selecionada vive imediatamente abaixo
                    // da própria linha expansível, não duplicada no fim da seção.
                    EmptyView()
                } else {
                    libraryDivider
                    if filteredRecordings.isEmpty {
                        compactEmptyState
                    } else {
                        recordingGroups(filteredRecordings)
                    }
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
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
        .sheet(item: $movingRec) { recording in
            TranscricaoMovePickerSheet(
                currentSlug: nil,
                currentFolderId: recording.folderId,
                onPick: { folderID, disciplineSlug in
                    performMove(recording, folderID: folderID, disciplineSlug: disciplineSlug)
                }
            )
        }
        .vitaAlert(
            isPresented: Binding(
                get: { deletingRec != nil },
                set: { if !$0 { deletingRec = nil } }
            ),
            title: "Excluir gravação?",
            message: deletingRec.map { "\"\($0.title)\" será excluída definitivamente." },
            destructiveLabel: "Excluir gravação",
            cancelLabel: "Cancelar",
            onConfirm: {
                if let recording = deletingRec {
                    onDelete(recording)
                }
                deletingRec = nil
            }
        )
        .vitaAlert(
            isPresented: Binding(
                get: { deletingFolder != nil },
                set: { if !$0 { deletingFolder = nil } }
            ),
            title: "Excluir pasta?",
            message: deletingFolder.map { f in
                "A pasta \"\(f.name)\" será apagada. As gravações dentro voltam para a lista geral — nenhum áudio é deletado."
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

    /// Mesmo header da Jornada: label e ações irmãs no mesmo eixo.
    private var libraryHeader: some View {
        HStack(spacing: VitaTokens.Spacing.xs) {
            Text("GRAVAÇÕES")
                .font(VitaTypography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.sectionLabel)
                .tracking(0.8)

            if !libraryRecordings.isEmpty {
                Text("· \(headerRecordingCount)")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textTertiary)
                    .tracking(0.8)
            }

            Spacer(minLength: 0)

            libraryIconButton(
                icon: "star.fill",
                label: "Favoritas",
                isSelected: listView == .favorites
            ) {
                selectLibraryMode(listView == .favorites ? .library : .favorites)
            }

            libraryIconButton(
                icon: "line.3.horizontal.decrease",
                label: "Filtrar gravações",
                isSelected: selectedFilter != nil
            ) {
                showFilterSheet = true
            }
            // vita-modals-ignore: TranscricaoFilterSheet usa NavigationStack+searchable+List
            .sheet(isPresented: $showFilterSheet) {
                TranscricaoFilterSheet(
                    disciplines: filterChips,
                    selected: $selectedFilter
                )
            }

            libraryIconButton(
                icon: "folder.badge.plus",
                label: "Nova pasta",
                isSelected: false,
                action: onCreateFolder
            )
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private func selectLibraryMode(_ mode: TranscricaoListView) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
            listView = mode
        }
    }

    private func libraryIconButton(
        icon: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        } label: {
            Image(systemName: icon)
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? VitaColors.surface : VitaColors.accentLight)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isSelected ? VitaColors.accent : VitaColors.glassBg))
                .overlay(
                    Circle().stroke(
                        isSelected ? VitaColors.accent : VitaColors.glassBorder,
                        lineWidth: 0.5
                    )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func activeFilterTag(_ active: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFilter = nil
            }
        } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                Image(systemName: "book.closed.fill")
                    .font(VitaTypography.labelSmall)
                Text(active)
                    .font(VitaTypography.labelMedium)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(VitaTypography.labelSmall)
                    .opacity(0.7)
            }
            .foregroundStyle(VitaColors.accentLight)
            .padding(.horizontal, VitaTokens.Spacing.md)
            .frame(height: 32)
            .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.30), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .contentShape(Rectangle())
        .accessibilityLabel("Remover filtro \(active)")
    }

    private var libraryDivider: some View {
        Divider()
            .overlay(VitaColors.glassBorder)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(VitaColors.glassBorder)
            .padding(.leading, VitaTokens.Spacing.lg + 36 + VitaTokens.Spacing.md)
            .padding(.trailing, VitaTokens.Spacing.lg)
    }

    private var compactEmptyState: some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "waveform.and.mic")
                .font(VitaTypography.headlineMedium)
                .foregroundStyle(VitaColors.accent.opacity(0.62))

            Text("Nenhuma gravação ainda")
                .font(VitaTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)

            Text("Grave sua aula para transcrever e criar materiais.")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VitaTokens.Spacing._2xl)
        .padding(.vertical, VitaTokens.Spacing._2xl)
    }

    @ViewBuilder
    private func recordingGroups(_ items: [TranscricaoEntry]) -> some View {
        let groups = groupedRecordings(for: items)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.key) { groupIndex, group in
                Text(group.key.uppercased())
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.sectionLabel)
                    .tracking(0.8)
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                    .padding(.top, VitaTokens.Spacing.sm)
                    .padding(.bottom, VitaTokens.Spacing.xs)

                ForEach(Array(group.recordings.enumerated()), id: \.element.id) { index, recording in
                    recordingRow(recording)

                    if index < group.recordings.count - 1 {
                        rowDivider
                    }
                }

                if groupIndex < groups.count - 1 {
                    libraryDivider
                }
            }
        }
    }

    private func recordingRow(_ recording: TranscricaoEntry) -> some View {
        VitaCardRow(
            onTap: nil,
            onSwipeRight: { onFavorite?(recording) },
            onSwipeLeft: { deletingRec = recording }
        ) {
            HStack(spacing: 0) {
                Button {
                    onTap(recording)
                } label: {
                    TealGlassRecordingCard(recording: recording)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .draggable(recording.id) {
                    recordingDragPreview(recording)
                }
                .accessibilityHint("Mantenha pressionado e arraste para mover entre pastas")

                Menu {
                    recordingMenu(recording)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(VitaColors.accent.opacity(0.07)))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Opções de \(recording.title)")
            }
            .padding(.horizontal, VitaTokens.Spacing.xs)
        }
    }

    @ViewBuilder
    private func recordingMenu(_ recording: TranscricaoEntry) -> some View {
        if let onFavorite {
            Button { onFavorite(recording) } label: {
                Label(
                    recording.favorite == true ? "Remover dos favoritos" : "Favoritar",
                    systemImage: recording.favorite == true ? "star.slash" : "star"
                )
            }
        }

        ShareLink(
            item: shareText(for: recording),
            subject: Text(recording.title)
        ) {
            Label("Compartilhar", systemImage: "square.and.arrow.up")
        }

        Button {
            renameValue = recording.title
            renamingRec = recording
        } label: {
            Label("Renomear", systemImage: "pencil")
        }

        Button { movingRec = recording } label: {
            Label("Mover para…", systemImage: "folder")
        }

        if recording.isTranscribed, let onGenerate {
            Menu("Criar com IA", systemImage: "sparkles") {
                Button { onGenerate(recording, "summary") } label: {
                    Label("Resumo", systemImage: "doc.text")
                }
                Button { onGenerate(recording, "flashcards") } label: {
                    Label("Flashcards", systemImage: "rectangle.stack")
                }
                Button { onGenerate(recording, "questions") } label: {
                    Label("Questões", systemImage: "questionmark.circle")
                }
                Button { onGenerate(recording, "concepts") } label: {
                    Label("Conceitos-chave", systemImage: "key")
                }
                Button { onGenerate(recording, "mindmap") } label: {
                    Label("Mindmap", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
        }

        Divider()

        Button(role: .destructive) { deletingRec = recording } label: {
            Label("Excluir", systemImage: "trash")
        }
    }

    private func recordingDragPreview(_ recording: TranscricaoEntry) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "waveform")
                .foregroundStyle(VitaColors.accent)
            Text(recording.title)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.vertical, VitaTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(VitaColors.accent.opacity(0.30), lineWidth: 0.75)
        )
    }

    private func shareText(for recording: TranscricaoEntry) -> String {
        var lines = [recording.title]
        if let discipline = recording.discipline, !discipline.isEmpty {
            lines.append(discipline)
        }
        if let detail = recording.detail, !detail.isEmpty {
            lines.append(detail)
        }
        lines.append("Compartilhado pelo Vita")
        return lines.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var folderRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                folderRow(folder)

                if index < folders.count - 1 {
                    libraryDivider
                        .padding(.leading, VitaTokens.Spacing.lg + 24 + VitaTokens.Spacing.md)
                }
            }
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: VitaAPI.StudioFolder) -> some View {
        let isExpanded = listView == .folder(id: folder.id)
        let isDropTarget = activeDropFolderID == folder.id
        let allFolderRecordings = recordings(in: folder)
        let visibleFolderRecordings = applyingDisciplineFilter(to: allFolderRecordings)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        listView = isExpanded ? .library : .folder(id: folder.id)
                    }
                } label: {
                    HStack(spacing: VitaTokens.Spacing.md) {
                        Image(systemName: "folder")
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(isExpanded || isDropTarget ? VitaColors.accentLight : VitaColors.accent)
                            .frame(width: 24)

                        Text(folder.name)
                            .font(VitaTypography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: VitaTokens.Spacing.sm)

                        Text("\(allFolderRecordings.count)")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(isExpanded ? VitaColors.accentLight : VitaColors.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.leading, VitaTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(folder.name), \(allFolderRecordings.count) áudios")
                .accessibilityValue(isExpanded ? "Expandida" : "Recolhida")
                .accessibilityHint("Solte uma gravação aqui para movê-la")

                Menu {
                    Button { onEditFolder?(folder) } label: {
                        Label("Renomear", systemImage: "pencil")
                    }
                    if onShareFolder != nil {
                        Button { onShareFolder?(folder) } label: {
                            Label("Compartilhar", systemImage: "square.and.arrow.up")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { deletingFolder = folder } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(VitaColors.accent.opacity(0.07)))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Opções da pasta \(folder.name)")
            }
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                    .fill(isDropTarget ? VitaColors.accent.opacity(0.12) : Color.clear)
                    .padding(.horizontal, VitaTokens.Spacing.xs)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                    .stroke(isDropTarget ? VitaColors.accent.opacity(0.42) : Color.clear, lineWidth: 0.75)
                    .padding(.horizontal, VitaTokens.Spacing.xs)
            )
            .dropDestination(for: String.self) { recordingIDs, _ in
                guard let recordingID = recordingIDs.first,
                      let recording = libraryRecordings.first(where: { $0.id == recordingID }),
                      recording.folderId != folder.id else {
                    return false
                }
                performMove(recording, folderID: folder.id, disciplineSlug: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.18)) {
                    if targeted {
                        if activeDropFolderID != folder.id {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        activeDropFolderID = folder.id
                    } else if activeDropFolderID == folder.id {
                        activeDropFolderID = nil
                    }
                }
            }

            if isExpanded {
                libraryDivider
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
                    recordingGroups(visibleFolderRecordings)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    private func performMove(
        _ recording: TranscricaoEntry,
        folderID: String?,
        disciplineSlug: String?
    ) {
        #if DEBUG
        #if targetEnvironment(simulator)
        if recording.id.hasPrefix("simulator-preview-") {
            withAnimation(.easeInOut(duration: 0.22)) {
                if let folderID {
                    simulatorFolderOverrides[recording.id] = folderID
                    simulatorUnfiledRecordingIDs.remove(recording.id)
                } else if let disciplineSlug,
                          let subjectFolder = folders.first(where: { $0.disciplineSlug == disciplineSlug }) {
                    simulatorFolderOverrides[recording.id] = subjectFolder.id
                    simulatorUnfiledRecordingIDs.remove(recording.id)
                } else {
                    simulatorFolderOverrides.removeValue(forKey: recording.id)
                    simulatorUnfiledRecordingIDs.insert(recording.id)
                }
            }
            return
        }
        #endif
        #endif

        onMove?(recording, folderID, disciplineSlug)
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
        HStack(spacing: VitaTokens.Spacing.md) {
            // Mic icon in glass circle
            ZStack {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
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
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                            .stroke(VitaColors.accent.opacity(0.22), lineWidth: 0.5)
                    )

                Image(systemName: "waveform")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.accentLight.opacity(0.92))
            }
            .opacity(displayStatus == .pending ? 0.5 : 1.0)

            // Text block
            VStack(alignment: .leading, spacing: 1) {
                // Discipline header (sempre presente, fallback "Outros")
                // iOS pattern: Notes/Voice Memos mostram pasta/categoria antes do título
                Text(disciplineDisplay)
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .tracking(0.9)
                    .lineLimit(1)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))

                Text(titleDisplay)
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                // Metadata row: date · duration · size
                HStack(spacing: VitaTokens.Spacing.xs) {
                    let dateStr = recording.relativeDate
                    if !dateStr.isEmpty {
                        Label(dateStr, systemImage: "clock")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let duration = recording.duration, !duration.isEmpty {
                        if !dateStr.isEmpty {
                            Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        }
                        Text(duration)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let size = recording.formattedSize {
                        Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        Text(size)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if recording.favorite == true {
                        Image(systemName: "star.fill")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.accent)
                            .accessibilityLabel("Favorita")
                    }

                    statusIndicator
                }
                .labelStyle(.titleOnly)
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.vertical, VitaTokens.Spacing.xs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch displayStatus {
        case .transcribed:
            Image(systemName: "checkmark.circle.fill")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.dataGreen)
                .accessibilityLabel("Transcrito")
        case .pending:
            ProgressView()
                .scaleEffect(0.5)
                .tint(VitaColors.accentHover)
                .frame(width: 10, height: 10)
                .accessibilityLabel("Processando")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.dataRed)
                .accessibilityLabel("Falhou")
        case .recording:
            Circle()
                .fill(VitaColors.dataRed)
                .frame(width: 6, height: 6)
                .accessibilityLabel("Gravando")
        }
    }
}

// `abbreviateDiscipline` moved to TranscricaoControls.swift (shared with pickers).
