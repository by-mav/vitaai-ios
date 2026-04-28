import SwiftUI
import AVFoundation
import OSLog

// MARK: - PdfAudioRecorder
//
// Notability-style audio + annotation sync. Aluno toca "Gravar", AVAudioRecorder
// grava .m4a no Documents/pdf_audio/<fileHash>.m4a. Toda anotação criada durante
// a gravação registra timestamp em <fileHash>_timeline.json. Depois, replay
// toca o áudio + destaca anotações quando o currentTime cruza o timestamp.
//
// Architecture (3 layers):
// 1. AVAudioSession.playAndRecord — permite gravar e reproduzir simultâneo.
//    Workaround conhecido: setar .playback durante playback e .record durante
//    gravação evita o bug de "volume baixo" em playAndRecord puro (Apple Forums
//    thread/108435).
// 2. AVAudioRecorder com AAC m4a (settings recomendadas Apple: 44.1kHz, mono,
//    AVEncoderAudioQualityKey=.high). 1ch porque voz não precisa stereo.
// 3. Timeline JSON paralelo, append-only durante gravação, lido no replay.
//
// Sources pesquisadas (LEI 1 — pesquisar antes de codar API Apple):
// - hackingwithswift.com/example-code/media/how-to-record-audio-using-avaudiorecorder
// - developer.apple.com/documentation/avfaudio/avaudiosession
// - developer.apple.com/documentation/avfoundation/avaudioplayer/1387297-currenttime
// - support.gingerlabs.com/hc/en-us/articles/206060617 (Notability sync model)

@MainActor
@Observable
final class PdfAudioRecorder: NSObject {

    // MARK: - State

    /// Estado do recorder. Idle = nada gravado nem tocando. Recording = mic ativo.
    /// Playing = áudio existente sendo reproduzido. Loaded = áudio existe mas
    /// está parado (ready to play).
    enum State: Equatable {
        case idle           // nenhum áudio gravado
        case recording      // gravando agora
        case loaded         // arquivo existe, parado
        case playing        // tocando
        case paused         // pausado no meio do playback
    }

    var state: State = .idle

