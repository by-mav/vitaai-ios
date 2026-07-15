import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Popout COMPARTILHADO: gaveta glass OURO pra escolher PDFs/materiais do aluno
/// e gerar material de estudo. Reusado por Flashcards, Questões e Simulados.
///
/// Layout (Rafael 2026-07-10): UMA tela só — grid de PASTAS por disciplina
/// (reusa `DisciplineFolderCard`, com contagem de PDFs) que funciona como FILTRO
/// (tap = liga/desliga, não navega), busca glass, e a lista de PDFs embaixo
/// reagindo ao filtro. Multi-seleção nos PDFs. Tudo ouro (gold standard) — sem
/// accent por ferramenta.
///
/// PDFs do Canvas têm URL externa e o servidor NÃO baixa (anti-sobrecarga):
/// o app baixa o arquivo autenticado, extrai o texto com PDFKit no aparelho
/// (mesmo algoritmo do PdfViewer) e manda `extractedText` pro
/// `ensureDocumentStudySource`. Só segue pro `onGenerate` com source `ready`.
struct StudyMaterialPicker: View {
    /// Resultado que o tool devolve depois de gerar: rótulo + ação de abrir o destino.
    struct Result {
        let label: String        // ex "12 flashcards criados"
        let open: () -> Void     // abre o baralho/sessão gerado
    }

    let title: String            // ex "Criar flashcards"
    let actionVerb: String       // ex "Gerar flashcards"
    /// Recebe os sourceIds JÁ processados (todos `ready`). O tool gera
    /// (generateStudyPack) e devolve rótulo + ação de abrir. Throws em falha.
    let onGenerate: ([String]) async throws -> Result
    /// Nome da disciplina pra JÁ ligar a pasta dela como filtro ao abrir (vem
    /// da tela da disciplina). nil = nenhuma pasta ligada, mostra tudo.
    var initialSubjectName: String? = nil
    /// Material único a gerar DIRETO ao abrir (botão rápido num material
    /// recente): pula a escolha e já entra gerando. nil = fluxo normal de escolha.
    var autoStartDocument: VitaDocument? = nil

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var docs: [VitaDocument] = []
    @State private var selected: Set<String> = []         // ids de docs marcados
    @State private var activeSubjects: Set<String> = []   // pastas ligadas como filtro
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var phase: Phase = .picking
    @State private var progressText = ""
    @State private var result: Result?
    @State private var showFileImporter = false

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

