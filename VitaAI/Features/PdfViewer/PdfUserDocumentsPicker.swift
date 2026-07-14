import SwiftUI

/// Goodnotes-style document picker scoped to the user's Vita library.
/// Replaces the iOS Files picker (which was wrong UX — it pointed at iCloud
/// Drive / device-local files, not at the user's actual Vita PDFs synced
/// from Canvas / uploads).
///
/// Layout GOLD (Rafael 2026-07-13): header custom + busca dourada + cards
/// glass agrupados por matéria — sem List nativo/insetGrouped (que dava ar
/// "antigo"). Tap numa linha abre como novo tab de PDF.
struct PdfUserDocumentsPicker: View {
    let onSelect: (URL, String, String?, String?) -> Void
    let onCancel: () -> Void

    @Environment(\.appContainer) private var container
    @State private var docs: [VitaDocument] = []
    @State private var isLoading: Bool = true
    @State private var loadError: String? = nil
    @State private var searchText: String = ""
    @State private var showFilesPicker: Bool = false

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                searchField
                content
            }
        }
        // vita-modals-ignore: PdfTabDocumentPicker é UIViewControllerRepresentable nativo (UIDocumentPickerViewController) — VitaSheet quebra apresentação do system picker
        .sheet(isPresented: $showFilesPicker) {
            PdfTabDocumentPicker { pickedURL in
                showFilesPicker = false
                onSelect(pickedURL, pickedURL.lastPathComponent, nil, nil)
            }
        }
        .task { await load() }
    }

    // MARK: - Header custom (sem nav bar nativa)

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancelar")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer()
            Text("Abrir documento")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
            Button { showFilesPicker = true } label: {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone da toolbar
                    .foregroundStyle(VitaColors.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar documento", text: $searchText)
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(VitaTypography.bodyMedium)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VitaColors.glassBg))  // ds-allow: campo de busca
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(VitaColors.glassBorder, lineWidth: 0.5))  // ds-allow: campo de busca
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            VitaMascotEquipped(state: .thinking, size: 96)
            Spacer()
        } else if let err = loadError {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))  // ds-allow: ícone de estado
                    .foregroundStyle(VitaColors.dataRed)
                Text(err)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Tentar novamente") { Task { await load() } }
                    .buttonStyle(.borderedProminent)
                    .tint(VitaColors.accent)
            }
            Spacer()
        } else if filteredGrouped.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))  // ds-allow: ícone de estado
                    .foregroundStyle(VitaColors.textTertiary)
                Text(searchText.isEmpty ? "Nenhum documento" : "Nenhum resultado para \"\(searchText)\"")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(filteredGrouped, id: \.subject) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.subject.uppercased())
                                .font(VitaTypography.labelSmall)
                                .tracking(0.6)
                                .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(group.docs.enumerated()), id: \.element.id) { idx, doc in
                                    if idx > 0 {
                                        Rectangle().fill(VitaColors.glassBorder).frame(height: 0.5)
                                            .padding(.horizontal, 14)
                                    }
                                    Button(action: { select(doc) }) { DocRow(doc: doc) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VitaColors.glassBg))  // ds-allow: card glass da lista
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VitaColors.glassBorder, lineWidth: 0.5))  // ds-allow: card glass da lista
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Data shaping

    private struct Group {
        let subject: String
        let docs: [VitaDocument]
    }

    private var filteredGrouped: [Group] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty
            ? docs
            : docs.filter { $0.title.lowercased().contains(q) || ($0.subjectName?.lowercased().contains(q) ?? false) }

        let buckets = Dictionary(grouping: filtered) { $0.subjectName ?? "Sem matéria" }
        return buckets.keys.sorted().map { key in
            Group(subject: key, docs: buckets[key]!.sorted { $0.title < $1.title })
        }
    }

    // MARK: - Actions

    private func select(_ doc: VitaDocument) {
        let urlString = "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file"
        guard let url = URL(string: urlString) else { return }
        onSelect(url, doc.title, doc.id, doc.studioSourceId)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            docs = try await container.api.getDocuments()
        } catch {
            loadError = "Não foi possível carregar seus documentos. Verifique sua conexão."
        }
        isLoading = false
    }
}

private struct DocRow: View {
    let doc: VitaDocument

    private var icon: String {
        let ext = doc.fileName.split(separator: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.text.fill"
        case "docx", "doc": return "doc.fill"
        case "xlsx", "xls": return "tablecells.fill"
        case "pptx", "ppt": return "rectangle.on.rectangle.fill"
        default: return "doc"
        }
    }

    private var ext: String {
        guard let last = doc.fileName.split(separator: ".").last else { return "" }
        return String(last).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))  // ds-allow: ícone do arquivo
                .foregroundStyle(VitaColors.accent)
                .frame(width: 34, height: 34)
                .background(VitaColors.accentSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // ds-allow: ícone do arquivo

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)

                if !ext.isEmpty {
                    Text(ext)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))  // ds-allow: chevron
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
