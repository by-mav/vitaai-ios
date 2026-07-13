import SwiftUI

// MARK: - JornadaWeekAgenda
//
// AGENDA (Minha Faculdade) — SEMANA (padrao) ou MÊS, no MESMO design:
//  · nav ‹ › (semana/mes conforme o modo)
//  · faixa/grid com hoje destacado + bolinhas COLORIDAS por tipo
//    (aula=ouro, prova=roxo, trabalho=verde-agua)
//  · lista dos eventos do dia selecionado (cor+icone+label por tipo)
// Convencao de dados IDENTICA ao antigo calendario: dayOfWeek 1=Mon..7=Sun;
// parseDate ISO/yyyyMMdd; isDate inSameDayAs. Rafael 2026-07-13 (mockup).

struct JornadaWeekAgenda: View {
    let schedule: [AgendaClassBlock]
    let evaluations: [AgendaEvaluation]
    var onOpenEval: ((AgendaEvaluation) -> Void)? = nil

    private enum Mode { case week, month }
    @State private var mode: Mode = .week
    @State private var selected: Date = Calendar.current.startOfDay(for: Date())

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2  // segunda
        c.locale = Locale(identifier: "pt_BR")
        return c
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            card
        }
    }

    // MARK: Header (label + switcher Semana/Mes)

    private var header: some View {
        HStack {
            Text(mode == .week ? "AGENDA DA SEMANA" : "AGENDA DO MÊS")
                .font(VitaTypography.labelSmall)
                .fontWeight(.semibold)
                .kerning(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            Spacer()
            HStack(spacing: 2) {
                segButton("Semana", active: mode == .week) { mode = .week }
                segButton("Mês", active: mode == .month) { mode = .month }
            }
            .padding(2)
            .background(Capsule().fill(VitaColors.glassBg))
            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 0.5))
        }
    }

    private func segButton(_ title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(VitaTypography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(active ? VitaColors.surface : VitaColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? VitaColors.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: Card (nav + faixa/grid + lista)

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            navRow
            if mode == .week { weekStrip } else { monthGrid }
            Rectangle().fill(VitaColors.glassBorder).frame(height: 0.6)
            eventsList
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    private var navRow: some View {
        HStack {
            navButton("chevron.left") { shift(-1) }
            Spacer()
            Text(monthYearLabel(selected))
                .font(VitaTypography.titleSmall)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
            navButton("chevron.right") { shift(1) }
        }
    }

    private func navButton(_ icon: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Image(systemName: icon)
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(VitaColors.glassBg))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shift(_ dir: Int) {
        let unit: Calendar.Component = mode == .week ? .weekOfYear : .month
        if let d = cal.date(byAdding: unit, value: dir, to: selected) {
            withAnimation(.easeInOut(duration: 0.15)) { selected = d }
        }
    }

    // MARK: Faixa da semana

    private var weekDays: [Date] {
        guard let interval = cal.dateInterval(of: .weekOfYear, for: selected) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day, showWeekday: true)
            }
        }
    }

    // MARK: Grid do mes (mesmo estilo)

    private var monthCells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: selected) else { return [] }
        let first = interval.start
        let firstWd = cal.component(.weekday, from: first)
        let leading = (firstWd - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<count { cells.append(cal.date(byAdding: .day, value: d, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var monthGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"], id: \.self) { wd in
                    Text(wd)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            let cells = monthCells
            let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day, showWeekday: false)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                }
            }
        }
    }

    // MARK: Celula de dia (compartilhada por semana e mes)

    private func dayCell(_ day: Date, showWeekday: Bool) -> some View {
        let isSel = cal.isDate(day, inSameDayAs: selected)
        return Button { withAnimation(.easeInOut(duration: 0.15)) { selected = day } } label: {
            VStack(spacing: 4) {
                if showWeekday {
                    Text(weekdayShort(day))
                        .font(VitaTypography.labelSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(showWeekday ? VitaTypography.titleSmall : VitaTypography.labelMedium)
                    .fontWeight(isSel ? .bold : .medium)
                    .foregroundStyle(isSel ? VitaColors.accentHover : VitaColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSel ? VitaColors.accent.opacity(0.14) : Color.clear)
                            .overlay(Circle().stroke(isSel ? VitaColors.accent : Color.clear, lineWidth: 1.5))
                    )
                typeDots(day)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, showWeekday ? 0 : 2)
        }
        .buttonStyle(.plain)
    }

    private func typeDots(_ day: Date) -> some View {
        let colors = typesFor(day)
        return HStack(spacing: 2.5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                Circle().fill(c).frame(width: 4, height: 4)
            }
        }
        .frame(height: 5)
    }

    private func typesFor(_ date: Date) -> [Color] {
        var out: [Color] = []
        if !aulasFor(date).isEmpty { out.append(VitaColors.accent) }
        let evals = evalsFor(date)
        if evals.contains(where: { $0.calendarKind == .exam }) { out.append(VitaColors.dataRed) }
        if evals.contains(where: { $0.calendarKind != .exam }) { out.append(VitaColors.dataBlue) }
        return out
    }

    // MARK: Lista de eventos do dia

    private struct AgendaRow: Identifiable {
        enum Kind { case aula, prova, trabalho }
        let id: String
        let time: String
        let kind: Kind
        let title: String
        let subtitle: String
        let eval: AgendaEvaluation?
    }

    private var rowsForSelected: [AgendaRow] {
        var out: [AgendaRow] = []
        for a in aulasFor(selected) {
            let sub = a.room.map { "Sala \($0)" } ?? (a.professor ?? "")
            out.append(AgendaRow(id: "a-\(a.id)", time: a.startTime, kind: .aula,
                                 title: a.subjectName, subtitle: sub, eval: nil))
        }
        for e in evalsFor(selected) {
            let k: AgendaRow.Kind = e.calendarKind == .exam ? .prova : .trabalho
            out.append(AgendaRow(id: "e-\(e.id)", time: "", kind: k,
                                 title: e.title, subtitle: e.subjectName ?? "", eval: e))
        }
        return out.sorted { ($0.time.isEmpty ? "99:99" : $0.time) < ($1.time.isEmpty ? "99:99" : $1.time) }
    }

    private var eventsList: some View {
        let rows = rowsForSelected
        return VStack(spacing: 8) {
            if rows.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(VitaColors.textTertiary)
                    Text("Nada na agenda de \(weekdayLong(selected))")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                ForEach(rows) { r in
                    Button { if let e = r.eval { onOpenEval?(e) } } label: { rowView(r) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func rowView(_ r: AgendaRow) -> some View {
        let color = colorFor(r.kind)
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)  // ds-allow: quadradinho do icone do evento
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: iconFor(r.kind))
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(color)
            }
            if !r.time.isEmpty {
                Text(r.time)
                    .font(VitaTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 42, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(labelFor(r.kind))
                        .font(VitaTypography.labelSmall)
                        .fontWeight(.semibold)
                        .kerning(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(color)
                }
                Text(r.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                if !r.subtitle.isEmpty {
                    Text(r.subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if r.eval != nil {
                Image(systemName: "chevron.right")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func colorFor(_ k: AgendaRow.Kind) -> Color {
        switch k {
        case .aula: return VitaColors.accent
        case .prova: return VitaColors.dataRed
        case .trabalho: return VitaColors.dataBlue
        }
    }
    private func iconFor(_ k: AgendaRow.Kind) -> String {
        switch k {
        case .aula: return "book.fill"
        case .prova: return "checkmark.seal.fill"
        case .trabalho: return "doc.text.fill"
        }
    }
    private func labelFor(_ k: AgendaRow.Kind) -> String {
        switch k {
        case .aula: return "Aula"
        case .prova: return "Prova"
        case .trabalho: return "Trabalho"
        }
    }

    // MARK: Data (mesma convencao do calendario — 1 cerebro)

    private func aulasFor(_ date: Date) -> [AgendaClassBlock] {
        let weekday = cal.component(.weekday, from: date)
        let apiWeekday = ((weekday + 5) % 7) + 1  // Foundation 1=Sun..7=Sat -> API 1=Mon..7=Sun
        return schedule.filter { $0.dayOfWeek == apiWeekday }.sorted { $0.startTime < $1.startTime }
    }
    private func evalsFor(_ date: Date) -> [AgendaEvaluation] {
        evaluations.filter { e in
            guard let s = e.date, let d = parseDate(s) else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
    }

    private func parseDate(_ s: String) -> Date? {
        if let d = Self.isoFrac.date(from: s) { return d }
        if let d = Self.isoPlain.date(from: s) { return d }
        if let d = Self.ymd.date(from: s) { return d }
        return nil
    }
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private func weekdayShort(_ date: Date) -> String {
        ["—", "DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"][cal.component(.weekday, from: date)]
    }
    private func weekdayLong(_ date: Date) -> String {
        ["—", "domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"][cal.component(.weekday, from: date)]
    }
    private func monthYearLabel(_ date: Date) -> String {
        Self.monthYear.string(from: date).capitalized
    }
    private static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "MMMM yyyy"; return f
    }()
}
