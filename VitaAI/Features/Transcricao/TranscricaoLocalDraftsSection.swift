import SwiftUI

// MARK: - TranscricaoLocalDraftsSection
//
// Lista de gravações que ainda vivem só no device — user marcou "Só rascunho
// local" no toggle antes de gravar. Cada card mostra título + duração + tamanho
// + 2 ações: Transcrever agora (promove pro pipeline R2+Whisper+LLM) ou Apagar.
//
// Sessão cinza ("Rascunhos locais · 📱") separada da lista cloud pra deixar
// claro que esses áudios NÃO foram transcritos nem sincronizados.

struct TranscricaoLocalDraftsSection: View {
    let drafts: [LocalRecording]
    let onTranscribe: (LocalRecording) -> Void
    let onDelete: (LocalRecording) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))

                Text("RASCUNHOS LOCAIS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .tracking(0.5)

                Text("\(drafts.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 16)

            VStack(spacing: 6) {
                ForEach(drafts) { draft in
                    LocalDraftCard(
                        draft: draft,
                        onTranscribe: { onTranscribe(draft) },
                        onDelete: { onDelete(draft) }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Card

private struct LocalDraftCard: View {
    let draft: LocalRecording
    let onTranscribe: () -> Void
    let onDelete: () -> Void

    private var durationLabel: String {
        let m = draft.durationSeconds / 60
        let s = draft.durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sizeLabel: String {
        let mb = Double(draft.fileSize) / 1_048_576.0
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(draft.fileSize / 1024) KB"
    }

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        if Calendar.current.isDateInToday(draft.createdAt) {
            fmt.dateFormat = "HH:mm"
            return "Hoje \(fmt.string(from: draft.createdAt))"
        }
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: draft.createdAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(dateLabel)
                    Text("·")
                    Text(durationLabel)
                    Text("·")
                    Text(sizeLabel)
                }
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
            }

            Spacer()

            // Actions menu (⋯)
            Menu {
                Button {
                    onTranscribe()
                } label: {
                    Label("Transcrever agora", systemImage: "sparkles")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Apagar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
}
