import SwiftUI
import AVFoundation

// MARK: - FlashcardAudioSegment — player de áudio inline no card
//
// Rafael 2026-07-18: "ausculta com som é o que os concorrentes têm". Os cards de
// ausculta cardíaca já trouxeram os .mp3 na extração (FlashcardMedia/medicina/*.mp3)
// + a tag <audio src="..."> no conteúdo — só faltava o app TOCAR. Este é o player:
// um botão play/pause + barra de progresso, estilo Vita. Serve tanto pra áudio
// EMBUTIDO (bundle) quanto pra áudio GRAVADO pelo usuário (caminho absoluto).

struct FlashcardAudioSegment: View {
    /// "medicina/07 Apex….mp3" (bundle FlashcardMedia) OU caminho de arquivo
    /// absoluto (áudio gravado pelo usuário em Documents).
    let url: String
    @StateObject private var player = AudioClipPlayer()

    var body: some View {
        HStack(spacing: 14) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))  // ds-allow: tamanho óptico do controle de áudio
                    .foregroundStyle(player.isReady ? VitaColors.accent : VitaColors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!player.isReady)

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: player.progress)
                    .tint(VitaColors.accent)
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))  // ds-allow: ícone
                    Text(player.isReady ? player.timeLabel : "Áudio indisponível")
                        .font(VitaTypography.labelSmall)
                        .monospacedDigit()
                }
                .foregroundStyle(VitaColors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.surfaceCard.opacity(0.6), in: RoundedRectangle(cornerRadius: VitaTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: VitaTokens.Radius.md).stroke(VitaColors.glassBorder, lineWidth: 1))
        .onAppear { player.load(url: url) }
        .onDisappear { player.stop() }
    }
}

// MARK: - AudioClipPlayer — wrapper de AVAudioPlayer observável

final class AudioClipPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var progress: Double = 0
    @Published var timeLabel = "0:00"

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: String) {
        guard player == nil else { return }
        guard let fileURL = Self.resolve(url),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            isReady = false
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        guard let p = try? AVAudioPlayer(contentsOf: fileURL) else { isReady = false; return }
        p.delegate = self
        p.prepareToPlay()
        player = p
        isReady = true
        updateLabel()
    }

    /// Ref relativa = mídia embutida (FlashcardMedia). Caminho absoluto/`file:` =
    /// áudio gravado pelo usuário.
    private static func resolve(_ url: String) -> URL? {
        if url.hasPrefix("file://") { return URL(string: url) }
        if url.hasPrefix("/") { return URL(fileURLWithPath: url) }
        guard let base = Bundle.main.resourceURL else { return nil }
        return base.appendingPathComponent("FlashcardMedia").appendingPathComponent(url)
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause(); isPlaying = false; stopTimer()
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play(); isPlaying = true; startTimer()
        }
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        progress = 0
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func tick() {
        guard let player else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        updateLabel()
    }

    private func updateLabel() {
        guard let player else { return }
        let cur = Int(player.currentTime), dur = Int(player.duration)
        timeLabel = "\(cur / 60):\(String(format: "%02d", cur % 60)) / \(dur / 60):\(String(format: "%02d", dur % 60))"
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        stopTimer()
        player.currentTime = 0
        updateLabel()
    }
}
