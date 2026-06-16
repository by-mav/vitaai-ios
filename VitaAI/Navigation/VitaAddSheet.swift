import SwiftUI

// VitaAddSheet — gaveta "+" do Vita (portada de PixioAddSheet, re-skin dourado).
// NAO cria: SOBE arquivos pro espaco do usuario no R2 e o LLM categoriza.
// Cada linha -> host abre o seletor nativo do tipo e dispara o upload existente
// (ExamUploadSheet / TranscricaoRecorder / PdfDocumentPicker / documents-upload).
// Pixio e referencia CONGELADA; so a cara cruza.
// SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
struct VitaAddSheet: View {
    var onSelect: (Kind) -> Void
    var bottomFill: CGFloat = 0

    enum Kind: Hashable {
        case prova, documento, transcricao, nota
        var testID: String {
            switch self {
            case .prova: return "prova"
            case .documento: return "documento"
            case .transcricao: return "transcricao"
            case .nota: return "nota"
            }
        }
    }

    private struct Item: Identifiable {
        let id = UUID()
        let kind: Kind
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
    }

    private let items: [Item] = [
        Item(kind: .prova, icon: "doc.text.viewfinder", color: VitaShellColor.catGreen,
             title: "Prova", subtitle: "Fotografe a prova e eu leio sozinho"),
        Item(kind: .documento, icon: "doc.text.fill", color: VitaShellColor.catBlue,
             title: "Trabalho / PDF", subtitle: "Suba um PDF e eu organizo"),
        Item(kind: .transcricao, icon: "waveform", color: VitaShellColor.catCyan,
             title: "Transcricao", subtitle: "Grave a aula e eu transcrevo"),
        Item(kind: .nota, icon: "note.text", color: VitaShellColor.catAmber,
             title: "Nota", subtitle: "Anotacao rapida de estudo"),
    ]

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 26,
            bottomLeadingRadius: bottomFill > 0 ? 0 : 26,
            bottomTrailingRadius: bottomFill > 0 ? 0 : 26,
            topTrailingRadius: 26,
            style: .continuous
        )
        return VStack(spacing: VitaShellSpacing.xs) {
            ForEach(items) { item in row(item) }
        }
        .padding(VitaShellSpacing.sm)
        .padding(.bottom, bottomFill)
        .background(shape.fill(VitaShellColor.pageLight))
        .overlay(shape.stroke(VitaShellColor.borderLight.opacity(0.5), lineWidth: 0.5))
        .shadow(color: VitaShellColor.textLight.opacity(0.16), radius: 22, y: 8)
        .accessibilityIdentifier("quick_add_drawer")
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        Button {
            VitaShellHaptics.tap()
            onSelect(item.kind)
        } label: {
            HStack(spacing: VitaShellSpacing.md) {
                ZStack {
                    Circle().fill(item.color).frame(width: 40, height: 40)
                    Image(systemName: item.icon)
                        .font(VitaShellType.cardTitle)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: VitaShellSpacing.xxs) {
                    Text(item.title)
                        .font(VitaShellType.body)
                        .foregroundStyle(VitaShellColor.textLight)
                    Text(item.subtitle)
                        .font(VitaShellType.caption)
                        .foregroundStyle(VitaShellColor.textLightMuted)
                }
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(VitaShellType.cardTitle)
                    .foregroundStyle(VitaShellColor.textLight)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(VitaShellColor.cardLight))
                    .overlay(Circle().stroke(VitaShellColor.borderLight, lineWidth: 0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adicionar \(item.title)")
        .accessibilityIdentifier("quick_add_\(item.kind.testID)")
        .padding(.horizontal, VitaShellSpacing.md)
        .padding(.vertical, VitaShellSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VitaShellColor.cardLight))
    }
}
