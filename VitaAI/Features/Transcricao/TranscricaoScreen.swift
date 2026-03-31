import SwiftUI

/// Entry point for Transcricao feature. Owns the ViewModel, routes between phases.
///
/// Sub-screens live in separate files:
///   - TranscricaoShared.swift          (TealColors, TealBackground, StatusBadge, ModeToggle, ProcessingToast, ErrorPhase)
///   - TranscricaoRecorderContent.swift (RecorderArea, DisciplineChips, LiveTranscriptBox, RecordingsList, RecordingCard)
///   - TranscricaoDetailSheet.swift     (DetailSheet, AudioPlayer, PendingContent, TranscribedContent, ActionsMenu, DonePhase, Tabs)
struct TranscricaoScreen: View {
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    @State private var viewModel: TranscricaoViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                TranscricaoContent(viewModel: vm, onBack: onBack)
            } else {
                ProgressView().tint(TealColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TealColors.screenBg.ignoresSafeArea())
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient, api: container.api)
                Task { await viewModel?.loadRecordings() }
            }
        }
        .onDisappear {
            viewModel?.reset()
        }
    }
}

// MARK: - Content

@MainActor
private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void

    @State private var selectedMode: TranscricaoRecordingMode = .offline
    @State private var selectedDiscipline: String = "Geral"
    @State private var selectedFilter: String = "Todas"
    @State private var selectedRecording: TranscricaoEntry? = nil

    // Default disciplines shown before API subjects load
    private let fallbackDisciplines = ["Geral", "Anatomia", "Farmacologia", "Patologia", "Bioquimica"]

    /// Whether the pipeline is actively processing (upload/transcribe/summarize/flashcards)
    private var isProcessing: Bool {
        switch viewModel.phase {
        case .uploading, .transcribing, .summarizing, .generatingFlashcards:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            // Teal ambient background
            TealBackground()

            VStack(spacing: 0) {
                switch viewModel.phase {
                case .error:
                    TranscricaoErrorPhase(
                        message: viewModel.errorMessage ?? "Erro desconhecido",
                        onRetry: { viewModel.reset() }
                    )

                case .done:
                    TranscricaoDonePhase(
                        transcript: viewModel.transcript,
                        summary: viewModel.summary,
                        flashcards: viewModel.flashcards,
                        onReset: { viewModel.reset() }
                    )

                default:
                    // idle, recording, and processing phases all show the main scroll
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Processing toast overlay (inline, not full-screen)
                            if isProcessing {
                                TranscricaoProcessingToast(
                                    phase: viewModel.phase,
                                    percent: viewModel.progressPercent,
                                    stage: viewModel.progressStage
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 6)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // Mode toggle
                            TranscricaoModeToggle(selected: $selectedMode)
                                .padding(.horizontal, 16)
                                .padding(.top, isProcessing ? 4 : 10)
                                .padding(.bottom, 12)
                                .disabled(viewModel.phase == .recording || isProcessing)
                                .opacity(isProcessing ? 0.5 : 1.0)

                            // Recorder area
                            TranscricaoRecorderArea(
                                elapsedSeconds: viewModel.phase == .recording ? viewModel.elapsedSeconds : 0,
                                isRecording: viewModel.phase == .recording,
                                selectedDiscipline: $selectedDiscipline,
                                disciplines: fallbackDisciplines,
                                onToggle: {
                                    if viewModel.phase == .recording {
                                        viewModel.stopRecording()
                                    } else {
                                        Task { await viewModel.startRecording() }
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .disabled(isProcessing)
                            .opacity(isProcessing ? 0.6 : 1.0)

                            // Live transcript (if in live mode and recording)
                            if viewModel.phase == .recording && selectedMode == .live && !viewModel.liveTranscript.isEmpty {
                                TranscricaoLiveTranscriptBox(text: viewModel.liveTranscript)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            }

                            // Recordings list
                            TranscricaoRecordingsListSection(
                                recordings: viewModel.recordings,
                                isLoading: viewModel.recordingsLoading,
                                selectedFilter: $selectedFilter,
                                filterChips: ["Todas"] + fallbackDisciplines,
                                onTap: { rec in selectedRecording = rec },
                                onDelete: { rec in
                                    withAnimation {
                                        viewModel.removeRecordingLocally(id: rec.id)
                                    }
                                }
                            )
                            .padding(.top, 10)
                        }
                        .padding(.bottom, 120)
                    }
                    .animation(.easeInOut(duration: 0.3), value: isProcessing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Detail sheet when tapping a recording
        .sheet(item: $selectedRecording) { rec in
            TranscricaoDetailSheet(recording: rec)
        }
    }
}
