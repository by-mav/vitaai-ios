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

// MARK: - AudioRecordSheet — gravação aberta pelo mic da BARRA do editor
//
// Rafael 2026-07-18: o mic fica na barra de formatação (do lado da imagem), NÃO
// numa seção separada. Toca no mic → abre este sheet → grava → "Anexar" insere
// a tag `<audio src="userdoc:…">` no cursor (igual a imagem); o player renderiza
// no card.

struct AudioRecordSheet: View {
    var onAttach: (String) -> Void
    var onCancel: () -> Void

    @StateObject private var recorder = AudioRecorder()
    @State private var recordedSrc: String?
    @State private var showMicDenied = false

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.xl) {
            Text("Gravar áudio")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.top, VitaTokens.Spacing.xl)

            Text(timeString(recorder.elapsed))
                .font(.system(size: 44, weight: .semibold))  // ds-allow: cronômetro grande do gravador
                .monospacedDigit()
                .foregroundStyle(recorder.isRecording ? VitaColors.danger : VitaColors.textPrimary)

            Button { toggle() } label: {
                ZStack {
                    Circle()
                        .fill((recorder.isRecording ? VitaColors.danger : VitaColors.accent).opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36, weight: .semibold))  // ds-allow: ícone do botão gravar
                        .foregroundStyle(recorder.isRecording ? VitaColors.danger : VitaColors.accent)
                }
            }
            .buttonStyle(.plain)
            .disabled(recordedSrc != nil)

            Text(hint)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            Spacer()

            HStack(spacing: VitaTokens.Spacing.md) {
                Button {
                    recorder.cancel()
                    onCancel()
                } label: {
                    Text("Cancelar")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassCard(cornerRadius: VitaTokens.Radius.md)
                }
                .buttonStyle(.plain)

                Button {
                    if let src = recordedSrc { onAttach(src) }
                } label: {
                    Text("Anexar")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.surface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(VitaColors.accent.opacity(recordedSrc == nil ? 0.4 : 1),
                                    in: RoundedRectangle(cornerRadius: VitaTokens.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(recordedSrc == nil)
            }
            .padding(.bottom, VitaTokens.Spacing.xl)
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surfaceElevated.ignoresSafeArea())
        .alert("Microfone bloqueado", isPresented: $showMicDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Libere o acesso ao microfone em Ajustes para gravar áudio.")
        }
    }

    private var hint: String {
        if recordedSrc != nil { return "Gravado. Toque em Anexar." }
        return recorder.isRecording ? "Gravando… toque pra parar." : "Toque no microfone pra gravar."
    }

    private func toggle() {
        if recorder.isRecording {
            recordedSrc = recorder.stop()
        } else if recordedSrc == nil {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { recorder.start() } else { showMicDenied = true }
                }
            }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
