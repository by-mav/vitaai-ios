import SwiftUI

/// Popout COMPARTILHADO: gaveta glass pra escolher PDFs/materiais do aluno,
/// organizados em PASTAS por disciplina (reusa `DisciplineFolderCard` — o MESMO
/// card 3D da tela Faculdade), com multi-seleção, e gerar material de estudo.
/// Reusado por Flashcards (roxo), Questões (ouro) e Simulados (teal).
///
/// Casca = `VitaSheet` (glass ouro `ultraThinMaterial`, drag indicator, corner 28).
/// Navegação em 2 níveis DENTRO da gaveta: grid de pastas → toca a pasta →
/// lista de docs daquela disciplina. Sem `List` stock, sem busca — as pastas
/// SÃO a navegação. O miolo (`ensureDocumentStudySource` → `onGenerate`) é
/// preservado 1:1. Rafael 2026-07-10.
struct StudyMaterialPicker: View {
    /// Resultado que o tool devolve depois de gerar: rótulo + ação de abrir o destino.
    struct Result {
        let label: String        // ex "12 flashcards criados"
        let open: () -> Void     // abre o baralho/sessão gerado
    }

    let title: String            // ex "Criar flashcards"
    let actionVerb: String       // ex "Gerar flashcards"
    /// Cor da ferramenta: Flashcards `.purple`, Questões `.gold`, Simulados `.teal`.
    /// Tinge só os elementos funcionais (check, badge, CTA, hero) — a moldura da
    /// gaveta continua ouro.
    var accent: ToolAccent = .gold
    /// Recebe os sourceIds JÁ processados. O tool gera (generateStudyPack) e
    /// devolve rótulo + ação de abrir. Throws em falha.
    let onGenerate: ([String]) async throws -> Result

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var docs: [VitaDocument] = []
    @State private var selected: Set<String> = []
    @State private var openGroup: Group?          // nil = grid de pastas; senão drill nos docs
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var phase: Phase = .picking
    @State private var progressText = ""
    @State private var result: Result?

