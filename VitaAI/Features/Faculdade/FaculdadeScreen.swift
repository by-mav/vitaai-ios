import SwiftUI

// MARK: - FaculdadeScreen
// PAGE_SPEC section 2: "Como esta minha vida academica real?"
// GOLD theme. 5 blocks: Summary, Agenda, Disciplines, Evaluations, History.

struct FaculdadeScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: FaculdadeViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                faculdadeContent(vm: vm)
            } else {
                FaculdadeSkeleton()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = FaculdadeViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }

    @ViewBuilder
    private func faculdadeContent(vm: FaculdadeViewModel) -> some View {
        switch vm.state {
        case .loading:
            FaculdadeSkeleton()

        case .empty:
            VitaEmptyState(
                title: String(localized: "faculdade_empty_title"),
                message: String(localized: "faculdade_empty_message"),
                actionText: String(localized: "faculdade_empty_action")
            ) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 48))
                    .foregroundStyle(VitaColors.accent)
            }

        case .error(let message):
            VitaErrorState(
                title: String(localized: "faculdade_error_title"),
                message: message,
                onRetry: { Task { await vm.load() } }
            )

        case .loaded:
            ScrollView(showsIndicators: false) {
                VStack(spacing: VitaTokens.Spacing.lg) {
                    summarySection(vm: vm)

                    if !vm.agendaItems.isEmpty {
                        agendaSection(vm: vm)
                    }

                    if !vm.disciplines.isEmpty {
                        disciplinesSection(vm: vm)
                    }

                    if !vm.evaluations.isEmpty {
                        evaluationsSection(vm: vm)
                    }

                    if !vm.history.isEmpty {
                        historySection(vm: vm)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, VitaTokens.Spacing.sm)
            }
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Block 2.1: Resumo Academico

    @ViewBuilder
    private func summarySection(vm: FaculdadeViewModel) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "faculdade_summary_title"))

            VStack(spacing: VitaTokens.Spacing.sm) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    summaryStatCard(
                        icon: "calendar.badge.clock",
                        label: String(localized: "faculdade_semester"),
                        value: vm.summary.currentSemester.isEmpty ? "--" : vm.summary.currentSemester
                    )
                    summaryStatCard(
                        icon: "book.closed",
                        label: String(localized: "faculdade_disciplines"),
                        value: "\(vm.summary.disciplineCount)"
                    )
                }
                HStack(spacing: VitaTokens.Spacing.sm) {
                    summaryStatCard(
                        icon: "star",
                        label: String(localized: "faculdade_avg_grade"),
                        value: vm.summary.averageGrade.map { String(format: "%.1f", $0) } ?? "--"
                    )
                    summaryStatCard(
                        icon: "chart.pie",
                        label: String(localized: "faculdade_avg_attendance"),
                        value: vm.summary.averageAttendance.map { String(format: "%.0f%%", $0) } ?? "--"
                    )
                }
                if vm.summary.absencesAtRisk > 0 {
                    riskBanner(count: vm.summary.absencesAtRisk)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func summaryStatCard(icon: String, label: String, value: String) -> some View {
        VitaGlassCard {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 32, height: 32)
                    .background(VitaColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                    Text(label)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                    Text(value)
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                }
                Spacer()
            }
            .padding(VitaTokens.Spacing.md)
        }
    }

    @ViewBuilder
    private func riskBanner(count: Int) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.dataRed)
            Text(String(localized: "faculdade_risk_banner \(count)"))
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.dataRed)
            Spacer()
        }
        .padding(VitaTokens.Spacing.md)
        .background(VitaColors.dataRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md)
                .stroke(VitaColors.dataRed.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Block 2.2: Agenda Academica

    @ViewBuilder
    private func agendaSection(vm: FaculdadeViewModel) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "faculdade_agenda_title"))

            VStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(vm.agendaItems.prefix(8)) { item in
                    agendaRow(item: item)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func agendaRow(item: AgendaItemVM) -> some View {
        let accentColor: Color = {
            switch item.type {
            case .exam: return VitaColors.dataRed
            case .classBlock: return VitaColors.dataBlue
            case .event: return VitaColors.accent
            }
        }()

        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor.opacity(0.7))
                .frame(width: 3)

            HStack(spacing: VitaTokens.Spacing.md) {
                if let daysUntil = item.daysUntil {
                    Text(String(localized: "faculdade_days_until \(daysUntil)"))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(accentColor)
                        .frame(width: 36, alignment: .leading)
                } else if let time = item.time {
                    Text(time)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accentColor.opacity(0.8))
                        .frame(width: 36, alignment: .leading)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                        .fill(accentColor.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: item.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                    Text(item.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let date = item.date {
                    Text(formatShortDate(date))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.md)
            .padding(.vertical, VitaTokens.Spacing.sm + 2)
        }
        .frame(maxWidth: .infinity)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .stroke(accentColor.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Block 2.3: Disciplinas do Semestre

    @ViewBuilder
    private func disciplinesSection(vm: FaculdadeViewModel) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            SectionHeader(
                title: String(localized: "faculdade_disciplines_title"),
                subtitle: "\(vm.disciplines.count)"
            )

            VStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(vm.disciplines) { disc in
                    disciplineCard(disc: disc)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func disciplineCard(disc: DisciplineCardVM) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                HStack(spacing: VitaTokens.Spacing.md) {
                    disciplineIcon(slug: disc.iconSlug)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                        Text(disc.name)
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)

                        if let prof = disc.professor {
                            HStack(spacing: VitaTokens.Spacing.xs) {
                                Image(systemName: "person")
                                    .font(.system(size: 10))
                                Text(prof)
                                    .font(VitaTypography.labelSmall)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    Spacer()

                    if disc.riskLevel != .none {
                        riskBadge(level: disc.riskLevel)
                    }
                }

                HStack(spacing: VitaTokens.Spacing.sm) {
                    gradeChip(label: "G1", value: disc.g1)
                    gradeChip(label: "G2", value: disc.g2)
                    gradeChip(label: "G3", value: disc.g3)
                    if let fg = disc.finalGrade {
                        Spacer()
                        VStack(spacing: 0) {
                            Text(String(localized: "faculdade_final"))
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                            Text(String(format: "%.1f", fg))
                                .font(VitaTypography.titleMedium)
                                .foregroundStyle(fg >= 6.0 ? VitaColors.dataGreen : VitaColors.dataRed)
                        }
                    } else {
                        Spacer()
                    }
                }

                HStack(spacing: VitaTokens.Spacing.lg) {
                    if let att = disc.attendance {
                        HStack(spacing: VitaTokens.Spacing.xs) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 11))
                            Text(String(format: "%.0f%%", att))
                                .font(VitaTypography.labelMedium)
                        }
                        .foregroundStyle(att >= 75 ? VitaColors.textSecondary : VitaColors.dataRed)
                    }

                    if disc.absences > 0 {
                        HStack(spacing: VitaTokens.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 11))
                            Text(String(localized: "faculdade_absences \(disc.absences)"))
                                .font(VitaTypography.labelMedium)
                        }
                        .foregroundStyle(VitaColors.dataAmber)
                    }

                    if let status = disc.status, !status.isEmpty {
                        Spacer()
                        Text(status)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
            .padding(VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func disciplineIcon(slug: String) -> some View {
        let assetName = "disc-\(slug)"
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                    .fill(VitaColors.accent.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.accent)
            }
        }
    }

    @ViewBuilder
    private func gradeChip(label: String, value: Double?) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(
                    value.map { $0 >= 6.0 ? VitaColors.dataGreen : ($0 >= 4.0 ? VitaColors.dataAmber : VitaColors.dataRed) }
                    ?? VitaColors.textTertiary
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .background(VitaColors.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))
    }

    @ViewBuilder
    private func riskBadge(level: RiskLevel) -> some View {
        let (color, text): (Color, String) = {
            switch level {
            case .critical: return (VitaColors.dataRed, String(localized: "faculdade_risk_critical"))
            case .high: return (VitaColors.dataAmber, String(localized: "faculdade_risk_high"))
            case .medium: return (VitaColors.dataAmber.opacity(0.7), String(localized: "faculdade_risk_medium"))
            case .none: return (VitaColors.textTertiary, "")
            }
        }()

        Text(text)
            .font(VitaTypography.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, VitaTokens.Spacing.sm)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Block 2.4: Avaliacoes

    @ViewBuilder
    private func evaluationsSection(vm: FaculdadeViewModel) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "faculdade_evaluations_title"))

            VStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(vm.evaluations.prefix(10)) { eval in
                    evaluationRow(eval: eval)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func evaluationRow(eval: EvaluationVM) -> some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                    .fill(VitaColors.accent.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: evaluationIcon(type: eval.type))
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.accent)
            }

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(eval.title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: VitaTokens.Spacing.xs) {
                    if let disc = eval.discipline {
                        Text(disc)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .lineLimit(1)
                    }
                    if let date = eval.date {
                        Text(formatShortDate(date))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }

            Spacer()

            if let score = eval.score {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.1f", score))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(
                            score >= 6.0 ? VitaColors.dataGreen
                            : score >= 4.0 ? VitaColors.dataAmber
                            : VitaColors.dataRed
                        )
                    if let max = eval.maxScore {
                        Text("/\(String(format: "%.0f", max))")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            } else if let grade = eval.grade {
                Text(grade)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            } else {
                evaluationStatusBadge(status: eval.status)
            }
        }
        .padding(VitaTokens.Spacing.md)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func evaluationStatusBadge(status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status.lowercased() {
            case "graded", "avaliado": return (VitaColors.dataGreen, status)
            case "pending", "pendente": return (VitaColors.dataAmber, status)
            case "submitted", "entregue": return (VitaColors.dataBlue, status)
            default: return (VitaColors.textTertiary, status)
            }
        }()

        Text(label)
            .font(VitaTypography.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, VitaTokens.Spacing.sm)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Block 2.5: Historico

    @ViewBuilder
    private func historySection(vm: FaculdadeViewModel) -> some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "faculdade_history_title"))

            VStack(spacing: VitaTokens.Spacing.md) {
                ForEach(vm.history) { semester in
                    historySemesterCard(semester: semester)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func historySemesterCard(semester: HistorySemesterVM) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                HStack {
                    Text(semester.semester)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    HStack(spacing: VitaTokens.Spacing.sm) {
                        if semester.approvedCount > 0 {
                            HStack(spacing: VitaTokens.Spacing.xxs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.dataGreen)
                                Text("\(semester.approvedCount)")
                                    .font(VitaTypography.labelSmall)
                                    .foregroundStyle(VitaColors.dataGreen)
                            }
                        }
                        if semester.failedCount > 0 {
                            HStack(spacing: VitaTokens.Spacing.xxs) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.dataRed)
                                Text("\(semester.failedCount)")
                                    .font(VitaTypography.labelSmall)
                                    .foregroundStyle(VitaColors.dataRed)
                            }
                        }
                    }
                }

                VStack(spacing: VitaTokens.Spacing.xs) {
                    ForEach(semester.disciplines) { disc in
                        HStack {
                            Image(systemName: disc.approved ? "checkmark" : "xmark")
                                .font(.system(size: 10))
                                .foregroundStyle(disc.approved ? VitaColors.dataGreen : VitaColors.dataRed)
                                .frame(width: 16)

                            Text(disc.name)
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            if let grade = disc.finalGrade {
                                Text(String(format: "%.1f", grade))
                                    .font(VitaTypography.labelMedium)
                                    .foregroundStyle(disc.approved ? VitaColors.dataGreen : VitaColors.dataRed)
                            } else {
                                Text(disc.status)
                                    .font(VitaTypography.labelSmall)
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(VitaTokens.Spacing.lg)
        }
    }

    // MARK: - Helpers

    private func evaluationIcon(type: String) -> String {
        switch type.lowercased() {
        case "prova", "exam", "test": return "doc.text.fill"
        case "trabalho", "assignment": return "doc.on.clipboard.fill"
        case "quiz": return "questionmark.circle.fill"
        case "seminario", "seminar": return "person.3.fill"
        default: return "pencil.and.list.clipboard"
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            return String(localized: "faculdade_today")
        }
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: date)
    }
}

// MARK: - FaculdadeSkeleton

struct FaculdadeSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                ShimmerText(width: 140, height: 10)
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                    .padding(.top, VitaTokens.Spacing.md)

                VStack(spacing: VitaTokens.Spacing.sm) {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        ShimmerBox(height: 64, cornerRadius: VitaTokens.Radius.lg)
                        ShimmerBox(height: 64, cornerRadius: VitaTokens.Radius.lg)
                    }
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        ShimmerBox(height: 64, cornerRadius: VitaTokens.Radius.lg)
                        ShimmerBox(height: 64, cornerRadius: VitaTokens.Radius.lg)
                    }
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)

                ShimmerText(width: 120, height: 10)
                    .padding(.horizontal, VitaTokens.Spacing.xl)

                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 52, cornerRadius: VitaTokens.Radius.lg)
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                }

                ShimmerText(width: 160, height: 10)
                    .padding(.horizontal, VitaTokens.Spacing.xl)

                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 120, cornerRadius: VitaTokens.Radius.lg)
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                }

                Spacer().frame(height: 120)
            }
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }
}
