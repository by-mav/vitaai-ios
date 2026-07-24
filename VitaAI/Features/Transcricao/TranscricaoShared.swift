import SwiftUI

// MARK: - Transcrição Colors (remapped to gold palette, unified with VitaColors)

enum TealColors {
    static let accent       = VitaColors.accent
    static let accentLight  = VitaColors.accentLight
    static let accentBright = VitaColors.accentHover

    static let cardBg = LinearGradient(
        colors: [
            Color(red: 12/255, green: 9/255, blue: 7/255, opacity: 0.94),
            Color(red: 14/255, green: 11/255, blue: 8/255, opacity: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBg = Color.clear

    static let badgeGreen     = VitaColors.dataGreen
    static let badgePending   = VitaColors.accentHover
    static let badgeRecording = VitaColors.dataRed
}

// MARK: - Teal Background

struct TealBackground: View {
    var body: some View {
        Color.clear.ignoresSafeArea()
    }
}

// MARK: - Recording Status Enum (for display)

enum RecordingStatus {
    case transcribed
    case pending
    case recording
    /// Upload travou ou Whisper desistiu — backend marcou status="failed".
    /// UI: badge vermelho "Falhou" + ação Tentar de novo / Remover.
    case failed
}

// MARK: - Status Badge

struct TranscricaoStatusBadge: View {
    let status: RecordingStatus

    var body: some View {
        HStack(spacing: 5) {
            if status == .transcribed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
            } else if status == .pending {
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(foregroundColor)
                    .frame(width: 9, height: 9)
            } else if status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
            } else {
                Circle().fill(foregroundColor).frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.2)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(backgroundColor)
            }
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 0.5)
        )
    }

    private var label: String {
        switch status {
        case .transcribed: return "Transcrito"
        case .pending:     return "Processando"
        case .recording:   return "Gravando"
        case .failed:      return "Falhou"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .transcribed: return VitaColors.accentLight
        case .pending:     return VitaColors.accentLight.opacity(0.70)
        case .recording:   return TealColors.badgeRecording.opacity(0.85)
        case .failed:      return VitaColors.dataRed
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .transcribed: return VitaColors.accent.opacity(0.08)
        case .pending:     return VitaColors.accent.opacity(0.06)
        case .recording:   return TealColors.badgeRecording.opacity(0.10)
        case .failed:      return VitaColors.dataRed.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch status {
        case .transcribed: return VitaColors.accent.opacity(0.22)
        case .pending:     return VitaColors.accent.opacity(0.18)
        case .recording:   return TealColors.badgeRecording.opacity(0.20)
        case .failed:      return VitaColors.dataRed.opacity(0.30)
        }
    }
}

// MARK: - Mode Toggle

struct TranscricaoModeToggle: View {
    @Binding var selected: TranscricaoRecordingMode

    var body: some View {
        // Mesmo seletor content-sized da Jornada, sem uma segunda label de
        // seção competindo com o cronômetro.
        HStack {
            Spacer()

            HStack(spacing: VitaTokens.Spacing.xxs) {
                ForEach(TranscricaoRecordingMode.allCases, id: \.self) { mode in
                    let isSelected = selected == mode
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(VitaTypography.labelMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSelected ? VitaColors.surface : VitaColors.textSecondary)
                            .padding(.horizontal, VitaTokens.Spacing.md)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(isSelected ? VitaColors.accent : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(VitaTokens.Spacing.xxs)
            .background(Capsule().fill(VitaColors.glassBg))
            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 0.5))
        }
        // zIndex garante que o ModeToggle está acima de qualquer vizinho no
        // stack pai — hit test vai pegar esse rectangle antes do mascote.
        .zIndex(1)
    }
}

// MARK: - Recording Mode (shared enum)

enum TranscricaoRecordingMode: String, CaseIterable {
    case offline = "Offline"
    case live = "Ao Vivo"
}

// MARK: - Processing Toast (inline card, not full-screen)


// MARK: - Error Phase

struct TranscricaoErrorPhase: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(TealColors.badgeRecording.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.microphone.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(TealColors.badgeRecording.opacity(0.8))
            }

            Text("Algo deu errado")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.90))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(TealColors.badgeRecording.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tentar novamente")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [TealColors.accent.opacity(0.85), TealColors.accent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: TealColors.accent.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Helper

func formatTranscricaoElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
