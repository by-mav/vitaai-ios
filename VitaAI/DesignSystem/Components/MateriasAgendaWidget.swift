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
        .glassCard(cornerRadius: 16)
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
                // Dynamic column headers — derived from union of all subjects'
                // evaluations. Supports any portal/faculty (AP1/AS/Recuperação/P1/etc.)
                // without hardcoded ULBRA-only schema.
                let columns = canonicalColumns(for: subjects)
                HStack(spacing: 0) {
                    Color.clear.frame(width: 7)
                    Text("DISCIPLINA")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(columns, id: \.self) { col in
                        Text(col).frame(width: 34, alignment: .center)
                    }
                    Text("FREQ").frame(width: 40, alignment: .center)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textWarm.opacity(0.60))
                .kerning(0.3)
                .padding(.horizontal, 8)

                // Rows
                VStack(spacing: 0) {
                    ForEach(subjects) { subject in
                        materiaRow(subject, columns: columns)
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
    private func materiaRow(_ subject: GradeSubject, columns: [String]) -> some View {
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
                ForEach(columns, id: \.self) { col in
                    gradeCell(scoreFor(subject: subject, column: col))
                }
                freqCell(subject.attendance)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dynamic columns

    /// Resolve the score this subject has for a given column label by matching
    /// against `evaluations[]` first (preferred — what the LLM extracted from
    /// the portal verbatim), falling back to the legacy grade1/2/3/finalGrade
    /// for subjects whose backend hasn't populated `evaluations` yet.
    private func scoreFor(subject: GradeSubject, column: String) -> Double? {
        if let match = subject.evaluations.first(where: { $0.title.caseInsensitiveCompare(column) == .orderedSame }) {
            return match.score
        }
        // Legacy fallback (back-compat).
        switch column.uppercased() {
        case "AP1", "P1", "N1": return subject.grade1
        case "AP2", "P2", "N2": return subject.grade2
        case "AP3", "P3", "N3": return subject.grade3
        case "AF", "MÉDIA", "MEDIA", "FINAL": return subject.finalGrade
        case "AS": return subject.grade3 // ULBRA legacy mapping
        default: return nil
        }
    }

    /// Compute the column list for the materia table by aggregating evaluation
    /// titles across subjects, then sorting (partial → final → makeup → other).
    /// Caps at 5 columns to fit on the home screen.
    private func canonicalColumns(for subjects: [GradeSubject]) -> [String] {
        struct Col: Hashable {
            let title: String
            let kind: String
            let sequence: Int
        }
        var seen: [String: Col] = [:]
        for s in subjects {
            for e in s.evaluations {
                let key = e.title.uppercased()
                if seen[key] == nil {
                    seen[key] = Col(title: e.title, kind: e.kind ?? "other", sequence: e.sequence ?? 99)
                }
            }
        }
        if seen.isEmpty {
            // Backend hasn't shipped evaluations[] yet — fall back to legacy ULBRA columns.
            return ["AP1", "AP2", "AF", "AS"]
        }
        let kindOrder: [String: Int] = ["partial": 0, "final": 1, "makeup": 2]
        let cols = Array(seen.values).sorted { a, b in
            let ka = kindOrder[a.kind] ?? 9
            let kb = kindOrder[b.kind] ?? 9
            if ka != kb { return ka < kb }
            return a.sequence < b.sequence
        }
        return Array(cols.prefix(5)).map { $0.title.uppercased() }
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
