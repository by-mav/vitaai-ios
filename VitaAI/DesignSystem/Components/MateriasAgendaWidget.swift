import SwiftUI

// MARK: - MateriasAgendaWidget
//
// Shared pager widget: Matérias ↔ Agenda tabs with swipe gesture.
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

    // Conic border colors (same as VitaGlassCard for consistency)
    private let conicGold120 = Color(red: 1.0, green: 200/255, blue: 120/255)
    private let conicGold100 = Color(red: 1.0, green: 180/255, blue: 100/255)

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

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
        .padding(.bottom, 4)
        .background {
            ZStack {
                // Real blur — lets background bleed through
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                // Dark warm tint to keep gold brand feel
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.72))
                // Subtle gold inner glow (top-left)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [goldPrimary.opacity(0.06), .clear],
                            center: UnitPoint(x: 0.15, y: 0.0),
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Specular top highlight
        .overlay {
            VStack(spacing: 0) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.05), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                    .padding(.horizontal, 24)
                    .padding(.top, 1)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        // Conic gold border (same angular gradient as VitaGlassCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: conicGold120.opacity(0.12), location: 0.0),
                            .init(color: conicGold100.opacity(0.04), location: 0.25),
                            .init(color: conicGold120.opacity(0.07), location: 0.40),
                            .init(color: conicGold100.opacity(0.02), location: 0.60),
                            .init(color: conicGold120.opacity(0.09), location: 0.80),
                            .init(color: conicGold120.opacity(0.12), location: 1.0),
                        ]),
                        center: .center,
                        startAngle: .degrees(200),
                        endAngle: .degrees(200 + 360)
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 10)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.2), value: activeTab)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabPill(title: "Matérias", icon: "graduationcap", index: 0)
            tabPill(title: "Agenda", icon: "calendar", index: 1)
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
                // Column headers
                HStack(spacing: 0) {
                    Color.clear.frame(width: 7)
                    Text("DISCIPLINA")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AP1").frame(width: 34, alignment: .center)
                    Text("AP2").frame(width: 34, alignment: .center)
                    Text("AF").frame(width: 34, alignment: .center)
                    Text("AS").frame(width: 34, alignment: .center)
                    Text("FREQ").frame(width: 40, alignment: .center)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(textWarm.opacity(0.35))
                .kerning(0.3)
                .padding(.horizontal, 8)

                // Rows
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

        Button {
            onNavigateToDiscipline?(subject.id, subject.subjectName)
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .padding(.trailing, 4)
                Text(shortSubjectName(subject.subjectName))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textWarm.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                gradeCell(subject.grade1)
                gradeCell(subject.grade2)
                gradeCell(subject.finalGrade)
                gradeCell(subject.grade3)
                freqCell(subject.attendance)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cells

    @ViewBuilder
    private func gradeCell(_ grade: Double?) -> some View {
        Text(grade.map { String(format: "%.1f", $0) } ?? "–")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(grade != nil ? textWarm.opacity(0.85) : textWarm.opacity(0.18))
            .frame(width: 34, alignment: .center)
    }

    @ViewBuilder
    private func freqCell(_ freq: Double?) -> some View {
        Text(freq.map { String(format: "%.0f%%", $0) } ?? "–")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(freq.map { freqColor($0) } ?? textWarm.opacity(0.18))
            .frame(width: 40, alignment: .center)
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
