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

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData

    private enum Mode { case week, month }
    @State private var mode: Mode = .week
    /// Editor manual aberto (nil = fechado). Rafael 2026-07-23.
    @State private var editor: EditorAlvo?
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
        .sheet(item: $editor) { alvo in
            EventoAgendaSheet(
                alvo: alvo,
                disciplinas: appData.canonicalDisciplines,
                api: container.api,
                aoTerminar: { Task { await appData.forceRefresh() } }
            )
        }
    }

    // MARK: Editor manual (adicionar / editar / remover)

    struct EditorAlvo: Identifiable {
        let id = UUID()
        let dia: Date
        let prova: AgendaEvaluation?
        let aula: AgendaClassBlock?
    }

    @ViewBuilder
    private func menuDoEvento(_ r: AgendaRow) -> some View {
        if let e = r.eval {
            Button {
                editor = EditorAlvo(dia: selected, prova: e, aula: nil)
            } label: { Label("Editar", systemImage: "pencil") }
            Button(role: .destructive) {
                Task {
                    try? await container.api.deleteProva(id: e.id)
                    await appData.forceRefresh()
                }
            } label: { Label("Remover", systemImage: "trash") }
        } else if let a = aulaDaLinha(r) {
            Button {
                editor = EditorAlvo(dia: selected, prova: nil, aula: a)
            } label: { Label("Editar aula", systemImage: "pencil") }
            Button(role: .destructive) {
                Task {
                    try? await container.api.deleteAula(id: a.id)
                    await appData.forceRefresh()
                }
            } label: { Label("Remover aula", systemImage: "trash") }
        }
    }

    /// A linha da lista guarda so o id prefixado ("a-<id>"); volta pro bloco real.
    private func aulaDaLinha(_ r: AgendaRow) -> AgendaClassBlock? {
        guard r.id.hasPrefix("a-") else { return nil }
        let id = String(r.id.dropFirst(2))
        return schedule.first { $0.id == id }
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

            Button {
                editor = EditorAlvo(dia: selected, prova: nil, aula: nil)
            } label: {
                Image(systemName: "plus")
                    .font(VitaTypography.labelMedium)
                    .fontWeight(.bold)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(VitaColors.accent.opacity(0.12)))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adicionar na agenda")
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
                        .contextMenu { menuDoEvento(r) }
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


// MARK: - EventoAgendaSheet — adicionar/editar evento manual da agenda
//
// Canon: VitaSheet + VitaInput + VitaButton + .glassCard(), tokens em tudo.
// Prova/Trabalho vao pra academic_evaluations (/api/study/provas); Aula vai pra
// grade semanal (/api/study/aulas). Disciplina obrigatoria nos tres — sem ela o
// backend de provas cria uma disciplina fantasma com o nome do evento.

struct EventoAgendaSheet: View {
    let alvo: JornadaWeekAgenda.EditorAlvo
    let disciplinas: [AcademicSubject]
    let api: VitaAPI
    let aoTerminar: () -> Void

    @Environment(\.dismiss) private var dismiss

    enum TipoEvento: String, CaseIterable, Identifiable {
        case prova, trabalho, aula
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .prova: return "Prova"
            case .trabalho: return "Trabalho"
            case .aula: return "Aula"
            }
        }
        var icone: String {
            switch self {
            case .prova: return "checklist"
            case .trabalho: return "doc.richtext"
            case .aula: return "book"
            }
        }
        // Ouro monocromatico: DESIGN.md proibe cor de accent por decoracao —
        // data* e so pra semantica de dado (acerto/erro/alerta).
        var cor: Color { VitaColors.accent }
    }

    @State private var tipo: TipoEvento = .prova
    @State private var titulo = ""
    @State private var subjectId = ""
    @State private var quando = Date()
    @State private var diaSemana = 1
    @State private var horaInicio = Date()
    @State private var horaFim = Date().addingTimeInterval(3600)
    @State private var sala = ""
    @State private var professor = ""
    @State private var salvando = false
    @State private var erro: String?

    private var editando: Bool { alvo.prova != nil || alvo.aula != nil }

    private var podeSalvar: Bool {
        if subjectId.isEmpty || salvando { return false }
        if tipo == .aula { return true }
        return !titulo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VitaSheet(title: editando ? "Editar evento" : "Novo evento", detents: [.large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                    if !editando { seletorTipo }
                    blocoDisciplina
                    if tipo == .aula { blocoAula } else { blocoProvaTrabalho }
                    if let erro { avisoErro(erro) }
                    acoes
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
        }
        .onAppear(perform: preencher)
    }

    // MARK: tipo

    private var seletorTipo: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            ForEach(TipoEvento.allCases) { t in
                Button { tipo = t } label: {
                    VStack(spacing: VitaTokens.Spacing.xs) {
                        Image(systemName: t.icone)
                            .font(VitaTypography.titleMedium)
                        Text(t.titulo)
                            .font(VitaTypography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(tipo == t ? t.cor : VitaColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VitaTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .fill(tipo == t ? t.cor.opacity(0.12) : VitaColors.glassBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                            .stroke(tipo == t ? t.cor.opacity(0.45) : VitaColors.glassBorder,
                                    lineWidth: tipo == t ? 1 : 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: disciplina

    private var blocoDisciplina: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            rotulo("Disciplina")
            Menu {
                ForEach(disciplinas, id: \.id) { d in
                    Button(d.preferredName) { subjectId = d.id }
                }
            } label: {
                HStack {
                    Text(nomeDisciplina ?? "Escolha uma disciplina")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(subjectId.isEmpty ? VitaColors.textTertiary : VitaColors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: VitaTokens.Spacing.sm)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.vertical, VitaTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: VitaTokens.Radius.md)
            }
            if subjectId.isEmpty {
                Text("Obrigatória — é ela que liga o evento à matéria.")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
    }

    private var nomeDisciplina: String? {
        disciplinas.first { $0.id == subjectId }?.preferredName
    }

    // MARK: prova / trabalho

    private var blocoProvaTrabalho: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                rotulo(tipo == .prova ? "Nome da prova" : "Nome do trabalho")
                VitaInput(value: $titulo,
                          placeholder: tipo == .prova ? "Ex: P1 de Anatomia" : "Ex: Relatório de caso")
            }
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                rotulo("Quando")
                caixaDeVidro {
                    DatePicker("", selection: $quando, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(VitaColors.accent)
                }
            }
        }
    }

    // MARK: aula

    private var blocoAula: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                rotulo("Dia da semana")
                HStack(spacing: VitaTokens.Spacing.xs) {
                    ForEach(Array(["SEG","TER","QUA","QUI","SEX","SÁB","DOM"].enumerated()), id: \.offset) { i, nome in
                        let dia = i + 1
                        Button { diaSemana = dia } label: {
                            Text(nome)
                                .font(VitaTypography.labelSmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(diaSemana == dia ? VitaColors.surface : VitaColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, VitaTokens.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                                        .fill(diaSemana == dia ? VitaColors.accent : VitaColors.glassBg)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: VitaTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                    rotulo("Começa")
                    caixaDeVidro {
                        DatePicker("", selection: $horaInicio, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.compact).tint(VitaColors.accent)
                    }
                }
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                    rotulo("Termina")
                    caixaDeVidro {
                        DatePicker("", selection: $horaFim, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.compact).tint(VitaColors.accent)
                    }
                }
            }
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                rotulo("Sala e professor (opcional)")
                VitaInput(value: $sala, placeholder: "Sala")
                VitaInput(value: $professor, placeholder: "Professor")
            }
        }
    }

    // MARK: acoes

    private var acoes: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            VitaButton(text: "Salvar",
                       action: { Task { await salvar() } },
                       isEnabled: podeSalvar,
                       isLoading: salvando,
                       fillsWidth: true)

            if editando {
                VitaButton(text: "Remover da agenda",
                           action: { Task { await remover() } },
                           variant: .danger,
                           isEnabled: !salvando,
                           fillsWidth: true)
            }
        }
        .padding(.top, VitaTokens.Spacing.sm)
    }

    // MARK: pecinhas

    private func rotulo(_ t: String) -> some View {
        Text(t)
            .font(VitaTypography.labelSmall)
            .fontWeight(.semibold)
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(VitaColors.sectionLabel)
    }

    private func caixaDeVidro<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c()
            .padding(.horizontal, VitaTokens.Spacing.md)
            .padding(.vertical, VitaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: VitaTokens.Radius.md)
    }

    private func avisoErro(_ t: String) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.dataRed)
            Text(t)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .padding(VitaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.dataRed.opacity(0.10))
        )
    }

    // MARK: preencher / salvar / remover

    private func preencher() {
        quando = alvo.dia
        if let p = alvo.prova {
            tipo = p.calendarKind == .exam ? .prova : .trabalho
            titulo = p.title
            if let iso = p.date, let d = Self.isoParaData(iso) { quando = d }
            subjectId = disciplinas.first { $0.preferredName == (p.subjectName ?? "") }?.id ?? ""
        } else if let a = alvo.aula {
            tipo = .aula
            subjectId = disciplinas.first { $0.preferredName == a.subjectName }?.id ?? ""
            diaSemana = a.dayOfWeek
            horaInicio = Self.horaParaData(a.startTime) ?? horaInicio
            horaFim = Self.horaParaData(a.endTime) ?? horaFim
            sala = a.room ?? ""
            professor = a.professor ?? ""
        }
    }

    private func salvar() async {
        salvando = true; erro = nil
        do {
            if tipo == .aula {
                let ini = Self.hhmm(horaInicio), fim = Self.hhmm(horaFim)
                if let a = alvo.aula {
                    try await api.updateAula(id: a.id, subjectId: subjectId, dayOfWeek: diaSemana,
                                             startTime: ini, endTime: fim,
                                             room: sala.isEmpty ? nil : sala,
                                             professor: professor.isEmpty ? nil : professor)
                } else {
                    try await api.createAula(subjectId: subjectId, dayOfWeek: diaSemana,
                                             startTime: ini, endTime: fim,
                                             room: sala.isEmpty ? nil : sala,
                                             professor: professor.isEmpty ? nil : professor)
                }
            } else {
                let iso = ISO8601DateFormatter().string(from: quando)
                let tipoTexto = tipo == .prova ? "prova" : "trabalho"
                if let p = alvo.prova {
                    try await api.updateProva(id: p.id, title: titulo, date: iso, type: tipoTexto)
                } else {
                    // O POST ignora `type`: cria e ja marca o tipo no PATCH.
                    let nova = try await api.createProva(title: titulo, subjectId: subjectId,
                                                         date: iso, notes: nil)
                    try? await api.updateProva(id: nova.id, title: nil, date: nil, type: tipoTexto)
                }
            }
            aoTerminar()
            dismiss()
        } catch {
            erro = "Não consegui salvar. Confira a conexão e tente de novo."
            salvando = false
        }
    }

    private func remover() async {
        salvando = true; erro = nil
        do {
            if let a = alvo.aula { try await api.deleteAula(id: a.id) }
            else if let p = alvo.prova { try await api.deleteProva(id: p.id) }
            aoTerminar()
            dismiss()
        } catch {
            erro = "Não consegui remover."
            salvando = false
        }
    }

    private static func hhmm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private static func horaParaData(_ hhmm: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.date(from: hhmm)
    }
    private static func isoParaData(_ iso: String) -> Date? {
        let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
        return a.date(from: iso) ?? b.date(from: iso)
    }
}
