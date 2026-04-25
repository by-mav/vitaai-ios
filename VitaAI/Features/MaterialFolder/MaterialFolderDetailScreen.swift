import SwiftUI

// MARK: - MaterialFolderDetailScreen
//
// Lista os documentos dentro de uma pasta de materiais (Slides, Provas,
// Transcrições, Plano de ensino, custom, etc.). Navegação: tap num card
// de pasta na DisciplineDetailScreen empurra esta tela na NavigationStack.
//
// Backend: GET /api/folders/{id}/documents — newest first.

struct MaterialFolderDetailScreen: View {
    let folderId: String
    let folderName: String
    let folderIcon: String
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router
    @State private var documents: [VitaDocument] = []
    @State private var isLoading = true
    @State private var error: String?

    private var goldPrimary: Color { VitaColors.accentHover }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.40) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity)
                } else if let error {
                    errorState(message: error)
                } else if documents.isEmpty {
                    emptyState
                } else {
                    docsList
                }
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await load() }
        .task { await load() }
        .trackScreen("MaterialFolderDetail", extra: ["folder_id": folderId])
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: folderIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(goldPrimary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(goldPrimary.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(folderName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(textPrimary)
                if !documents.isEmpty {
                    Text("\(documents.count) \(documents.count == 1 ? "documento" : "documentos")")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                }
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Documents list

    private var docsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(documents.enumerated()), id: \.element.id) { idx, doc in
                if idx > 0 {
                    Rectangle()
                        .fill(glassBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)
                }
                Button {
                    router.navigate(to: .pdfViewer(
                        url: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file",
                        title: doc.title.isEmpty ? doc.fileName : doc.title
                    ))
                } label: {
                    docRow(doc)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(cornerRadius: 14)
    }

    private func docRow(_ doc: VitaDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: docIcon(doc.fileName))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(goldPrimary.opacity(0.80))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(goldPrimary.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.isEmpty ? doc.fileName : doc.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let date = doc.createdAt, let formatted = formatRelative(date) {
                    Text(formatted)
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Empty + error states

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: folderIcon)
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(goldPrimary.opacity(0.40))
            Text("Pasta vazia")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(textPrimary)
            Text("Os documentos aparecem aqui quando o portal sincronizar ou quando você fizer upload.")
                .font(.system(size: 12))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(VitaColors.dataAmber)
            Text("Erro ao carregar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        error = nil
        do {
            let resp = try await container.api.listFolderDocuments(folderId: folderId)
            documents = resp.documents
        } catch {
            self.error = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    private func docIcon(_ fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".pdf") { return "doc.fill" }
        if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") { return "rectangle.on.rectangle" }
        if lower.hasSuffix(".docx") || lower.hasSuffix(".doc") { return "doc.text.fill" }
        if lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") { return "tablecells" }
        if lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") { return "play.rectangle.fill" }
        if lower.hasSuffix(".mp3") || lower.hasSuffix(".m4a") || lower.hasSuffix(".wav") { return "waveform" }
        return "doc"
    }

    private func formatRelative(_ iso: String) -> String? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        fmt2.formatOptions = [.withInternetDateTime]
        guard let date = fmt.date(from: iso) ?? fmt2.date(from: iso) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
