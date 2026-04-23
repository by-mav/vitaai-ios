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

    private var hasInFlight: Bool {
        drafts.contains(where: { isInFlight($0.cloudStatus) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: hasInFlight ? "arrow.up.circle" : "iphone")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hasInFlight ? VitaColors.accent : VitaColors.textWarm.opacity(0.55))

                Text(hasInFlight ? "EM PROCESSAMENTO" : "RASCUNHOS LOCAIS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hasInFlight ? VitaColors.accent : VitaColors.textWarm.opacity(0.55))
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

/// Se `cloudStatus` ≠ nil && ≠ "ready" && ≠ "failed", a entry tá no meio do
/// pipeline cloud em background. UI mostra spinner + label correspondente.
fileprivate func isInFlight(_ status: String?) -> Bool {
    guard let s = status else { return false }
    return s == "uploading" || s == "transcribing" || s == "summarizing" || s == "generating_flashcards"
}

fileprivate func inFlightLabel(_ status: String?) -> String {
    switch status {
    case "uploading": return "Enviando áudio"
    case "transcribing": return "Transcrevendo"
    case "summarizing": return "Resumindo"
    case "generating_flashcards": return "Gerando flashcards"
    default: return ""
    }
}

private struct LocalDraftCard: View {
    let draft: LocalRecording
    let onTranscribe: () -> Void
    let onDelete: () -> Void

    private var inFlight: Bool { isInFlight(draft.cloudStatus) }
    private var failed: Bool { draft.cloudStatus == "failed" }

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
            // Icon (spinner quando upload em voo)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 36, height: 36)
                if inFlight {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .scaleEffect(0.8)
                } else if failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.80))
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                if inFlight {
                    HStack(spacing: 6) {
                        Text(inFlightLabel(draft.cloudStatus))
                            .foregroundStyle(VitaColors.accent)
                        Text("·")
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        Text(durationLabel)
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }
                    .font(.system(size: 11, weight: .medium))
                } else if failed {
                    HStack(spacing: 6) {
                        Text("Falhou — toque pra tentar de novo")
                            .foregroundStyle(Color.red.opacity(0.80))
                    }
                    .font(.system(size: 11, weight: .medium))
                } else {
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
            }

            Spacer()

            // Actions menu (⋯)
            Menu {
                if !inFlight {
                    Button {
                        onTranscribe()
                    } label: {
                        Label(failed ? "Tentar novamente" : "Transcrever agora", systemImage: "sparkles")
                    }
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
                        .stroke(inFlight ? VitaColors.accent.opacity(0.35) : Color.white.opacity(0.05), lineWidth: inFlight ? 1.0 : 0.5)
                )
        )
    }
}