    /// Erro com mensagem legível pro estudante (aparece no failedBody).
    private struct PickerError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
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
        // vita-modals-ignore: seletor nativo existente, compartilhado com upload de prova
        .sheet(isPresented: $showFileImporter) {
            DocumentPickerView(allowedTypes: [.pdf, .jpeg, .png]) { url in
                importPickedFile(url)
            }
        }
        .task {
            // Auto-start (botão rápido num material recente): já entra gerando
            // AQUELE material, sem passar pela escolha. Rafael 2026-07-14.
            if let doc = autoStartDocument {
                docs = [doc]
                selected = [doc.id]
                isLoading = false
                await run()
            } else {
                await load()
            }
        }
    }

    // MARK: - Picking (pastas-filtro + busca + lista)

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
            } else if groups.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isLoading, loadError == nil, !groups.isEmpty {
                selectionCTA
            }
        }
    }

    private var header: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")  // ds-allow: voltar da gaveta (área de toque)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: área de toque
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(VitaColors.surfaceCard.opacity(0.65)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")
            .accessibilityIdentifier("study_material_back")

            Text(title)
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer(minLength: 0)
            Button { showFileImporter = true } label: {
                Image(systemName: "doc.badge.plus")  // ds-allow: importar material (área de toque)
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: área de toque
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(VitaColors.surfaceCard.opacity(0.65)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enviar arquivo")
            .accessibilityIdentifier("study_material_upload")
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .padding(.top, VitaTokens.Spacing.lg)
        .padding(.bottom, VitaTokens.Spacing.sm)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                SectionHeader(title: "Disciplinas")
                foldersGrid
                GlassTextField(placeholder: "Buscar material", text: $searchText, icon: "magnifyingglass")
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                SectionHeader(
                    title: "Materiais",
                    subtitle: selected.isEmpty ? nil : "\(selected.count) selecionados"
                )
                docsList
            }
            .padding(.vertical, VitaTokens.Spacing.md)
            .padding(.bottom, 112)
        }
        .accessibilityIdentifier("study_material_scroll")
    }

    // Grid de pastas — tap liga/desliga a disciplina como filtro da lista abaixo.
    private var foldersGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 12
        ) {
            ForEach(groups) { group in
                let isActive = activeSubjects.contains(group.subject)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if isActive { activeSubjects.remove(group.subject) }
                        else { activeSubjects.insert(group.subject) }
                    }
                } label: {
                    VStack(spacing: VitaTokens.Spacing.xs) {
                        DisciplineFolderCard(subjectName: group.subject, itemCount: 0, onMenu: nil)
                            .overlay(alignment: .topTrailing) { countBadge(group) }
                            .overlay {
                                if isActive {
                                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                                        .stroke(VitaColors.accent.opacity(0.9), lineWidth: 1.5)
                                }
                            }
                        Text("\(group.docs.count) PDFs")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(isActive ? VitaColors.accentLight : VitaColors.textTertiary)
                    }
                    .opacity(activeSubjects.isEmpty || isActive ? 1 : 0.45)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
    }

    @ViewBuilder
    private func countBadge(_ group: Group) -> some View {
        let n = selectedCount(in: group)
        if n > 0 {
            Text("\(n)")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.surface)
                .frame(minWidth: 20, minHeight: 20)
                .background(Circle().fill(VitaColors.accent))
                .overlay(Circle().stroke(VitaColors.surface, lineWidth: 1.5))
                .offset(x: 6, y: -6)
        }
    }

    // Lista de PDFs filtrada pelas pastas ativas + busca.
    @ViewBuilder
    private var docsList: some View {
        if visibleDocs.isEmpty {
            VStack(spacing: VitaTokens.Spacing.sm) {
                Image(systemName: "doc.text.magnifyingglass")  // ds-allow: ícone empty da lista
                    .font(.system(size: 28))  // ds-allow: empty
                    .foregroundStyle(VitaColors.textTertiary)
                Text(searchText.isEmpty ? "Nenhum material nessas pastas" : "Nenhum resultado")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VitaTokens.Spacing._2xl)
        } else {
            LazyVStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(visibleDocs) { doc in
                    Button {
                        toggle(doc.id)
                    } label: {
                        docRow(doc)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("study_material_doc_row")
                    .accessibilityLabel(doc.title)
                    .accessibilityValue(selected.contains(doc.id) ? "Selecionado" : "Não selecionado")
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                }
            }
        }
    }

    private func docRow(_ doc: VitaDocument) -> some View {
        let isOn = selected.contains(doc.id)
        return HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")  // ds-allow: check de seleção (área de toque)
                .font(.system(size: 22))  // ds-allow: área de toque
                .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: VitaTokens.Spacing.xs) {
                    Text(fileExt(doc))
                    if activeSubjects.isEmpty, let subject = doc.subjectName {
                        Text("·")
                        Text(subject).lineLimit(1)
                    }
                }
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(VitaTokens.Spacing.md)
        .glassCard(cornerRadius: 16)
    }

    private var selectionCTA: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)

            Button {
                Task { await run() }
            } label: {
                Text(selected.isEmpty ? "Selecione um material" : "\(actionVerb) (\(selected.count))")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(selected.isEmpty ? VitaColors.textSecondary : VitaColors.surface)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(selected.isEmpty ? VitaColors.surfaceCard : VitaColors.accent)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .stroke(
                                selected.isEmpty ? VitaColors.glassBorder : VitaColors.accent.opacity(0.9),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing.lg)
        }
        .background(.ultraThinMaterial)
        .overlay {
            Rectangle()
                .fill(VitaModalTokens.goldTint)
                .allowsHitTesting(false)
        }
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
                .foregroundStyle(VitaColors.accent)
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
                    .background(Capsule().fill(VitaColors.accent))
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
                .foregroundStyle(VitaColors.accent)
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
                .foregroundStyle(VitaColors.accent)
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

    private var groups: [Group] {
        let buckets = Dictionary(grouping: docs) { $0.subjectName ?? "Sem matéria" }
        return buckets.keys.sorted().map { key in
            Group(subject: key, docs: buckets[key]!.sorted { $0.title < $1.title })
        }
    }

    /// Lista reage às pastas ligadas + busca. Nenhuma pasta ligada = todos os docs.
    private var visibleDocs: [VitaDocument] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return docs
            .filter { doc in
                activeSubjects.isEmpty || activeSubjects.contains(doc.subjectName ?? "Sem matéria")
            }
            .filter { doc in
                q.isEmpty || doc.title.lowercased().contains(q)
                    || (doc.subjectName?.lowercased().contains(q) ?? false)
            }
            .sorted {
                ($0.subjectName ?? "", $0.title) < ($1.subjectName ?? "", $1.title)
            }
    }

    private func selectedCount(in g: Group) -> Int {
        g.docs.reduce(0) { $0 + (selected.contains($1.id) ? 1 : 0) }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func importPickedFile(_ url: URL) {
        showFileImporter = false
        guard let data = try? Data(contentsOf: url) else {
            phase = .failed("Não consegui abrir esse arquivo.")
            return
        }
        guard data.count <= 20 * 1_024 * 1_024 else {
            phase = .failed("O arquivo precisa ter até 20 MB.")
            return
        }
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        Task { await runUploadedFile(data, fileName: url.lastPathComponent, mimeType: mimeType) }
    }

    private func runUploadedFile(_ data: Data, fileName: String, mimeType: String) async {
        phase = .working
        progressText = "Enviando o material..."
        do {
            let upload = try await container.api.uploadStudioSource(
                fileData: data, fileName: fileName, mimeType: mimeType
            )
            progressText = "Lendo o material..."
            let detail = try await container.api.waitForStudioSourceTerminal(id: upload.sourceId)
            guard detail.status == "ready" else {
                throw PickerError(message: detail.errorMessage
                    ?? "O processamento demorou mais que o esperado. Tenta de novo.")
            }
            progressText = "Gerando..."
            result = try await onGenerate([detail.id])
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func fileExt(_ doc: VitaDocument) -> String {
        doc.fileName.split(separator: ".").last.map { String($0).uppercased() } ?? "DOC"
    }

    private func load() async {
        isLoading = true; loadError = nil
        do {
            docs = try await container.api.getDocuments()
            // Veio de uma disciplina → já abre com a pasta dela ligada (o aluno
            // vê primeiro o material daquela matéria, não tudo).
            if activeSubjects.isEmpty, let s = initialSubjectName,
               docs.contains(where: { $0.subjectName == s }) {
                activeSubjects = [s]
            }
        }
        catch { loadError = "Não foi possível carregar teus materiais." }
        isLoading = false
    }

    // MARK: - Run (ensureSource com extração local -> onGenerate)

    private func run() async {
        let picked = docs.filter { selected.contains($0.id) }
        guard !picked.isEmpty else { return }
        phase = .working
        do {
            var sourceIds: [String] = []
            for (i, doc) in picked.enumerated() {
                progressText = "Lendo o material \(i + 1)/\(picked.count)..."
                // 1ª sondagem BEST-EFFORT: se já existe source pronto, volta na
                // hora. Office/externo sem texto retorna erro aqui (não é PDF nativo)
                // — NÃO abortamos: extraímos o texto (o /file já converte Office->PDF
                // via Gotenberg) e reenviamos. Rafael 2026-07-14.
                var resp = try? await container.api.ensureDocumentStudySource(documentId: doc.id)
                if resp?.status != "ready" {
                    guard let text = await extractPdfText(documentId: doc.id) else {
                        throw PickerError(message: resp?.errorMessage
                            ?? "Não consegui ler \"\(doc.title)\". Tenta abrir o material uma vez e gerar de novo.")
                    }
                    resp = try await container.api.ensureDocumentStudySource(
                        documentId: doc.id, extractedText: text
                    )
                }
                guard let ready = resp, ready.status == "ready" else {
                    throw PickerError(message: resp?.errorMessage
                        ?? "\"\(doc.title)\" não pôde ser processado.")
                }
                sourceIds.append(ready.studioSourceId)
            }
            progressText = "Gerando..."
            let r = try await onGenerate(sourceIds)
            result = r
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Extração PDFKit no aparelho (mesmo algoritmo do PdfViewer)

    /// Baixa o PDF autenticado (Cookie + X-Extension-Token, igual PdfViewer) e
    /// extrai o texto com PDFKit fora da main thread. nil = não deu (aí o caller
    /// mostra a errorMessage do servidor).
    private func extractPdfText(documentId: String, maxCharacters: Int = 90_000) async -> String? {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/documents/\(documentId)/file") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        if let token = await container.tokenStore.token {
            request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
            request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
        }
        if let forwardedHost = AppConfig.localForwardedHostHeader {
            request.setValue(forwardedHost, forHTTPHeaderField: "x-forwarded-host")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count >= 4, data[0] == 0x25, data[1] == 0x50, data[2] == 0x44, data[3] == 0x46
        else { return nil }

        return await Task.detached(priority: .userInitiated) {
            Self.extractText(from: data, maxCharacters: maxCharacters)
        }.value
    }

    private nonisolated static func extractText(from data: Data, maxCharacters: Int) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        var remaining = maxCharacters
        var parts: [String] = []
        for pageIndex in 0..<document.pageCount where remaining > 0 {
            guard let pageText = document.page(at: pageIndex)?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !pageText.isEmpty else { continue }
            let clipped = String(pageText.prefix(remaining))
            parts.append(clipped)
            remaining -= clipped.count
        }
        let text = parts.joined(separator: "\n\n--- página ---\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count >= 120 ? text : nil
    }
}
