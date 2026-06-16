import SwiftUI

// MARK: - MateriasAgendaWidget
//
// Shared pager widget: Agenda ↔ Disciplinas tabs with swipe gesture.
// Used by both DashboardScreen and FaculdadeHomeScreen.
// ANY change here reflects in BOTH places — that's the point.
//
// Wrapped in VitaGlassCard for unified glassmorphism across the app.

struct MateriasAgendaWidget: View {
    let subjects: [GradeSubject]
    let schedule: [AgendaClassBlock]
    let evaluations: [AgendaEvaluation]
    var onNavigateToDiscipline: ((String, String) -> Void)?

    @State private var activeTab: Int = 0

    // Tokens
    private let goldPrimary = VitaColors.accentHover
    private let textPrimary = VitaColors.textPrimary
    private let textWarm = VitaColors.textWarm
    private let textDim = VitaColors.textWarm.opacity(0.25)

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Content — swap with gesture
            Group {
                if activeTab == 0 {
                    agendaContent()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                } else {
                    materiasContent()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -30 { activeTab = 1 }
                        if value.translation.width > 30 { activeTab = 0 }
                    }
            )
        }
        .padding(.bottom, 4)
        .glassCard(cornerRadius: 16)
        .animation(.easeInOut(duration: 0.2), value: activeTab)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabPill(title: "Agenda", icon: "calendar", index: 0)
            tabPill(title: "Disciplinas", icon: "graduationcap", index: 1)
        }
    }

    @ViewBuilder
    private func tabPill(title: String, icon: String, index: Int) -> some View {
        let selected = activeTab == index
        Button {
            activeTab = index
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selected ? goldPrimary : textWarm.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? goldPrimary.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? goldPrimary.opacity(0.15) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Matérias content

    @ViewBuilder
    private func materiasContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if subjects.isEmpty {
                Text("Nenhuma disciplina ativa")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textWarm.opacity(0.35))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(subjects) { subject in
                        materiaRow(subject)
                        if subject.id != subjects.last?.id {
                            Rectangle()
                                .fill(textWarm.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Agenda content

    @ViewBuilder
    private func agendaContent() -> some View {
        MonthlyCalendarView(
            schedule: schedule,
            evaluations: evaluations
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Row

    @ViewBuilder
    private func materiaRow(_ subject: GradeSubject) -> some View {
        let color = SubjectColors.colorFor(subject: subject.subjectName)
        let relatedEvaluations = evaluations.filter { eval in
            let evalSubject = eval.subjectName ?? ""
            return evalSubject.caseInsensitiveCompare(subject.subjectName) == .orderedSame
        }
        let pendingCount = relatedEvaluations.filter { eval in
            let status = eval.status.lowercased()
            return status != "completed" && status != "graded" && status != "submitted"
        }.count
        let nextLabel = nextEvaluationLabel(for: relatedEvaluations)

        Button {
            onNavigateToDiscipline?(subject.id, subject.subjectName)
        } label: {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.subjectName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(textWarm.opacity(0.90))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if pendingCount > 0 {
                            infoPill("\(pendingCount) tarefa\(pendingCount == 1 ? "" : "s")")
                        }
                        if let nextLabel {
                            infoPill(nextLabel)
                        }
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(goldPrimary.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(textWarm.opacity(0.55))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(goldPrimary.opacity(0.07))
            )
    }

    private func nextEvaluationLabel(for evaluations: [AgendaEvaluation]) -> String? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let now = Date()
        let upcoming = evaluations
            .compactMap { eval -> Date? in
                guard let raw = eval.date else { return nil }
                return fmt.date(from: raw) ?? fallback.date(from: raw)
            }
            .filter { $0 >= now }
            .sorted()
            .first
        guard let next = upcoming else { return nil }
        let days = Calendar.current.dateComponents([.day], from: now, to: next).day ?? 0
        if days <= 0 { return "hoje" }
        if days == 1 { return "amanhã" }
        return "\(days)d"
    }
}
