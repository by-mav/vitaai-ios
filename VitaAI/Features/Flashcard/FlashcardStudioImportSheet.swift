import SwiftUI
import UniformTypeIdentifiers

/// "Criar do teu material" — PDF/slides/imagem vira baralho de flashcards.
/// Fluxo: fileImporter -> upload (studio/upload) -> poll source ready ->
/// generate (type=flashcards) -> add-to-deck (nome do arquivo) -> onDone.
/// Backend ja existia (Studio pipeline); isto e so a porta de entrada. Rafael 2026-07-10.
struct FlashcardStudioImportSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    /// Chamado com (deckId, quantidadeDeCards) quando o baralho novo esta pronto.
    let onDone: (String, Int) -> Void

    enum Stage: Equatable {
        case pick
        case uploading
        case processing
        case generating
        case saving
        case done(deckId: String, count: Int)
        case failed(String)
    }

    @State private var stage: Stage = .pick
    @State private var showImporter = false
    @State private var fileName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surface.ignoresSafeArea()
                content
            }
            .navigationTitle("Criar do teu material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await run(url: url) }
            case .failure(let err):
                stage = .failed(err.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .pick:
            VStack(spacing: VitaTokens.Spacing.lg) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 44))  // ds-allow: icone hero do empty state
                    .foregroundStyle(VitaColors.accent)
                Text("Escolhe um PDF, slide ou foto de material")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("O Vita le o conteudo e cria um baralho de flashcards pra voce")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    showImporter = true
                } label: {
                    Text("Escolher arquivo")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.surface)
                        .padding(.horizontal, VitaTokens.Spacing._2xl)
                        .padding(.vertical, VitaTokens.Spacing.md)
                        .background(Capsule().fill(VitaColors.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VitaTokens.Spacing._3xl)

        case .uploading, .processing, .generating, .saving:
            VStack(spacing: VitaTokens.Spacing.lg) {
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(1.4)
                Text(stageLabel)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                if !fileName.isEmpty {
                    Text(fileName)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }
            }

        case .done(let deckId, let count):
            VStack(spacing: VitaTokens.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))  // ds-allow: icone hero do estado final
                    .foregroundStyle(VitaColors.accent)
                Text("\(count) cards criados")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("Baralho novo em \u{201C}Seus baralhos\u{201D}")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                Button {
                    onDone(deckId, count)
                    dismiss()
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

        case .failed(let msg):
            VStack(spacing: VitaTokens.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))  // ds-allow: icone de erro
                    .foregroundStyle(VitaColors.dataRed)
                Text("Nao rolou")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(msg)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Tentar de novo") { stage = .pick }
                    .foregroundStyle(VitaColors.accent)
            }
            .padding(.horizontal, VitaTokens.Spacing._3xl)
        }
    }

    private var stageLabel: String {
        switch stage {
        case .uploading: return "Enviando arquivo..."
        case .processing: return "Lendo o material..."
        case .generating: return "Criando flashcards..."
        case .saving: return "Montando o baralho..."
        default: return ""
        }
    }

    // MARK: - Pipeline

    private func run(url: URL) async {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        fileName = url.lastPathComponent
        guard let data = try? Data(contentsOf: url) else {
            stage = .failed("Nao consegui ler o arquivo")
            return
        }
        guard data.count <= 20 * 1024 * 1024 else {
            stage = .failed("Arquivo maior que 20MB")
            return
        }

        let mime: String
        switch url.pathExtension.lowercased() {
        case "pdf": mime = "application/pdf"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        default: mime = "application/pdf"
        }

        do {
            stage = .uploading
            let up = try await container.api.uploadStudioSource(fileData: data, fileName: fileName, mimeType: mime)

            stage = .processing
            try await pollUntilReady(sourceId: up.sourceId)

            stage = .generating
            let output = try await container.api.generateStudioOutput(sourceId: up.sourceId, outputType: "flashcards")
            guard let cards = output.content?.flashcards, !cards.isEmpty else {
                stage = .failed("O material nao rendeu flashcards — tenta um arquivo com mais texto")
                return
            }

            stage = .saving
            let deckTitle = (fileName as NSString).deletingPathExtension
            let added = try await container.api.addStudioFlashcardsToDeck(cards: cards, deckTitle: deckTitle)
            stage = .done(deckId: added.deckId, count: added.addedCount)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    /// Pipeline de processamento e async (upload dispara e retorna) — poll a cada 2s, max 120s.
    private func pollUntilReady(sourceId: String) async throws {
        for _ in 0..<60 {
            let detail = try await container.api.getStudioSourceDetail(id: sourceId)
            if detail.status == "ready" { return }
            if detail.status == "error" {
                throw NSError(domain: "studio", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: detail.errorMessage ?? "Falha ao processar o arquivo",
                ])
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw NSError(domain: "studio", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Processamento demorou demais — tenta de novo",
        ])
    }
}
