import SwiftUI
import AVFoundation

// MARK: - Gravação de áudio no composer de card
//
// Rafael 2026-07-18: "pode ter a opção da pessoa gravar áudio, usando o microfone
// da Apple, e colocar em um card se quiser (fica um player, ela toca e sai o áudio)".
// O aluno grava pelo mic; salva em Documents/flashcard-audio/<uuid>.m4a; o card
// guarda a ref `userdoc:flashcard-audio/<uuid>.m4a` (portável) e toca com o mesmo
// FlashcardAudioSegment usado pela ausculta.

// MARK: - AudioRecorder (wrapper de AVAudioRecorder)

final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFile: URL?

    static func audioDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("flashcard-audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let fileURL = Self.audioDir().appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let r = try? AVAudioRecorder(url: fileURL, settings: settings) else { return }
        r.delegate = self
        r.record()
        recorder = r
        currentFile = fileURL
        isRecording = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let r = self.recorder else { return }
            self.elapsed = r.currentTime
        }
    }

    /// Para e devolve a ref `userdoc:…` pro card guardar (nil se nada gravado).
    @discardableResult
    func stop() -> String? {
        recorder?.stop()
        stopTimer()
        isRecording = false
        guard let file = currentFile else { return nil }
        currentFile = nil
        return "userdoc:flashcard-audio/\(file.lastPathComponent)"
    }

    /// Cancela e apaga o arquivo (usado ao descartar a gravação).
    func cancel() {
        recorder?.stop()
        if let f = currentFile { try? FileManager.default.removeItem(at: f) }
        currentFile = nil
        stopTimer()
        isRecording = false
        elapsed = 0
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    /// Apaga o arquivo de um src `userdoc:` (ao remover o áudio do card).
    static func deleteFile(for src: String) {
        guard let url = AudioClipPlayer.resolve(src) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - CardAudioRecorderView — controle no composer

struct CardAudioRecorderView: View {
    /// Ref `userdoc:…` do áudio anexado (nil = nenhum).
    @Binding var audioSrc: String?
    @StateObject private var recorder = AudioRecorder()
    @State private var showMicDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text("ÁUDIO (OPCIONAL)")
                .font(VitaTypography.labelSmall)
                .kerning(1.0)
                .foregroundStyle(VitaColors.accentLight.opacity(0.7))

            if recorder.isRecording {
                recordingBar
            } else if let src = audioSrc {
                attachedPlayer(src)
            } else {
                recordButton
            }
        }
        .alert("Microfone bloqueado", isPresented: $showMicDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Libere o acesso ao microfone em Ajustes para gravar áudio.")
        }
    }

    private var recordButton: some View {
        Button { requestAndRecord() } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone
                Text("Gravar áudio")
                    .font(VitaTypography.labelLarge)
                Spacer()
            }
            .foregroundStyle(VitaColors.accent)
            .padding(VitaTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VitaColors.glassBg, in: RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).stroke(VitaColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var recordingBar: some View {
        Button { audioSrc = recorder.stop() } label: {
            HStack(spacing: VitaTokens.Spacing.sm) {
                Circle().fill(VitaColors.danger).frame(width: 12, height: 12)
                Text("Gravando  \(timeString(recorder.elapsed))")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
                Spacer()
                Text("Parar")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.danger)
            }
            .padding(VitaTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(VitaColors.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg).stroke(VitaColors.danger.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func attachedPlayer(_ src: String) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            FlashcardAudioSegment(url: src)
            Button {
                AudioRecorder.deleteFile(for: src)
                audioSrc = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))  // ds-allow: ícone
                    .foregroundStyle(VitaColors.danger)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private func requestAndRecord() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted { recorder.start() } else { showMicDenied = true }
            }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
