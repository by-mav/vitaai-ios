import SwiftUI

// MARK: - Recorder Area (timer + waveform + discipline chips + record button)

// Pre-seeded waveform heights — avoids CGFloat.random causing layout thrash on every render
private let waveformHeights: [CGFloat] = [8, 18, 28, 14, 34, 10, 24, 32, 12, 22, 30, 8,
                                          20, 34, 16, 26, 10, 28, 18, 34, 12, 22, 8, 20]

struct TranscricaoRecorderArea: View {
    let elapsedSeconds: Int
    let isRecording: Bool
    @Binding var selectedDiscipline: String
    let disciplines: [String]
    let onToggle: () -> Void

    @State private var wavePhase: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left side: timer + status + waveform + discipline chips + stop btn
            VStack(alignment: .leading, spacing: 0) {
                // Timer
                Text(formatTranscricaoElapsed(elapsedSeconds))
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .tracking(-1.5)
                    .monospacedDigit()
                    .foregroundStyle(
                        isRecording
                            ? VitaColors.accentLight.opacity(0.95)
                            : Color.white.opacity(0.22)
                    )
                    .shadow(color: isRecording ? VitaColors.accent.opacity(0.4) : .clear, radius: 24)

                // Status label
                Text(isRecording ? "Gravando..." : "Pronto para gravar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isRecording
                            ? VitaColors.accentLight.opacity(0.70)
                            : Color.white.opacity(0.25)
                    )
                    .padding(.top, 2)

                // Waveform bars — fixed heights, animated via phase toggle
                HStack(spacing: 1.5) {
                    ForEach(0..<24, id: \.self) { i in
                        let baseH = waveformHeights[i]
                        let altH  = waveformHeights[(i + 12) % 24]
                        let h: CGFloat = isRecording ? (wavePhase ? baseH : altH) : 6
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isRecording
                                    ? LinearGradient(
                                        colors: [VitaColors.accent.opacity(0.5), VitaColors.accentLight.opacity(0.85)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                                    : LinearGradient(
                                        colors: [VitaColors.accent.opacity(0.10)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                      )
                            )
                            .frame(width: 2.5, height: h)
                            .animation(.easeInOut(duration: 0.35).delay(Double(i) * 0.02), value: wavePhase)
                            .animation(.easeInOut(duration: 0.35), value: isRecording)
                    }
                }
                .frame(height: 36)
                .padding(.top, 8)
                .onAppear {
                    guard isRecording else { return }
                    withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                        wavePhase.toggle()
                    }
                }
                .onChange(of: isRecording) { _, recording in
                    if recording {
                        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                            wavePhase.toggle()
                        }
                    }
                }

                // Discipline chips below waveform
                TranscricaoDisciplineChips(
                    disciplines: ["Auto-detectar"] + disciplines,
                    selected: $selectedDiscipline,
                    disabled: isRecording
                )
                .padding(.top, 4)

                // Stop button (only visible when recording)
                if isRecording {
                    Button(action: onToggle) {
                        Text("Parar gravação")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accentHover.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(VitaColors.accent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VitaColors.accent.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // Right side: recorder image button
            Button(action: {
                if !isRecording { onToggle() }
            }) {
                VStack(spacing: 4) {
                    Image("btn-transcricao")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 155)
                        .shadow(color: VitaColors.accent.opacity(0.30), radius: 20)
                        .opacity(isRecording ? 0.7 : 1.0)
                        .scaleEffect(isRecording ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.4), value: isRecording)

                    Text(isRecording ? "Gravando..." : "Toque para gravar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            isRecording
                                ? VitaColors.accentLight.opacity(0.70)
                                : Color.white.opacity(0.22)
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Discipline Chips

struct TranscricaoDisciplineChips: View {
    let disciplines: [String]
    @Binding var selected: String
    let disabled: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(disciplines, id: \.self) { disc in
                    let isSelected = selected == disc
                    Button {
                        if !disabled {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selected = disc
                            }
                        }
                    } label: {
                        Text(abbreviateDiscipline(disc))
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(
                                isSelected
                                    ? VitaColors.accentHover.opacity(0.90)
                                    : VitaColors.textWarm.opacity(0.35)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.10)
                                            : Color.white.opacity(0.04)
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.30)
                                            : VitaColors.accent.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(disabled ? 0.5 : 1.0)
                }
            }
        }
    }
}

// MARK: - Live Transcript Box

struct TranscricaoLiveTranscriptBox: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(4)
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(maxHeight: 120)
        .background(TealColors.accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Recordings List Section (data from API)

struct TranscricaoRecordingsListSection: View {
    let recordings: [TranscricaoEntry]
    let isLoading: Bool
    @Binding var selectedFilter: String?
    let filterChips: [String]
    let onTap: (TranscricaoEntry) -> Void
    let onDelete: (TranscricaoEntry) -> Void

    private var filteredRecordings: [TranscricaoEntry] {
        guard let filter = selectedFilter else { return recordings }
        return recordings.filter { $0.discipline?.uppercased() == filter.uppercased() }
    }

    // Group recordings by date bucket
    private var groupedRecordings: [(key: String, recordings: [TranscricaoEntry])] {
        let items = filteredRecordings
        let cal = Calendar.current
        let now = Date()

        var today: [TranscricaoEntry] = []
        var thisWeek: [TranscricaoEntry] = []
        var older: [TranscricaoEntry] = []

        for rec in items {
            let date = rec.parsedDate ?? .distantPast
            if cal.isDateInToday(date) {
                today.append(rec)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                thisWeek.append(rec)
            } else {
                older.append(rec)
            }
        }

        var result: [(key: String, recordings: [TranscricaoEntry])] = []
        if !today.isEmpty { result.append(("Hoje", today)) }
        if !thisWeek.isEmpty { result.append(("Esta semana", thisWeek)) }
        if !older.isEmpty { result.append(("Anteriores", older)) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with count
            HStack {
                Text("GRAVAÇÕES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .tracking(0.5)

                if !recordings.isEmpty {
                    Text("\(recordings.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.accent.opacity(0.80))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VitaColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            // Filter chips (discipline filter)
            if !filterChips.isEmpty {
                TranscricaoFilterChips(chips: filterChips, selected: $selectedFilter)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            if isLoading {
                ProgressView()
                    .tint(TealColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if recordings.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.12), VitaColors.accent.opacity(0.03)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(VitaColors.accent.opacity(0.55))
                    }

                    Text("Nenhuma gravação ainda")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text("Grave sua aula e a IA transcreve, resume,\ne cria flashcards automaticamente.")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
            } else {
                // Date-grouped recordings
                VStack(spacing: 4) {
                    ForEach(groupedRecordings, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.key.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                                .tracking(0.8)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(group.recordings) { rec in
                                TealGlassRecordingCard(recording: rec)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(rec) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Filter Chips

struct TranscricaoFilterChips: View {
    let chips: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "Todas" chip — clears filter
                chipButton(label: "Todas", isSelected: selected == nil) {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = nil }
                }

                ForEach(chips, id: \.self) { chip in
                    chipButton(label: abbreviateDiscipline(chip), isSelected: selected == chip) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = (selected == chip) ? nil : chip
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(
                    isSelected
                        ? VitaColors.accentHover.opacity(0.90)
                        : VitaColors.textWarm.opacity(0.35)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? VitaColors.accent.opacity(0.10)
                                : Color.white.opacity(0.04)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? VitaColors.accent.opacity(0.30)
                                : VitaColors.accent.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Teal Glass Recording Card

struct TealGlassRecordingCard: View {
    let recording: TranscricaoEntry

    private var displayStatus: RecordingStatus {
        recording.isTranscribed ? .transcribed : .pending
    }

    var body: some View {
        HStack(spacing: 14) {
            // Mic icon in glass circle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.15 : 0.32),
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.06 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 6, y: 3)

                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.92))
            }
            .opacity(displayStatus == .pending ? 0.5 : 1.0)

            // Text block
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title.isEmpty ? "Gravação" : recording.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)

                // Discipline tag (if categorized)
                if let disc = recording.discipline, !disc.isEmpty, disc != "Geral" {
                    Text(abbreviateDiscipline(disc).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .lineLimit(1)
                        .foregroundStyle(VitaColors.accent.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(VitaColors.accent.opacity(0.10))
                        .clipShape(Capsule())
                }

                // Metadata row: date · duration · size
                HStack(spacing: 5) {
                    let dateStr = recording.relativeDate
                    if !dateStr.isEmpty {
                        Label(dateStr, systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let duration = recording.duration, !duration.isEmpty {
                        if !dateStr.isEmpty {
                            Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        }
                        Text(duration)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let size = recording.formattedSize {
                        Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }
                }
                .labelStyle(.titleOnly)
            }

            Spacer()

            // Status + chevron
            VStack(spacing: 6) {
                TranscricaoStatusBadge(status: displayStatus)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Discipline Name Abbreviation

/// Shortens long discipline names for chips.
/// Strategy: title-case, drop prepositions, abbreviate to fit ≤16 chars.
/// "FARMACOLOGIA MÉDICA I" → "Farmacologia I"
/// "MEDICINA DE FAMÍLIA E COMUNIDADE" → "Med. Família"
/// "PRÁTICAS MÉDICAS EM ATENÇÃO BÁSICA" → "Prát. Médicas"
private func abbreviateDiscipline(_ name: String) -> String {
    let prepositions: Set<String> = ["de", "do", "da", "dos", "das", "em", "e", "a", "o", "na", "no", "para"]

    // Title-case words, skipping prepositions
    let words: [String] = name.lowercased().split(separator: " ").compactMap { segment in
        let w = String(segment)
        // Drop prepositions entirely for abbreviation
        if prepositions.contains(w) { return nil }
        // Keep roman numerals uppercase
        if w.allSatisfy({ "ivxlcdm".contains($0) }) && !w.isEmpty {
            return w.uppercased()
        }
        return w.prefix(1).uppercased() + w.dropFirst()
    }

    // If the joined result is short enough, return as-is
    let full = words.joined(separator: " ")
    if full.count <= 16 { return full }

    // Keep first word (possibly abbreviated) + second word abbreviated
    guard let first = words.first else { return full }

    if words.count == 1 {
        // Single long word — truncate
        return String(first.prefix(14)) + "."
    }

    // Try: first word + remaining as initials/short
    var result = first
    if result.count > 10 {
        // Abbreviate first word too
        result = String(first.prefix(4)) + "."
    }

    for i in 1..<words.count {
        let w = words[i]
        let candidate = result + " " + w
        if candidate.count <= 16 {
            result = candidate
        } else {
            // Roman numeral — always append
            if w.count <= 3 && w.allSatisfy({ "IVX".contains($0) }) {
                result += " " + w
            }
            break
        }
    }

    return result
}
