import SwiftUI

// MARK: - Mock data (matches qbank-mobile-v1.html mockup exactly)

private let mockProgress = QBankProgressResponse(
    totalAvailable: 1248,
    totalAnswered: 234,
    totalCorrect: 183,
    accuracy: 78.0,
    byDifficulty: [],
    byTopic: [
        QBankProgressByTopic(topicId: 1, topicTitle: "Farmacologia", answered: 50, correct: 41),
        QBankProgressByTopic(topicId: 2, topicTitle: "Cardiologia", answered: 40, correct: 30),
        QBankProgressByTopic(topicId: 3, topicTitle: "Pediatria", answered: 20, correct: 18),
        QBankProgressByTopic(topicId: 4, topicTitle: "Semiologia", answered: 25, correct: 17),
        QBankProgressByTopic(topicId: 5, topicTitle: "Histologia", answered: 20, correct: 11),
    ]
)

private let mockSessions = [
    QBankSessionSummary(id: "mock-1", title: "Farmacologia \u{2014} ENARE", totalQuestions: 40, currentIndex: 28, correctCount: 23, completedAt: nil, createdAt: "2026-03-31T09:00:00Z"),
    QBankSessionSummary(id: "mock-2", title: "Cardiologia \u{2014} USP-RP", totalQuestions: 40, currentIndex: 40, correctCount: 30, completedAt: "2026-03-24T15:00:00Z", createdAt: "2026-03-24T14:00:00Z"),
    QBankSessionSummary(id: "mock-3", title: "Pediatria Geral", totalQuestions: 20, currentIndex: 20, correctCount: 18, completedAt: "2026-03-22T10:00:00Z", createdAt: "2026-03-22T09:00:00Z"),
]

// MARK: - Home content (mockup-matched: bg-qbank + hero + CTA + chips + sessions + topics)

