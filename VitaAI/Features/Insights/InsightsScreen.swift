import SwiftUI

// MARK: - InsightsScreen

struct InsightsScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: InsightsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                insightsContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InsightsViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }

    @ViewBuilder
    private func insightsContent(vm: InsightsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 1. Stats 2x2 Grid
                StatsGrid(vm: vm)

                // 2. Progresso Hoje (only when todayTotal > 0)
                if vm.todayTotal > 0 {
                    TodayProgressCard(
                        todayCompleted: vm.todayCompleted,
                        todayTotal: vm.todayTotal,
                        todayMinutes: vm.todayMinutes
                    )
                }

                // 3. Por Matéria
                SubjectsSection(vm: vm)

                // 4. Próximas Provas
                ExamsSection(exams: vm.upcomingExams)

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await vm.load() }
    }
}

// MARK: - Stat Item Model

private struct InsightsStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let subtitle: String
    let icon: String
    let valueColor: Color
}

// MARK: - Stats Grid

private struct StatsGrid: View {
    let vm: InsightsViewModel

    private var stats: [InsightsStatItem] {
        let accuracySubtitle: String
        let accuracyColor: Color
        if vm.avgAccuracy >= 70 {
            accuracySubtitle = "Excelente!"
            accuracyColor = Color(hex: 0x22C55E)
        } else if vm.avgAccuracy >= 50 {
            accuracySubtitle = "Razoável"
            accuracyColor = Color(hex: 0xF59E0B)
        } else {
            accuracySubtitle = "Precisa melhorar"
            accuracyColor = Color(hex: 0xEF4444)
        }

        return [
            InsightsStatItem(
                label: "PRECISÃO",
                value: "\(Int(vm.avgAccuracy))%",
                subtitle: accuracySubtitle,
                icon: "target",
                valueColor: accuracyColor
            ),
            InsightsStatItem(
                label: "SEQUÊNCIA",
                value: "\(vm.streakDays)d",
                subtitle: "dias seguidos",
                icon: "flame.fill",
                valueColor: VitaColors.textTertiary
            ),
            InsightsStatItem(
                label: "HORAS",
                value: String(format: "%.1fh", vm.totalHours),
                subtitle: "de estudo",
                icon: "clock.fill",
                valueColor: VitaColors.textTertiary
            ),
            InsightsStatItem(
                label: "FLASHCARDS",
                value: "\(vm.totalCards)",
                subtitle: "\(vm.flashcardsDue) pendentes",
                icon: "brain.fill",
                valueColor: VitaColors.textTertiary
            ),
        ]
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(stats) { stat in
                StatCard(stat: stat)
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let stat: InsightsStatItem

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textTertiary)
                    Text(stat.label)
                        .font(.system(size: 9))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Text(stat.value)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(VitaColors.textPrimary)
                Text(stat.subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(stat.valueColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}

// MARK: - Today Progress Card

private struct TodayProgressCard: View {
    let todayCompleted: Int
    let todayTotal: Int
    let todayMinutes: Int

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Hoje")

                HStack(spacing: 12) {
                    Text("\(todayCompleted)/\(todayTotal)")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(VitaColors.textPrimary)

                    GeometryReader { geo in
                        let pct: CGFloat = todayTotal > 0
                            ? CGFloat(todayCompleted) / CGFloat(todayTotal)
                            : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VitaColors.surfaceElevated)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: 0x22C55E))
                                .frame(width: geo.size.width * pct, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(todayMinutes) min")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
        }
    }
}

// MARK: - Subjects Section

private struct SubjectsSection: View {
    let vm: InsightsViewModel

    private var sortedSubjects: [SubjectProgress] {
        vm.subjects.sorted { $0.accuracy > $1.accuracy }
    }

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Por Matéria")

            if sortedSubjects.isEmpty {
                InsightsEmptyState(
                    icon: "book.closed.fill",
                    message: "Nenhuma matéria registrada ainda"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedSubjects, id: \.subjectId) { subject in
                        SubjectRow(
                            subject: subject,
                            subjectName: vm.subjectName(for: subject.subjectId),
                            accuracyColor: vm.accuracyColor(for: subject.accuracy)
                        )
                    }
                }
            }
        }
    }
}

private struct SubjectRow: View {
    let subject: SubjectProgress
    let subjectName: String
    let accuracyColor: Color

    private var detailText: String {
        let hoursStr = String(format: "%.1f", subject.hoursSpent) + "h"
        if subject.cardsDue > 0 {
            return "\(hoursStr) · \(subject.cardsDue) pendentes"
        }
        return hoursStr
    }

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.surfaceElevated)
                            .frame(width: 32, height: 32)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(subjectName)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text(detailText)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    Spacer()

                    Text("\(Int(subject.accuracy))%")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(accuracyColor)
                }

                // Accuracy progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 2)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accuracyColor)
                            .frame(
                                width: geo.size.width * CGFloat(subject.accuracy) / 100,
                                height: 2
                            )
                    }
                }
                .frame(height: 2)
            }
            .padding(14)
        }
    }
}

// MARK: - Exams Section

private struct ExamsSection: View {
    let exams: [ExamEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Próximas Provas")

            if exams.isEmpty {
                InsightsEmptyState(
                    icon: "calendar.badge.clock",
                    message: "Nenhuma prova agendada"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(exams) { exam in
                        ExamRow(exam: exam)
                    }
                }
            }
        }
    }
}

private struct ExamRow: View {
    let exam: ExamEntry

    private var countdownColor: Color {
        if exam.daysUntil <= 7 { return Color.red }
        if exam.daysUntil <= 14 { return Color.yellow }
        return VitaColors.textSecondary
    }

    private func formattedDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateStyle = .medium
        return df.string(from: date)
    }

    var body: some View {
        VitaGlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.subjectName)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(formattedDate(exam.date))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Text("\(exam.daysUntil)d")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(countdownColor)
            }
            .padding(14)
        }
    }
}

// MARK: - Empty State

private struct InsightsEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text(message)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        }
    }
}
