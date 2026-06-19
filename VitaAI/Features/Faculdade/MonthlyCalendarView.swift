import SwiftUI

// MARK: - MonthlyCalendarView
//
// Calm-at-rest monthly calendar inspired by the Pixio subscription calendar mock.
// Three data layers in one grid:
//   - Aulas (recurring schedule)
//   - Provas
//   - Trabalhos
//
// The selected layer uses colored discipline dots only. The chip row communicates
// type; dots communicate discipline.

struct MonthlyCalendarView: View {
    let schedule: [AgendaClassBlock]
    let evaluations: [AgendaEvaluation]

    @State private var displayedMonth: Date = .now
    @State private var selectedDay: SelectedDay?
    @State private var filter: CalendarFilter = .classes
    @State private var cachedCells: [MonthCell] = []
    @State private var viewMode: ViewMode = .month
    @State private var focusDate: Date = .now
    @State private var footerSheet: FooterSheet?

    enum FooterSheet: String, Identifiable {
        case avaliacoes
        case provas
        case aulas

        var id: String { rawValue }

        var title: String {
            switch self {
            case .avaliacoes: return "Avaliações do mês"
            case .provas: return "Provas do mês"
            case .aulas: return "Horário semanal"
            }
        }
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        case month, week, day
        var id: String { rawValue }
        var iconName: String {
            switch self {
            case .month: return "square.grid.3x3"
            case .week:  return "rectangle.split.3x1"
            case .day:   return "rectangle"
            }
        }
    }

