import SwiftUI
import PDFKit

// MARK: - PdfBookmarksListSheet
//
// Lista TODAS as páginas marcadas no documento atual (sorted ASC).
// Cada row: thumbnail mini + número + label da página (PDFPage.label) +
// botão remover. Tap → onJumpToPage callback.
//
// Persistência já é feita pelo PdfViewerViewModel (file-based by hash) — esta
// sheet só lê `viewModel.bookmarkedPages` e dispara `toggleBookmark(forPage:)`
// pra remover.

struct PdfBookmarksListSheet: View {
    let document: PDFDocument
    let bookmarkedPages: Set<Int>
    let onJumpToPage: (Int) -> Void
    let onRemoveBookmark: (Int) -> Void

    private var sortedPages: [Int] {
        Array(bookmarkedPages).sorted()
    }

    var body: some View {
        VitaSheet(title: "Marcações") {
            if sortedPages.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bookmark.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Nenhuma página marcada")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Text("Use o botão de bookmark na toolbar pra marcar referências.")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedPages, id: \.self) { pageIdx in
                    BookmarkRow(
                        document: document,
                        pageIndex: pageIdx,
                        onTap: { onJumpToPage(pageIdx) },
                        onRemove: { onRemoveBookmark(pageIdx) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Single bookmark row

private struct BookmarkRow: View {
    let document: PDFDocument
    let pageIndex: Int
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var thumbnail: UIImage? = nil

    private var page: PDFPage? { document.page(at: pageIndex) }
    private var pageLabel: String { page?.label ?? "" }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    thumbView
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Página \(pageIndex + 1)")
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                        if !pageLabel.isEmpty && pageLabel != "\(pageIndex + 1)" {
                            Text(pageLabel)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .help("Remover marcação")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VitaColors.surfaceCard.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder.opacity(0.4), lineWidth: 0.5)
        )
        .task { await renderThumb() }
    }

    @ViewBuilder
    private var thumbView: some View {
        if let img = thumbnail {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(VitaColors.glassBorder.opacity(0.5), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(VitaColors.surface.opacity(0.5))
                .frame(width: 44, height: 56)
        }
    }

    private func renderThumb() async {
        guard thumbnail == nil, let page else { return }
        let size = CGSize(width: 88, height: 112) // 2x for retina
        let img = await Task.detached(priority: .userInitiated) {
            page.thumbnail(of: size, for: .mediaBox)
        }.value
        await MainActor.run { thumbnail = img }
    }
}