    private enum Phase: Equatable {
        case picking, working, done, failed(String)
        static func == (l: Phase, r: Phase) -> Bool {
            switch (l, r) {
            case (.picking, .picking), (.working, .working), (.done, .done): return true
            case let (.failed(a), .failed(b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        VitaSheet(title: nil, detents: [.large]) {
            ZStack {
                switch phase {
                case .picking: pickingBody
                case .working: workingBody
                case .done: doneBody
                case .failed(let msg): failedBody(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .interactiveDismissDisabled(phase == .working)
        .task { await load() }
    }

    // MARK: - Picking (grid de pastas → drill de docs)

    @ViewBuilder
    private var pickingBody: some View {
        VStack(spacing: 0) {
            header
            if isLoading {
                Spacer()
                VitaMascotEquipped(state: .thinking, size: 96)
                Spacer()
            } else if let err = loadError {
                errorState(err)
            } else if grouped.isEmpty {
                emptyState
            } else if let group = openGroup {
                folderDocsList(group)
            } else {
                foldersGrid
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isLoading, loadError == nil, !grouped.isEmpty {
                selectionCTA
            }
        }
    }

    private var header: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            if openGroup != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { openGroup = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")  // ds-allow: back da gaveta (área de toque)
                            .font(.system(size: 15, weight: .semibold))  // ds-allow: área de toque
                        Text("Disciplinas")
                            .font(VitaTypography.titleMedium)
                    }
                    .foregroundStyle(accent.accent)
                }
            } else {
                Text(title)
                    .font(VitaTypography.headlineSmall)
                    .foregroundStyle(VitaColors.textPrimary)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")  // ds-allow: fechar a gaveta (área de toque)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: área de toque
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(VitaColors.surfaceCard.opacity(0.5)))
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.top, VitaTokens.Spacing.lg)
        .padding(.bottom, VitaTokens.Spacing.sm)
    }

    // NÍVEL 1 — grid de pastas por disciplina (mesmo padrão de FaculdadeHomeScreen)
    private var foldersGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                SectionHeader(title: "Escolha as disciplinas")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 12
                ) {
                    ForEach(grouped) { group in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) { openGroup = group }
                        } label: {
                            DisciplineFolderCard(subjectName: group.subject, vitaScore: 0, onMenu: nil)
                                .overlay(alignment: .topTrailing) { countBadge(group) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
            }
            .padding(.vertical, VitaTokens.Spacing.md)
            .padding(.bottom, 96)  // respiro pro CTA flutuante
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func countBadge(_ group: Group) -> some View {
        let n = selectedCount(in: group)
        if n > 0 {
            Text("\(n)")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.surface)
                .frame(minWidth: 20, minHeight: 20)
                .background(Circle().fill(accent.accent))
                .overlay(Circle().stroke(VitaColors.surface, lineWidth: 1.5))
                .offset(x: 6, y: -6)
        }
    }

    // NÍVEL 2 — docs da disciplina escolhida, com multi-seleção
    private func folderDocsList(_ group: Group) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                SectionHeader(
                    title: group.subject,
                    subtitle: selectedCount(in: group) > 0 ? "\(selectedCount(in: group)) selecionados" : nil
                )
                ForEach(group.docs) { doc in
                    VitaCardRow(onTap: { toggle(doc.id) }) {
                        docRow(doc)
                    }
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                }
            }
            .padding(.vertical, VitaTokens.Spacing.sm)
            .padding(.bottom, 96)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func docRow(_ doc: VitaDocument) -> some View {
        let isOn = selected.contains(doc.id)
        return HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")  // ds-allow: check de seleção (área de toque)
                .font(.system(size: 22))  // ds-allow: área de toque
                .foregroundStyle(isOn ? accent.accent : VitaColors.textTertiary.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(fileExt(doc))
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(VitaTokens.Spacing.md)
        .glassCard(cornerRadius: 16)
    }

    private var selectionCTA: some View {
        Button {
            Task { await run() }
        } label: {
            Text(selected.isEmpty ? actionVerb : "\(actionVerb) (\(selected.count))")
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VitaTokens.Spacing.lg)
                .background(
                    Capsule().fill(selected.isEmpty ? VitaColors.textTertiary.opacity(0.4) : accent.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(selected.isEmpty)
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.bottom, VitaTokens.Spacing.lg)
    }

    // MARK: - Working / Done / Failed

    private var workingBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            VitaMascotEquipped(state: .thinking, size: 96)
            Text(progressText.isEmpty ? "Lendo o material..." : progressText)
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneBody: some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")  // ds-allow: ícone hero do estado final
                .font(.system(size: 48))  // ds-allow: hero
                .foregroundStyle(accent.accent)
            Text(result?.label ?? "Pronto")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                let open = result?.open
                dismiss()
                open?()
            } label: {
                Text("Estudar agora")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.surface)
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .padding(.vertical, VitaTokens.Spacing.md)
                    .background(Capsule().fill(accent.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(VitaTokens.Spacing._2xl)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedBody(_ msg: String) -> some View {
        VStack(spacing: VitaTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")  // ds-allow: ícone de erro
                .font(.system(size: 36))  // ds-allow: hero de erro
                .foregroundStyle(VitaColors.dataRed)
            Text("Não rolou")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Text(msg)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar de novo") { phase = .picking }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(accent.accent)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")  // ds-allow: ícone empty state
                .font(.system(size: 34))  // ds-allow: empty
                .foregroundStyle(VitaColors.textTertiary)
            Text("Nenhum material na tua biblioteca ainda")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VitaTokens.Spacing._3xl)
    }

    private func errorState(_ err: String) -> some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            Spacer()
            Text(err)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await load() } }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(accent.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VitaTokens.Spacing._3xl)
    }

    // MARK: - Data

    private struct Group: Identifiable {
        var id: String { subject }
        let subject: String
        let docs: [VitaDocument]
    }

    private var grouped: [Group] {
        let buckets = Dictionary(grouping: docs) { $0.subjectName ?? "Sem matéria" }
        return buckets.keys.sorted().map { key in
            Group(subject: key, docs: buckets[key]!.sorted { $0.title < $1.title })
        }
    }

    private func selectedCount(in g: Group) -> Int {
        g.docs.reduce(0) { $0 + (selected.contains($1.id) ? 1 : 0) }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func fileExt(_ doc: VitaDocument) -> String {
        doc.fileName.split(separator: ".").last.map { String($0).uppercased() } ?? "DOC"
    }

    private func load() async {
        isLoading = true; loadError = nil
        do { docs = try await container.api.getDocuments() }
        catch { loadError = "Não foi possível carregar teus materiais." }
        isLoading = false
    }

    // MARK: - Run (ensureSource -> onGenerate) — MIOLO PRESERVADO 1:1

    private func run() async {
        let picked = docs.filter { selected.contains($0.id) }
        guard !picked.isEmpty else { return }
        phase = .working
        do {
            var sourceIds: [String] = []
            for (i, doc) in picked.enumerated() {
                progressText = "Lendo o material \(i + 1)/\(picked.count)..."
                let resp = try await container.api.ensureDocumentStudySource(documentId: doc.id)
                sourceIds.append(resp.studioSourceId)
            }
            progressText = "Gerando..."
            let r = try await onGenerate(sourceIds)
            result = r
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