struct QBankHomeContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void
    @State private var selectedChip = "Todas"

    private let chipLabels = ["Todas", "N\u{e3}o respondidas", "Resid\u{ea}ncia", "F\u{e1}cil", "M\u{e9}dia", "Dif\u{ed}cil"]

    /// Use real data if available, otherwise fall back to mock
    private var displayProgress: QBankProgressResponse {
        vm.state.progress.totalAvailable > 0 ? vm.state.progress : mockProgress
    }

    private var displaySessions: [QBankSessionSummary] {
        vm.state.recentSessions.isEmpty ? mockSessions : vm.state.recentSessions
    }

    private var displayTopics: [QBankProgressByTopic] {
        let real = vm.state.progress.byTopic
        return real.isEmpty ? mockProgress.byTopic : real
    }

    var body: some View {
        ZStack {
            // -- Fullscreen bg-qbank image with dark overlay (matches .bg-fullscreen CSS)
            QBankBackground()

            if vm.state.progressLoading {
                ProgressView().tint(VitaColors.accent)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // -- PROGRESS HERO card
                        QBankProgressHero(progress: displayProgress)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // -- CTA: Nova Sessao
                        Button {
                            vm.goToDisciplines()
                        } label: {
                            Text("Nova Sess\u{e3}o")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(-0.01 * 15)
                                .foregroundStyle(Color.white.opacity(0.95))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.65),
                                            VitaColors.accentDark.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(VitaColors.accentLight.opacity(0.18), lineWidth: 0.5)
                                )
                                .shadow(color: VitaColors.accent.opacity(0.20), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // -- FILTER CHIPS (horizontal scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(chipLabels, id: \.self) { label in
                                    QBankFilterChip(label: label, isActive: selectedChip == label) {
                                        selectedChip = label
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 16)

                        // -- SESSOES RECENTES
                        QBankSectionLabel(title: "Sess\u{f5}es recentes")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        VStack(spacing: 10) {
                            ForEach(displaySessions) { session in
                                QBankSessionCard(session: session) {
                                    vm.resumeSession(session)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // -- DESEMPENHO POR TOPICO
                        QBankSectionLabel(title: "Desempenho por t\u{f3}pico")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        QBankTopicsCard(topics: Array(displayTopics.prefix(5)))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        if displayTopics.count > 5 {
                            Text("e mais \(displayTopics.count - 5) temas...")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 6)
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .onAppear { vm.loadHomeData() }
    }
}

// MARK: - QBank Background (bg-qbank fullscreen + dark overlay)

struct QBankBackground: View {
    var body: some View {
        ZStack {
            VitaColors.surface

            Image("bg-qbank")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.1)

            // Dark gradient overlay (matches .bg-fullscreen::after)
            LinearGradient(
                stops: [
                    .init(color: VitaColors.surface.opacity(0.40), location: 0),
                    .init(color: VitaColors.surface.opacity(0.15), location: 0.40),
                    .init(color: VitaColors.surface.opacity(0.55), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Progress Hero (234 / 1.248 big number + bar + accuracy)

struct QBankProgressHero: View {
    let progress: QBankProgressResponse

    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 0) {
                // Big number row
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatNumber(progress.totalAnswered))
                        .font(.system(size: 36, weight: .heavy))
                        .tracking(-0.04 * 36)
                        .foregroundStyle(VitaColors.accentLight.opacity(0.92))

                    Text("/ \(formatNumber(progress.totalAvailable))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                }

                // Label
                Text("quest\u{f5}es respondidas")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(.top, 4)

                // Progress bar
                let pctFill = progress.totalAvailable > 0
                    ? Double(progress.totalAnswered) / Double(progress.totalAvailable)
                    : 0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 99)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 99)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.accent.opacity(0.7),
                                        VitaColors.accentHover.opacity(0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: VitaColors.accentHover.opacity(0.30), radius: 6)
                            .frame(width: max(geo.size.width * CGFloat(pctFill), 2))
                    }
                }
                .frame(height: 6)
                .padding(.top, 14)

                // Accuracy row
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .medium))
                    Text("\(Int(progress.normalizedAccuracy * 100))% de acerto")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(VitaColors.dataGreen.opacity(0.85))
                .padding(.top, 12)
            }
            .padding(.vertical, 20).padding(.horizontal, 18)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Filter Chip (matches .chip CSS)

struct QBankFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? VitaColors.accentLight.opacity(0.92)
                        : VitaColors.textWarm.opacity(0.55)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isActive
                        ? LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(0.20),
                                VitaColors.accentDark.opacity(0.10)
                            ],
                            startPoint: .top, endPoint: .bottom
                          )
                        : LinearGradient(
                            colors: [
                                VitaColors.textWarm.opacity(0.05),
                                VitaColors.textWarm.opacity(0.02)
                            ],
                            startPoint: .top, endPoint: .bottom
                          )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isActive
                            ? VitaColors.accentHover.opacity(0.28)
                            : VitaColors.accentLight.opacity(0.10),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Label (uppercase, matches .section-label CSS)

struct QBankSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(VitaColors.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Session Card (matches .glass-card.session-card CSS)

struct QBankSessionCard: View {
    let session: QBankSessionSummary
    let action: () -> Void

    private var pct: Int {
        session.totalQuestions > 0
            ? Int(Double(session.correctCount) / Double(session.totalQuestions) * 100)
            : 0
    }
    private var metaText: String {
        if session.isActive {
            return "\(session.currentIndex)/\(session.totalQuestions) respondidas \u{b7} hoje"
        }
        return "\(session.correctCount)/\(session.totalQuestions) corretas"
    }

    var body: some View {
        Button(action: action) {
            VitaGlassCard(cornerRadius: 18) {
                HStack(spacing: 12) {
                    // Session icon (matches .session-icon CSS)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.glassInnerLight.opacity(0.22),
                                        VitaColors.accentDark.opacity(0.10)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 1)
                        Image(systemName: session.isActive ? "clock" : "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                    }
                    .frame(width: 40, height: 40)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title ?? "Sess\u{e3}o de \(session.totalQuestions) quest\u{f5}es")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)
                        Text(metaText)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Accuracy %
                    Text("\(pct)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Topics Card (matches .glass-card with .topic-row CSS)

struct QBankTopicsCard: View {
    let topics: [QBankProgressByTopic]

    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                    let pct = Int((topic.accuracy > 1.0 ? topic.accuracy : topic.accuracy * 100))
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                    }
                    HStack(spacing: 10) {
                        Text(topic.topicTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Horizontal bar (80px)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 80, height: 4)
                            RoundedRectangle(cornerRadius: 99)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.6),
                                            VitaColors.accentHover.opacity(0.8)
                                        ],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: max(80 * CGFloat(topic.accuracy).clamped(to: 0...1), 2), height: 4)
                        }

                        Text("\(pct)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                            .frame(width: 32, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Empty State

struct QBankEmptyState: View {
    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.glassInnerLight.opacity(0.22),
                                    VitaColors.accentDark.opacity(0.10)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "book")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                }
                .frame(width: 40, height: 40)

                Text("Comece a praticar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))

                Text("Inicie uma sess\u{e3}o de quest\u{f5}es para acompanhar seu desempenho aqui")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(28)
        }
    }
}