    // MARK: - Calendar config

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday, matching Pixio AgendaCard.
        c.locale = Locale(identifier: "pt_BR")
        c.timeZone = TimeZone.current
        return c
    }()

    private let weekdayLabels = ["D", "S", "T", "Q", "Q", "S", "S"]

    // Cached formatters — SwiftUI re-evaluates computed props on every render,
    // so creating DateFormatter inline is a real perf hit on a grid view.
    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "LLLL, yyyy"
        return f
    }()

    private static let popoverHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f
    }()

    private static let dayTitleShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    private static let dayIDFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let yyyyMMddFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private var monthTitle: String {
        let raw = Self.monthTitleFormatter.string(from: displayedMonth)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private var weekTitle: String {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: focusDate) else {
            return monthTitle
        }
        let startDay = calendar.component(.day, from: interval.start)
        let endDay = calendar.component(.day, from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end)
        let monthName = Self.monthTitleFormatter.string(from: focusDate)
        let pretty = monthName.prefix(1).uppercased() + monthName.dropFirst()
        return "\(startDay) – \(endDay) \(pretty)"
    }

    private var dayTitle: String {
        Self.dayTitleShortFormatter.string(from: focusDate).capitalized
    }

    // MARK: - Week mode

    private var weekDates: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: focusDate) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    private var weekModePlaceholder: some View {
        VStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                weekDayRow(date)
            }
        }
    }

    @ViewBuilder
    private func weekDayRow(_ date: Date) -> some View {
        let aulas = aulasFor(date: date)
        let evals = evalsFor(date: date)
        let isToday = calendar.isDateInToday(date)
        let isEmpty = aulas.isEmpty && evals.isEmpty

        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                focusDate = date
                viewMode = .day
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 1) {
                    Text(weekdayShortLabel(for: date))
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(textDim)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isToday ? goldPrimary : textWarm.opacity(0.75))
                        .monospacedDigit()
                }
                .frame(width: 30)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    if isEmpty {
                        Text("Sem compromissos")
                            .font(.system(size: 10))
                            .foregroundStyle(textDim)
                            .padding(.top, 4)
                    } else {
                        ForEach(Array(evals.enumerated()), id: \.offset) { _, eval in
                            weekEvalLine(eval)
                        }
                        ForEach(Array(aulas.enumerated()), id: \.offset) { _, aula in
                            weekAulaLine(aula)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isToday ? goldPrimary.opacity(0.06) : cellBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isToday ? goldPrimary.opacity(0.18) : Color.clear, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func weekEvalLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = colorFor(subject: subject)
        let prova = isProva(eval)
        return HStack(spacing: 6) {
            Group {
                if prova {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color.opacity(0.5), radius: 2)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 1.2)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 10)
            Text(eval.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.95))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func weekAulaLine(_ aula: AgendaClassBlock) -> some View {
        let color = colorFor(subject: aula.subjectName)
        return HStack(spacing: 6) {
            Text(String(aula.startTime.prefix(5)))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.50))
                .frame(width: 36, alignment: .leading)
            Rectangle()
                .fill(color.opacity(0.85))
                .frame(width: 2, height: 12)
            Text(aula.subjectName)
                .font(.system(size: 11))
                .foregroundStyle(textWarm.opacity(0.78))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func weekdayShortLabel(for date: Date) -> String {
        let wd = calendar.component(.weekday, from: date)
        switch wd {
        case 1: return "DOM"
        case 2: return "SEG"
        case 3: return "TER"
        case 4: return "QUA"
        case 5: return "QUI"
        case 6: return "SEX"
        case 7: return "SAB"
        default: return ""
        }
    }

    // MARK: - Day mode

    private var dayModePlaceholder: some View {
        let aulas = aulasFor(date: focusDate)
        let evals = evalsFor(date: focusDate)
        return VStack(alignment: .leading, spacing: 10) {
            // Avaliações do dia (sempre no topo)
            if !evals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AVALIAÇÕES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(textDim)
                    ForEach(Array(evals.enumerated()), id: \.offset) { _, eval in
                        dayEvalCard(eval)
                    }
                }
                .padding(.bottom, 4)
            }

            // Timeline de aulas
            if aulas.isEmpty && evals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 22))
                        .foregroundStyle(goldMuted.opacity(0.35))
                    Text("Dia livre")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textWarm.opacity(0.50))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if !aulas.isEmpty {
                Text("AULAS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(textDim)
                VStack(spacing: 6) {
                    ForEach(Array(aulas.enumerated()), id: \.offset) { _, aula in
                        dayTimelineRow(aula)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayEvalCard(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = colorFor(subject: subject)
        let prova = isProva(eval)
        return HStack(alignment: .top, spacing: 10) {
            Group {
                if prova {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .shadow(color: color.opacity(0.55), radius: 3)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 1.6)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: 12, height: 12)
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(eval.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(subject)
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                    Text(prettyType(eval))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.90))
                }
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(prova ? 0.35 : 0.18), lineWidth: 0.8)
        )
    }

    private func dayTimelineRow(_ aula: AgendaClassBlock) -> some View {
        let color = colorFor(subject: aula.subjectName)
        let start = String(aula.startTime.prefix(5))
        let end = String(aula.endTime.prefix(5))
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(start)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textPrimary)
                Text(end)
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textDim)
            }
            .frame(width: 42, alignment: .trailing)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.40)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(aula.subjectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                if let room = aula.room, !room.isEmpty {
                    Text(room)
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
                if let prof = aula.professor, !prof.isEmpty {
                    Text(prof)
                        .font(.system(size: 10))
                        .foregroundStyle(textWarm.opacity(0.40))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cellBg)
        )
    }

    // MARK: - Tokens

    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.28) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var cellBg: Color { VitaColors.glassInnerLight.opacity(0.025) }
    private var cellBgToday: Color { Color.clear }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.04) }

    // MARK: - Filter

    enum CalendarFilter: String, CaseIterable, Identifiable {
        case classes = "Aulas"
        case exams = "Provas"
        case assignments = "Trabalhos"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .classes: return "book.closed"
            case .exams: return "checkmark.seal"
            case .assignments: return "doc.text"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        calendarContent
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selectedDay?.id)
        .onAppear { rebuildCellsIfNeeded() }
        .onChange(of: displayedMonth) { _, _ in rebuildCellsIfNeeded() }
    }

    @ViewBuilder
    private func footerBubbleContent(
        _ sheet: FooterSheet,
        evals: [AgendaEvaluation],
        blocks: [AgendaClassBlock]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sheet.title)
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch sheet {
                    case .avaliacoes, .provas:
                        if evals.isEmpty {
                            emptySheetState(message: "Nada marcado no mês")
                        } else {
                            ForEach(evals.sorted(by: evalSortAsc)) { eval in
                                evalRowDetail(eval)
                            }
                        }
                    case .aulas:
                        if blocks.isEmpty {
                            emptySheetState(message: "Sem aulas registradas")
                        } else {
                            ForEach(blocks.sorted(by: blockSortAsc), id: \.id) { block in
                                aulaRowDetail(block)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 300)
    }

    private func evalRowDetail(_ eval: AgendaEvaluation) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isProva(eval) ? colorFor(subject: eval.subjectName ?? "—") : Color.clear)
                .overlay(
                    Circle().stroke(colorFor(subject: eval.subjectName ?? "—"), lineWidth: 1.5)
                )
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(eval.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(eval.subjectName ?? "—")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                    if let dStr = eval.date, let d = parseDate(dStr) {
                        Text("·").foregroundStyle(VitaColors.textTertiary)
                        Text(d, format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
            }
            Spacer()
            Text(prettyType(eval))
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func aulaRowDetail(_ block: AgendaClassBlock) -> some View {
        HStack(spacing: 12) {
            Text(subjectInitial(block.subjectName))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(colorFor(subject: block.subjectName))
                .frame(width: 24, height: 24)
                .background(Circle().fill(colorFor(subject: block.subjectName).opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(block.subjectName)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("\(weekdayLabel(block.dayOfWeek)) · \(block.startTime)–\(block.endTime)")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func emptySheetState(message: String) -> some View {
        Text(message)
            .font(VitaTypography.bodyMedium)
            .foregroundStyle(VitaColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private func evalSortAsc(_ a: AgendaEvaluation, _ b: AgendaEvaluation) -> Bool {
        (a.date ?? "") < (b.date ?? "")
    }

    private func blockSortAsc(_ a: AgendaClassBlock, _ b: AgendaClassBlock) -> Bool {
        if a.dayOfWeek != b.dayOfWeek { return a.dayOfWeek < b.dayOfWeek }
        return a.startTime < b.startTime
    }

    private func weekdayLabel(_ wd: Int) -> String {
        // dayOfWeek: 1=Mon, 7=Sun (backend convention)
        let labels = ["—", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
        guard wd >= 0, wd < labels.count else { return "—" }
        return labels[wd]
    }

    private func rebuildCellsIfNeeded() {
        cachedCells = makeMonthCells()
    }

    private var calendarContent: some View {
        VStack(spacing: 16) {
            filterPills
            header
            weekdaysRow
                .padding(.horizontal, 8)
            daysGrid
                .padding(.horizontal, 8)
            disciplineLegend
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 18) {
            navButton(systemName: "chevron.left") { navigate(-1) }

            Text(monthStepperLabel)
                .font(PixioTypo.sans(size: 15, weight: .medium))
                .foregroundStyle(textPrimary)
                .lineLimit(1)

            navButton(systemName: "chevron.right") { navigate(1) }
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTitle: String {
        switch viewMode {
        case .month: return monthTitle
        case .week:  return weekTitle
        case .day:   return dayTitle
        }
    }

    private var monthStepperLabel: String {
        let raw = Self.monthTitleFormatter.string(from: displayedMonth)
        let pretty = raw.prefix(1).uppercased() + raw.dropFirst()
        let currentYear = calendar.component(.year, from: Date())
        let shownYear = calendar.component(.year, from: displayedMonth)
        if shownYear == currentYear {
            return pretty.split(separator: ",").first.map(String.init) ?? pretty
        }
        return String(pretty.replacingOccurrences(of: ",", with: ""))
    }

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewMode = mode
                    }
                } label: {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(viewMode == mode ? goldPrimary : textDim)
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(viewMode == mode
                                      ? goldPrimary.opacity(0.12)
                                      : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VitaColors.surfaceElevated.opacity(0.45))
        )
    }

    private var filterMenu: some View {
        Menu {
            ForEach(CalendarFilter.allCases) { f in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { filter = f }
                } label: {
                    if filter == f {
                        Label(f.rawValue, systemImage: "checkmark")
                    } else {
                        Text(f.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(goldMuted.opacity(0.55))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(VitaColors.glassInnerLight.opacity(0.04))
                )
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(PixioTypo.sans(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary.opacity(0.72))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navigate(_ delta: Int) {
        PixioHaptics.tap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
                displayedMonth = next
            }
            selectedDay = nil
        }
    }

    // MARK: - Filter pills

    private var filterPills: some View {
        HStack(spacing: 6) {
            ForEach(CalendarFilter.allCases) { f in
                Button {
                    PixioHaptics.tap()
                    withAnimation(.easeOut(duration: 0.18)) {
                        filter = f
                        selectedDay = nil
                        footerSheet = nil
                    }
                } label: {
                    calendarFilterChip(f)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func calendarFilterChip(_ item: CalendarFilter) -> some View {
        let selected = filter == item
        return HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(PixioTypo.sans(size: 10, weight: .semibold))
            Text(item.rawValue)
                .font(PixioTypo.sans(size: 11, weight: .semibold))
            Text("\(count(for: item))")
                .font(PixioTypo.sans(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(selected ? VitaColors.goldText.opacity(0.84) : textDim)
        }
        .foregroundStyle(selected ? VitaColors.accentLight : textWarm.opacity(0.48))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(selected ? VitaColors.accent.opacity(0.13) : VitaColors.surfaceElevated.opacity(0.48))
        )
        .overlay(
            Capsule()
                .stroke(selected ? VitaColors.accentLight.opacity(0.26) : VitaColors.surfaceBorder.opacity(0.40), lineWidth: 0.75)
        )
    }

    // MARK: - Weekdays row

    private var weekdaysRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(PixioTypo.sans(size: 11, weight: .semibold))
                    .foregroundStyle(textDim)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Days grid

    private var daysGrid: some View {
        let cells = cachedCells.isEmpty ? makeMonthCells() : cachedCells
        let rows = stride(from: 0, to: cells.count, by: 7).map { index in
            Array(cells[index..<min(index + 7, cells.count)])
        }
        let rowCount = max(1, rows.count)
        let spacing: CGFloat = 4

        return GeometryReader { geo in
            let cellSize = max(0, (geo.size.width - spacing * 6) / 7)
            VStack(spacing: spacing) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                            dayCell(rows[rowIndex][colIndex], size: cellSize)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, alignment: .top)
        }
        .frame(height: gridHeight(rows: rowCount))
    }

    @ViewBuilder
    private func dayCell(_ cell: MonthCell, size: CGFloat) -> some View {
        switch cell {
        case .empty:
            Color.clear
                .frame(width: size, height: size)
        case .day(let date, let dayNum):
            let dayAulas = aulasFor(date: date)
            let dayEvals = evaluationsFor(date: date, filter: filter)
            let visibleSubjects = subjectsFor(
                aulas: filter == .classes ? dayAulas : [],
                evaluations: dayEvals
            )
            let isToday = calendar.isDateInToday(date)
            let isSelected = selectedDay?.id == dateID(date)
            let hasContent = !visibleSubjects.isEmpty

            Button {
                guard hasContent else { return }
                PixioHaptics.tap()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    focusDate = date
                    selectedDay = SelectedDay(
                        id: dateID(date),
                        date: date,
                        aulas: filter == .classes ? dayAulas : [],
                        evals: dayEvals
                    )
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(chipFill(isSelected: isSelected, isToday: isToday))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(chipEdge(isSelected: isSelected, isToday: isToday), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1.5)

                    VStack(spacing: 0) {
                        if hasContent {
                            calendarDisciplineDots(subjects: visibleSubjects)
                                .padding(.top, 5)
                        }
                        Spacer(minLength: 0)

                        Text("\(dayNum)")
                            .font(PixioTypo.sans(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(textPrimary.opacity(isToday || isSelected ? 0.96 : 0.78))
                            .monospacedDigit()
                            .padding(.bottom, 3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
            .disabled(!hasContent)
            .vitaBubble(
                isPresented: Binding(
                    get: { selectedDay?.id == dateID(date) },
                    set: { presented in
                        if !presented { selectedDay = nil }
                    }
                ),
                arrowEdge: .top
            ) {
                if let selectedDay {
                    popoverCard(selectedDay)
                        .frame(width: 300)
                }
            }
        }
    }

    private func gridHeight(rows: Int) -> CGFloat {
        let screenW = UIScreen.main.bounds.width
        let outerPad: CGFloat = 16 * 2
        let cardPad: CGFloat = 14 * 2
        let gridPad: CGFloat = 8 * 2
        let spacing: CGFloat = 4
        let available = screenW - outerPad - cardPad - gridPad - spacing * 6
        let cellSize = max(0, available / 7)
        return CGFloat(rows) * cellSize + CGFloat(max(0, rows - 1)) * spacing
    }

    private func chipFill(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return VitaColors.surfaceBorder.opacity(0.78) }
        if isToday { return VitaColors.surfaceElevated.opacity(0.92) }
        return VitaColors.surfaceElevated.opacity(0.68)
    }

    private func chipEdge(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return VitaColors.textPrimary.opacity(0.22) }
        if isToday { return VitaColors.textPrimary.opacity(0.16) }
        return VitaColors.textPrimary.opacity(0.10)
    }

    @ViewBuilder
    private func calendarDisciplineDots(subjects: [String]) -> some View {
        let visible = Array(subjects.prefix(3))
        let overflow = max(0, subjects.count - visible.count)

        HStack(spacing: 3) {
            ForEach(visible, id: \.self) { subject in
                Circle()
                    .fill(colorFor(subject: subject))
                    .frame(width: 7, height: 7)
                    .shadow(color: colorFor(subject: subject).opacity(0.42), radius: 2)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(PixioTypo.sans(size: 7, weight: .bold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 0.5)
                    .background(Capsule().fill(VitaColors.surfaceBorder.opacity(0.60)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var disciplineLegend: some View {
        let subjects = legendSubjects
        return Group {
            if subjects.isEmpty {
                Text(emptyLegendText)
                    .font(PixioTypo.sans(size: 10, weight: .medium))
                    .foregroundStyle(textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(subjects, id: \.self) { subject in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(colorFor(subject: subject))
                                    .frame(width: 7, height: 7)
                                Text(compactSubjectName(subject))
                                    .font(PixioTypo.sans(size: 10, weight: .semibold))
                                    .foregroundStyle(textWarm.opacity(0.58))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(VitaColors.surfaceElevated.opacity(0.38)))
                            .overlay(
                                Capsule()
                                    .stroke(VitaColors.surfaceBorder.opacity(0.36), lineWidth: 0.6)
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func count(for item: CalendarFilter) -> Int {
        switch item {
        case .classes:
            return schedule.count
        case .exams:
            return monthEvaluations(kind: .exam).count
        case .assignments:
            return monthEvaluations(kind: .assignment, includesOther: true).count
        }
    }

    private var legendSubjects: [String] {
        switch filter {
        case .classes:
            return uniqueSubjects(schedule.map(\.subjectName))
        case .exams:
            return uniqueSubjects(monthEvaluations(kind: .exam).map { $0.subjectName ?? "—" })
        case .assignments:
            return uniqueSubjects(
                monthEvaluations(kind: .assignment, includesOther: true).map { $0.subjectName ?? "—" }
            )
        }
    }

    private var emptyLegendText: String {
        switch filter {
        case .classes: return "Sem aulas cadastradas para este período"
        case .exams: return "Sem provas neste mês"
        case .assignments: return "Sem trabalhos neste mês"
        }
    }

    private func uniqueSubjects(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { continue }
            result.append(cleaned)
        }
        return result.sorted { compactSubjectName($0) < compactSubjectName($1) }
    }

    private func compactSubjectName(_ subject: String) -> String {
        let cleaned = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacements = [
            "MEDICINA DE FAMÍLIA E COMUNIDADE": "MFC",
            "MEDICINA DE FAMILIA E COMUNIDADE": "MFC",
            "GINECOLOGIA E OBSTETRÍCIA": "GO",
            "GINECOLOGIA E OBSTETRICIA": "GO",
        ]
        let folded = cleaned
            .uppercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        for (key, value) in replacements {
            let normalizedKey = key.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            if folded == normalizedKey { return value }
        }
        if cleaned.count > 26 {
            return String(cleaned.prefix(25)) + "…"
        }
        return cleaned.isEmpty ? "Sem disciplina" : cleaned
    }

    private func uniqueEvalMarkers(_ evals: [AgendaEvaluation]) -> [(subject: String, isProva: Bool)] {
        var seen = Set<String>()
        var unique: [(subject: String, isProva: Bool)] = []
        for eval in evals {
            let subject = eval.subjectName ?? "—"
            let prova = isProva(eval)
            let key = "\(subject)|\(prova ? "P" : "T")"
            if seen.insert(key).inserted {
                unique.append((subject, prova))
            }
        }
        unique.sort { lhs, rhs in
            if lhs.isProva != rhs.isProva { return lhs.isProva }
            return lhs.subject < rhs.subject
        }
        return unique
    }

    private func aulaBars(subjects: [String]) -> some View {
        // Avatar-style identity: cor da materia + letra inicial.
        // Substitui barras genericas por algo que identifica sem precisar de legenda.
        let maxAvatars = 2
        let visible = Array(subjects.prefix(maxAvatars))
        let extra = subjects.count - maxAvatars
        return HStack(spacing: 3) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, subject in
                subjectAvatar(subject)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(goldMuted.opacity(0.55))
                    .padding(.leading, 1)
            }
        }
    }

    private func subjectAvatar(_ subject: String) -> some View {
        let color = colorFor(subject: subject)
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.42), radius: 2)
    }

    private func subjectInitial(_ subject: String) -> String {
        // Primeira letra da primeira palavra significativa.
        // Ignora preposicoes/artigos curtos que não ajudam a identificar.
        let skip: Set<String> = ["de", "da", "do", "das", "dos", "e", "em", "a", "o", "na", "no"]
        let words = subject
            .split(separator: " ")
            .map { String($0) }
            .filter { !skip.contains($0.lowercased()) && !$0.isEmpty }
        guard let first = words.first, let ch = first.first else {
            return String(subject.prefix(1)).uppercased()
        }
        return String(ch).uppercased()
    }

    /// Unique (matéria, tipo) marker for a day.
    /// Shape/fill codifies tipo: prova = ● solid com glow, trabalho = ○ ring.
    /// Cor = matéria (mesma das letras de aula no rodapé, hash estável).
    private func evalMarkers(evals: [AgendaEvaluation]) -> some View {
        // Deduplica por (subjectName, categoria)
        var seen = Set<String>()
        var unique: [(subject: String, isProva: Bool)] = []
        for e in evals {
            let subject = e.subjectName ?? "—"
            let isP = isProva(e)
            let key = "\(subject)|\(isP ? "P" : "T")"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append((subject, isP))
            }
        }

        // Prova tem prioridade visual, aparece primeiro.
        unique.sort { lhs, rhs in
            if lhs.isProva != rhs.isProva { return lhs.isProva }
            return lhs.subject < rhs.subject
        }

        let maxMarkers = 3
        let visible = Array(unique.prefix(maxMarkers))
        let extra = unique.count - maxMarkers

        return HStack(spacing: 3) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                evalMarker(subject: item.subject, isProva: item.isProva)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(goldMuted.opacity(0.55))
            }
        }
    }

    private func evalMarker(subject: String, isProva: Bool) -> some View {
        let color = colorFor(subject: subject)
        return Group {
            if isProva {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.55), radius: 2.5)
            } else {
                Circle()
                    .stroke(color, lineWidth: 1.3)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Legend (visible explanation of marker shapes + letter colors)

    private var calendarLegend: some View {
        HStack(spacing: 12) {
            legendItem(icon: legendDot(filled: true), text: "prova")
            legendItem(icon: legendDot(filled: false), text: "trabalho")
            HStack(spacing: 3) {
                Text("A")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(goldPrimary.opacity(0.80))
                Text("matéria")
                    .font(.system(size: 10))
                    .foregroundStyle(textDim)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func legendItem<Icon: View>(icon: Icon, text: String) -> some View {
        HStack(spacing: 4) {
            icon
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(textDim)
        }
    }

    @ViewBuilder
    private func legendDot(filled: Bool) -> some View {
        if filled {
            Circle()
                .fill(goldPrimary.opacity(0.85))
                .frame(width: 6, height: 6)
        } else {
            Circle()
                .stroke(goldPrimary.opacity(0.85), lineWidth: 1)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Footer summary (clicável: cada stat abre lista detalhada)

    private var monthFooter: some View {
        let monthEvals = evaluations.filter { eval in
            guard let dStr = eval.date, let d = parseDate(dStr) else { return false }
            return calendar.isDate(d, equalTo: displayedMonth, toGranularity: .month)
        }
        let provasCount = monthEvals.filter { isProva($0) }.count
        let weeklyAulas = schedule.count

        let provas = monthEvals.filter { isProva($0) }

        return HStack(spacing: 10) {
            footerStatButton(
                value: "\(monthEvals.count)",
                label: monthEvals.count == 1 ? "avaliação" : "avaliações",
                action: {
                    footerSheet = (footerSheet == .avaliacoes) ? nil : .avaliacoes
                }
            )
            .vitaBubble(
                isPresented: Binding(
                    get: { footerSheet == .avaliacoes },
                    set: { if !$0 { footerSheet = nil } }
                ),
                arrowEdge: .top
            ) {
                footerBubbleContent(.avaliacoes, evals: monthEvals, blocks: [])
            }

            divider

            footerStatButton(
                value: "\(provasCount)",
                label: provasCount == 1 ? "prova" : "provas",
                action: {
                    footerSheet = (footerSheet == .provas) ? nil : .provas
                }
            )
            .vitaBubble(
                isPresented: Binding(
                    get: { footerSheet == .provas },
                    set: { if !$0 { footerSheet = nil } }
                ),
                arrowEdge: .top
            ) {
                footerBubbleContent(.provas, evals: provas, blocks: [])
            }

            divider

            footerStatButton(
                value: "\(weeklyAulas)",
                label: "aulas/sem",
                action: {
                    footerSheet = (footerSheet == .aulas) ? nil : .aulas
                }
            )
            .vitaBubble(
                isPresented: Binding(
                    get: { footerSheet == .aulas },
                    set: { if !$0 { footerSheet = nil } }
                ),
                arrowEdge: .top
            ) {
                footerBubbleContent(.aulas, evals: [], blocks: schedule)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(glassBorder)
            .frame(width: 1, height: 14)
    }

    private func footerStatButton(value: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(goldPrimary.opacity(0.85))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(textDim)
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(textDim.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Popover layer

    @ViewBuilder
    private func popoverLayer(_ day: SelectedDay) -> some View {
        // vita-modals-ignore: legacy day-popover, migrar pra .sheet(item:)+VitaSheet em refactor separado
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                        selectedDay = nil
                    }
                }

            popoverCard(day)
                .padding(.horizontal, 32)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    )
                )
        }
    }

    private func popoverCard(_ day: SelectedDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            popoverHeader(day)
            if !day.evals.isEmpty {
                popoverSection(label: "Avaliações") {
                    ForEach(Array(day.evals.enumerated()), id: \.offset) { _, eval in
                        evalRow(eval)
                    }
                }
            }
            if !day.aulas.isEmpty {
                popoverSection(label: "Aulas") {
                    ForEach(Array(day.aulas.enumerated()), id: \.offset) { _, aula in
                        aulaRow(aula)
                    }
                }
            }
            popoverFooter(day)
        }
        .padding(.vertical, 4)
    }

    private func popoverHeader(_ day: SelectedDay) -> some View {
        let title = Self.popoverHeaderFormatter.string(from: day.date).capitalized

        return HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textWarm.opacity(0.40))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(VitaColors.glassInnerLight.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func popoverSection<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(textDim)
            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func evalRow(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = colorFor(subject: subject)
        let prova = isProva(eval)
        return HStack(spacing: 10) {
            // Mesma linguagem visual das celulas: solid = prova, ring = trabalho
            ZStack {
                if prova {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .shadow(color: color.opacity(0.55), radius: 3)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 1.6)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(eval.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                Text(subject)
                    .font(.system(size: 10))
                    .foregroundStyle(textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(prettyType(eval))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color.opacity(0.95))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(color.opacity(prova ? 0.18 : 0.10))
                )
        }
    }

    private func prettyType(_ eval: AgendaEvaluation) -> String {
        switch eval.calendarKind {
        case .exam: return "Prova"
        case .assignment: return "Trabalho"
        case .other: return "Trabalho"
        }
    }

    private func isProva(_ eval: AgendaEvaluation) -> Bool {
        eval.calendarKind == .exam
    }

    private func aulaRow(_ aula: AgendaClassBlock) -> some View {
        let color = colorFor(subject: aula.subjectName)
        return HStack(spacing: 10) {
            Text(String(aula.startTime.prefix(5)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(goldMuted.opacity(0.55))
                .frame(width: 38, alignment: .trailing)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(aula.subjectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if let room = aula.room, !room.isEmpty {
                    Text(room)
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }
            Spacer()
        }
    }

    private func popoverFooter(_ day: SelectedDay) -> some View {
        HStack(spacing: 4) {
            Text("\(day.aulas.count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldPrimary)
            Text(day.aulas.count == 1 ? "aula" : "aulas")
                .font(.system(size: 10))
                .foregroundStyle(textDim)
            Text("·")
                .font(.system(size: 10))
                .foregroundStyle(textDim)
                .padding(.horizontal, 2)
            Text("\(day.evals.count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldPrimary)
            Text(day.evals.count == 1 ? "avaliação" : "avaliações")
                .font(.system(size: 10))
                .foregroundStyle(textDim)
            Spacer()
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(glassBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Data helpers

    private func makeMonthCells() -> [MonthCell] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [MonthCell] = Array(repeating: .empty, count: leading)
        let range = calendar.range(of: .day, in: .month, for: displayedMonth) ?? 1..<29
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) {
                cells.append(.day(date: date, dayNum: day))
            }
        }
        while cells.count % 7 != 0 {
            cells.append(.empty)
        }
        return cells
    }

    private func aulasFor(date: Date) -> [AgendaClassBlock] {
        let weekday = calendar.component(.weekday, from: date)
        // Foundation: 1=Sun ... 7=Sat. API dayOfWeek: 1=Mon ... 7=Sun.
        let apiWeekday = ((weekday + 5) % 7) + 1
        return schedule
            .filter { $0.dayOfWeek == apiWeekday }
            .sorted { $0.startTime < $1.startTime }
    }

    private func aulaSubjectsFor(date: Date) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for a in aulasFor(date: date) where !seen.contains(a.subjectName) {
            seen.insert(a.subjectName)
            result.append(a.subjectName)
        }
        return result
    }

    private func evalsFor(date: Date) -> [AgendaEvaluation] {
        evaluations.filter { eval in
            guard let dStr = eval.date, let d = parseDate(dStr) else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func evaluationsFor(date: Date, filter: CalendarFilter) -> [AgendaEvaluation] {
        evalsFor(date: date).filter { eval in
            switch filter {
            case .classes:
                return false
            case .exams:
                return eval.calendarKind == .exam
            case .assignments:
                return eval.calendarKind == .assignment || eval.calendarKind == .other
            }
        }
    }

    private func monthEvaluations(kind: AgendaEvaluationKind, includesOther: Bool = false) -> [AgendaEvaluation] {
        evaluations.filter { eval in
            guard let raw = eval.date, let date = parseDate(raw),
                  calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
            else {
                return false
            }
            if eval.calendarKind == kind { return true }
            return includesOther && eval.calendarKind == .other
        }
    }

    private func subjectsFor(aulas: [AgendaClassBlock], evaluations: [AgendaEvaluation]) -> [String] {
        uniqueSubjects(aulas.map(\.subjectName) + evaluations.map { $0.subjectName ?? "—" })
    }

    private func evalSubjectsFor(date: Date) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for e in evalsFor(date: date) {
            let s = e.subjectName ?? "—"
            if !seen.contains(s) {
                seen.insert(s)
                result.append(s)
            }
        }
        return result
    }

    private func parseDate(_ s: String) -> Date? {
        if let d = Self.isoFractionalFormatter.date(from: s) { return d }
        if let d = Self.isoFormatter.date(from: s) { return d }
        if let d = Self.yyyyMMddFormatter.date(from: s) { return d }
        return nil
    }

    private func dateID(_ date: Date) -> String {
        Self.dayIDFormatter.string(from: date)
    }

    // MARK: - Subject color (deterministic by name)

    private let subjectPalette: [Color] = [
        VitaColors.accentHover,
        VitaTokens.PrimitiveColors.cyan400,
        VitaTokens.PrimitiveColors.indigo400,
        VitaTokens.PrimitiveColors.green400,
        VitaTokens.PrimitiveColors.orange400,
        VitaTokens.PrimitiveColors.red400,
        VitaTokens.PrimitiveColors.teal400,
        VitaTokens.PrimitiveColors.amber400,
    ]

    private func colorFor(subject: String) -> Color {
        var sum: UInt32 = 0
        for byte in subject.utf8 {
            sum = (sum &* 31) &+ UInt32(byte)
        }
        return subjectPalette[Int(sum) % subjectPalette.count]
    }
}

// MARK: - Models

private enum MonthCell {
    case empty
    case day(date: Date, dayNum: Int)
}

private struct SelectedDay: Equatable {
    let id: String
    let date: Date
    let aulas: [AgendaClassBlock]
    let evals: [AgendaEvaluation]

    static func == (lhs: SelectedDay, rhs: SelectedDay) -> Bool {
        lhs.id == rhs.id
    }
}
