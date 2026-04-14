import AVFoundation
import Foundation
import Speech
import SwiftUI

// MARK: - TranscricaoViewModel
//
// Manages the full recording → upload → transcription → done pipeline.
// Mirrors Android's TranscricaoViewModel state machine (Phase enum).
//
// iOS extras vs Android:
//   - SFSpeechRecognizer for live transcript display while recording
//   - AVAudioFile for direct-to-disk m4a capture alongside recognition

@MainActor
@Observable
final class TranscricaoViewModel {

    // MARK: - Phase (mirrors Android Phase enum)

    enum Phase: Equatable {
        case idle
        case recording
        case uploading
        case transcribing
        case summarizing
        case generatingFlashcards
        case done
        case error
    }

    // MARK: - Exposed State

    private(set) var phase: Phase = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var progressPercent: Int = 0
    private(set) var progressStage: String = ""
    /// Real-time SFSpeechRecognizer partial transcript shown during recording.
    private(set) var liveTranscript: String = ""
    private(set) var transcript: String = ""
    private(set) var summary: String = ""
    private(set) var flashcards: [TranscriptionFlashcard] = []
    private(set) var errorMessage: String?
    /// Saved recordings loaded from API
    private(set) var recordings: [TranscricaoEntry] = []
    private(set) var recordingsLoading: Bool = false

    // MARK: - Private

    private let client: TranscricaoClient
    private var api: VitaAPI?
    private var gamificationEvents: GamificationEventManager?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var recordingURL: URL?
    private var timerTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var recordingStartDate = Date()

    init(client: TranscricaoClient, api: VitaAPI? = nil, gamificationEvents: GamificationEventManager? = nil) {
        self.client = client
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Public API

    /// Load saved recordings from the API
    func loadRecordings() async {
        guard let api else { return }
        recordingsLoading = true
        do {
            recordings = try await api.getTranscricoes()
            for r in recordings {
                NSLog("[TranscricaoVM] Recording: id=%@ title=%@ status=%@ isTranscribed=%d", r.id, r.title, r.status ?? "nil", r.isTranscribed ? 1 : 0)
            }
        } catch {
            NSLog("[TranscricaoVM] FAILED to load recordings: %@", "\(error)")
            // Non-fatal — just show empty list
        }
        recordingsLoading = false
    }

    func startRecording() async {
        guard await requestPermissions() else {
            phase = .error
            errorMessage = "Microfone ou reconhecimento de voz bloqueado. Ative em Ajustes > Privacidade."
            return
        }

        recordingStartDate = Date()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vita_audio_\(Int(Date().timeIntervalSince1970)).m4a")
        recordingURL = url
        liveTranscript = ""

        do {
            try beginAudioCapture(outputURL: url)
            phase = .recording
            elapsedSeconds = 0
            startTimer()
        } catch {
            phase = .error
            errorMessage = "Não foi possível iniciar a gravação: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        timerTask?.cancel()
        timerTask = nil
        endAudioCapture()

        guard let url = recordingURL else {
            setError("Arquivo de gravação não encontrado.")
            return
        }
        phase = .uploading
        progressPercent = 0
        progressStage = ""
        uploadTask = Task { [weak self] in
            await self?.processUpload(fileURL: url)
        }
    }

    /// Remove a recording from the local list (optimistic delete)
    func removeRecordingLocally(id: String) {
        recordings.removeAll { $0.id == id }
    }

    func reset() {
        timerTask?.cancel()
        uploadTask?.cancel()
        timerTask = nil
        uploadTask = nil
        endAudioCapture()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        phase = .idle
        elapsedSeconds = 0
        progressPercent = 0
        progressStage = ""
        liveTranscript = ""
        transcript = ""
        summary = ""
        flashcards = []
        errorMessage = nil
    }

    // MARK: - Permissions

    private func requestPermissions() async -> Bool {
        // Microphone
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        if micStatus == .denied { return false }
        if micStatus == .undetermined {
            let granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in cont.resume(returning: granted) }
            }
            guard granted else { return false }
        }
        // Speech recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .denied || speechStatus == .restricted { return false }
        if speechStatus == .notDetermined {
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
            guard granted else { return false }
        }
        return true
    }

    // MARK: - Audio Capture

    private func beginAudioCapture(outputURL: URL) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Write to disk (AAC/m4a) — same format as Android AudioRecorder
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: min(inputFormat.channelCount, 1),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: fileSettings)

        // SFSpeechRecognizer for live partial transcript
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        // Single tap: write samples to disk AND feed speech recognizer
        // Capture `outputFile` and `request` by value to avoid actor isolation issues
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [outputFile, request] buffer, _ in
            try? outputFile.write(from: buffer)
            request.append(buffer)
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        try engine.start()
        audioEngine = engine

        // Recognition task — updates live transcript only (does NOT control recording stop)
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                self?.liveTranscript = text
            }
        }
    }

    private func endAudioCapture() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.elapsedSeconds += 1 }
            }
        }
    }

    // MARK: - Upload

    private func processUpload(fileURL: URL) async {
        do {
            for try await event in await client.uploadAndStream(fileURL: fileURL) {
                switch event {
                case .progress(let stage, let percent):
                    progressPercent = percent
                    progressStage = stage
                    phase = phaseFromStage(stage)
                case .complete(let t, let s, let cards):
                    transcript = t
                    summary = s
                    flashcards = cards
                    progressPercent = 100
                    phase = .done
                    try? FileManager.default.removeItem(at: fileURL)

                    // Log study session for gamification
                    let durationMinutes = Int(Date().timeIntervalSince(recordingStartDate) / 60)
                    if let api, let gamificationEvents {
                        Task {
                            if let result = try? await api.logActivity(
                                action: "study_session_end",
                                metadata: ["durationMinutes": String(durationMinutes)]
                            ) {
                                await gamificationEvents.handleActivityResponse(result, previousLevel: nil)
                            }
                        }
                    }
                case .error(let msg):
                    setError(msg)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            setError("Erro no envio: \(error.localizedDescription)")
        }
    }

    private func phaseFromStage(_ stage: String) -> Phase {
        let lower = stage.lowercased()
        if lower.contains("transcri") { return .transcribing }
        if lower.contains("resum") { return .summarizing }
        if lower.contains("flash") { return .generatingFlashcards }
        return .uploading
    }

    private func setError(_ msg: String) {
        phase = .error
        errorMessage = msg
    }
}
