import SwiftUI

// MARK: - MateriasAgendaWidget
//
// Shared pager widget: Matérias ↔ Agenda tabs with swipe gesture.
// Used by both DashboardScreen and FaculdadeHomeScreen.
// ANY change here reflects in BOTH places — that's the point.

struct MateriasAgendaWidget: View {
    let subjects: [GradeSubject]
    let schedule: [AgendaClassBlock]
    let evaluations: [AgendaEvaluation]
    var onNavigateToDiscipline: ((String, String) -> Void)?

    @State private var activeTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab pills
            HStack(spacing: 0) {
                pagerTab(title: "Matérias", icon: "graduationcap", index: 0)
                pagerTab(title: "Agenda", icon: "calendar", index: 1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Content — swap with gesture
            Group {
                if activeTab == 0 {
                    materiasContent()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                } else {
                    agendaContent()
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
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(VitaColors.surfaceCard.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: activeTab)
    }

    // MARK: - Tab pill

    @ViewBuilder
    private func pagerTab(title: String, icon: String, index: Int) -> some View {
        let selected = activeTab == index
        Button {
            activeTab = index
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(selected ? VitaColors.accentHover : VitaColors.textWarm.opacity(0.30))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? VitaColors.accentHover.opacity(0.08) : Color.clear)
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
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
            } else {
                // Column headers
                HStack(spacing: 0) {
                    Color.clear.frame(width: 6)
                    Text("DISCIPLINA")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AP1").frame(width: 32, alignment: .center)
                    Text("AP2").frame(width: 32, alignment: .center)
                    Text("AF").frame(width: 32, alignment: .center)
                    Text("AS").frame(width: 32, alignment: .center)
                    Text("FREQ").frame(width: 38, alignment: .center)
                }
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                .padding(.horizontal, 4)

                // Rows
                VStack(spacing: 0) {
                    ForEach(subjects) { subject in
                        materiaRow(subject)
                        if subject.id != subjects.last?.id {
                            Rectangle()
                                .fill(VitaColors.textWarm.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 12)
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

        Button {
            onNavigateToDiscipline?(subject.subjectName, subject.subjectName)
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 1))
                    .padding(.trailing, 4)
                Text(shortSubjectName(subject.subjectName))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                gradeCell(subject.grade1)
                gradeCell(subject.grade2)
                gradeCell(subject.finalGrade)
                gradeCell(subject.grade3)
                freqCell(subject.attendance)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cells

    @ViewBuilder
    private func gradeCell(_ grade: Double?) -> some View {
        Text(grade.map { String(format: "%.1f", $0) } ?? "--")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(grade != nil ? VitaColors.textWarm.opacity(0.82) : VitaColors.textWarm.opacity(0.20))
            .frame(width: 32, alignment: .center)
    }

    @ViewBuilder
    private func freqCell(_ freq: Double?) -> some View {
        Text(freq.map { String(format: "%.0f%%", $0) } ?? "--")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(freq.map { freqColor($0) } ?? VitaColors.textWarm.opacity(0.20))
            .frame(width: 38, alignment: .center)
    }

    // MARK: - Helpers

    private func freqColor(_ freq: Double) -> Color {
        if freq >= 85 { return VitaColors.dataGreen }
        if freq >= 75 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    private func shortSubjectName(_ subject: String) -> String {
        subject
            .replacingOccurrences(of: "(?i)\\bMÉDICA\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\bMÉDICO\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\b(III|II|I)\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",.*$", with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