    /// Tempo de gravação ou playback corrente, em segundos.
    var currentTime: TimeInterval = 0
    /// Duração total do áudio gravado/carregado.
    var totalDuration: TimeInterval = 0
    /// Eventos com timestamp (em ms) — anotações criadas durante a gravação.
    var timeline: Timeline = Timeline()
    /// Mostra o overlay de player? View binda nisso.
    var isOverlayVisible: Bool = false
    /// Permission denied? UI exibe alerta.
    var permissionDenied: Bool = false

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var pollTimer: Timer?
    private var recordingStartedAt: Date?
    private var fileHash: String = ""

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "pdf-audio")

    // MARK: - Public API

    /// Carrega o estado pra um PDF específico. Chama no PdfViewerViewModel.load().
    /// Se houver áudio salvo no disco, vira `.loaded`. Senão, `.idle`.
    func bind(fileHash: String) {
        self.fileHash = fileHash
        loadTimeline()
        if FileManager.default.fileExists(atPath: audioFileURL().path),
           let probe = try? AVAudioPlayer(contentsOf: audioFileURL()) {
            totalDuration = probe.duration
            state = .loaded
        } else {
            state = .idle
            totalDuration = 0
        }
    }

    /// Pede permissão (se necessário) e inicia gravação. Chama no botão Gravar.
    func startRecording() async {
        guard state == .idle || state == .loaded else { return }
        let granted = await requestPermission()
        guard granted else {
            permissionDenied = true
            return
        }

        // Apaga áudio antigo (sobreposição não suportada nesse MVP).
        try? FileManager.default.removeItem(at: audioFileURL())
        try? FileManager.default.removeItem(at: timelineFileURL())
        timeline = Timeline()

        // Configure session for record
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            Self.logger.error("[audio] session setup failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let r = try AVAudioRecorder(url: audioFileURL(), settings: settings)
            r.delegate = self
            r.prepareToRecord()
            guard r.record() else {
                Self.logger.error("[audio] AVAudioRecorder.record() returned false")
                return
            }
            recorder = r
            recordingStartedAt = Date()
            state = .recording
            currentTime = 0
            startPollTimer()
            isOverlayVisible = true
            Self.logger.notice("[audio] recording started, file=\(self.audioFileURL().lastPathComponent, privacy: .public)")
        } catch {
            Self.logger.error("[audio] AVAudioRecorder init failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Para gravação. Persiste timeline. Volta pra .loaded.
    func stopRecording() {
        guard state == .recording, let recorder else { return }
        recorder.stop()
        let duration = recorder.currentTime
        self.recorder = nil
        stopPollTimer()
        timeline.audioFile = audioFileURL().lastPathComponent
        timeline.totalDurationMs = Int(duration * 1000)
        saveTimeline()
        totalDuration = duration
        currentTime = 0
        state = .loaded
        recordingStartedAt = nil
        Self.logger.notice("[audio] recording stopped duration=\(duration) events=\(self.timeline.events.count)")
    }

    /// Inicia playback do áudio gravado. Polling 0.1s atualiza currentTime.
    func startPlayback() {
        guard state == .loaded || state == .paused else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            if player == nil {
                player = try AVAudioPlayer(contentsOf: audioFileURL())
                player?.delegate = self
                player?.prepareToPlay()
            }
            guard player?.play() == true else { return }
            state = .playing
            startPollTimer()
            isOverlayVisible = true
            Self.logger.notice("[audio] playback started")
        } catch {
            Self.logger.error("[audio] playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Pausa playback. Pode resumir com startPlayback().
    func pausePlayback() {
        guard state == .playing else { return }
        player?.pause()
        state = .paused
        stopPollTimer()
    }

    /// Pula pra um timestamp específico (em segundos).
    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(seconds, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Fecha overlay sem deletar nada. Áudio persiste no disco.
    func closeOverlay() {
        if state == .recording { stopRecording() }
        if state == .playing { pausePlayback() }
        player = nil
        isOverlayVisible = false
    }

    // MARK: - Timeline registration (called by ViewModel during recording)

    /// Registra evento de anotação na timeline. Só funciona se estiver gravando.
    func recordEvent(type: EventType, pageIndex: Int, id: String) {
        guard state == .recording, let started = recordingStartedAt else { return }
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        timeline.events.append(.init(type: type.rawValue, timestamp: elapsedMs, pageIndex: pageIndex, id: id))
        // Persiste a cada evento — proteção contra crash mid-recording.
        saveTimeline()
    }

    /// Pra UI: descobre qual página deveria estar destacada AGORA durante playback.
    /// Retorna o pageIndex do último evento cuja timestamp <= currentTimeMs.
    func currentHighlightedPage() -> Int? {
        guard state == .playing || state == .paused else { return nil }
        let nowMs = Int(currentTime * 1000)
        // Última página tocada antes ou igual ao tempo atual (eventos ordenados).
        let recent = timeline.events.last { $0.timestamp <= nowMs }
        return recent?.pageIndex
    }

    /// Eventos prestes a ser tocados (pra animar pulse). Janela de 0.6s pós-evento.
    func eventsActiveNow() -> [TimelineEvent] {
        guard state == .playing else { return [] }
        let nowMs = Int(currentTime * 1000)
        let windowMs = 600
        return timeline.events.filter { ev in
            ev.timestamp >= nowMs - windowMs && ev.timestamp <= nowMs + 50
        }
    }

    // MARK: - Permission

    private func requestPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Polling

    private func startPollTimer() {
        stopPollTimer()
        // 0.1s polling — Notability-tier responsiveness com low overhead.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        if state == .recording, let recorder {
            currentTime = recorder.currentTime
        } else if state == .playing, let player {
            currentTime = player.currentTime
            if !player.isPlaying {
                state = .paused
                stopPollTimer()
            }
        }
    }

    // MARK: - Files

    private func audioDir() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func audioFileURL() -> URL {
        audioDir().appendingPathComponent("\(fileHash).m4a")
    }

    private func timelineFileURL() -> URL {
        audioDir().appendingPathComponent("\(fileHash)_timeline.json")
    }

    private func loadTimeline() {
        let url = timelineFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Timeline.self, from: data) else {
            timeline = Timeline()
            return
        }
        timeline = decoded
    }

    private func saveTimeline() {
        let url = timelineFileURL()
        guard let data = try? JSONEncoder().encode(timeline) else { return }
        try? data.write(to: url)
    }
}

// MARK: - Delegate conformance

extension PdfAudioRecorder: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.state = .loaded
            self.currentTime = 0
            self.stopPollTimer()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            Self.logger.error("[audio] recorder encode error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            self.state = .idle
            self.stopPollTimer()
        }
    }
}

// MARK: - Timeline model

extension PdfAudioRecorder {
    enum EventType: String, Codable {
        case stroke
        case highlight
        case freeText
        case mask
    }

    struct TimelineEvent: Codable, Equatable {
        let type: String        // EventType.rawValue
        let timestamp: Int      // ms desde início da gravação
        let pageIndex: Int
        let id: String          // identificador da anotação (ex: "p2_stroke_142")
    }

    struct Timeline: Codable, Equatable {
        var audioFile: String = ""
        var totalDurationMs: Int = 0
        var events: [TimelineEvent] = []
    }
}
