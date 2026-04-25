import SwiftUI

/// Goodnotes-style horizontal tab bar showing every open PDF in the workspace.
/// Each tab: file icon + truncated title + close button. Active tab has gold
/// accent. Trailing "+ tab" button opens the file picker.
///
/// Layout sits between the PdfToolbar (top) and the PDFView content. Hides
/// itself when only 1 tab is open AND showWhenSingle = false (we currently
/// keep it always-visible like Goodnotes does, so user can hit the + tab).
struct PdfTabBar: View {
    let openDocs: [OpenPdfDocument]
    let activeId: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onAdd: () -> Void
    let onCloseOthers: ((UUID) -> Void)?
    let onCloseAll: (() -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(openDocs) { doc in
                        PdfTabChip(
                            doc: doc,
                            isActive: doc.id == activeId,
                            onTap: { onSelect(doc.id) },
                            onClose: { onClose(doc.id) },
                            onCloseOthers: onCloseOthers.map { fn in { fn(doc.id) } },
                            onCloseAll: onCloseAll
                        )
                        .id(doc.id)
                    }

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .frame(width: 32, height: 30)
                            .background(VitaColors.surfaceCard.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(VitaColors.accentSubtle.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Abrir outro documento")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .onChange(of: activeId) { _, newId in
                guard let newId else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.accentSubtle.opacity(0.35))
                .frame(height: 0.5)
        }
    }
}

private struct PdfTabChip: View {
    let doc: OpenPdfDocument
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    let onCloseOthers: (() -> Void)?
    let onCloseAll: (() -> Void)?

    private var truncatedTitle: String {
        let max = 18
        if doc.title.count <= max { return doc.title }
        return String(doc.title.prefix(max)) + "…"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? VitaColors.accent : VitaColors.textSecondary)

            Text(truncatedTitle)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? VitaColors.textPrimary : VitaColors.textSecondary)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isActive ? VitaColors.textSecondary : VitaColors.textTertiary)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(isActive ? VitaColors.accentSubtle.opacity(0.4) : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar \(doc.title)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? VitaColors.accentSubtle.opacity(0.55) : VitaColors.surfaceCard.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? VitaColors.accent.opacity(0.6) : VitaColors.accentSubtle.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: isActive ? VitaColors.accent.opacity(0.18) : .clear, radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            if let onCloseOthers {
                Button("Fechar outras", role: .destructive, action: onCloseOthers)
            }
            if let onCloseAll {
                Button("Fechar todas", role: .destructive, action: onCloseAll)
            }
        }
    }
}
