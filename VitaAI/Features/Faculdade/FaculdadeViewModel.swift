import Foundation
import Observation

// MARK: - FaculdadeViewModel
// Source of truth: PAGE_SPEC.md section 2 (Faculdade)
// Data: GET /api/portal/data, /api/grades, /api/study/provas, /api/webaluno/*
// View state structs below -- View NEVER sees raw API models.

@MainActor
@Observable
final class FaculdadeViewModel {
    private let api: VitaAPI

    // MARK: - Screen state

    enum ScreenState {
        case loading
        case loaded
        case empty
        case error(String)
    }

    private(set) var state: ScreenState = .loading

    // MARK: - View state (adapted from API)

    private(set) var summary: AcademicSummaryVM = .empty
    private(set) var agendaItems: [AgendaItemVM] = []
    private(set) var disciplines: [DisciplineCardVM] = []
    private(set) var evaluations: [EvaluationVM] = []
    private(set) var history: [HistorySemesterVM] = []

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Loading

    func load() async {
        state = .loading

        async let portalTask: PortalData200Response? = {
            try? await api.getPortalData()
        }()

        async let gradesTask: [GradeEntry] = {
            (try? await api.getGrades(limit: 100)) ?? []
        }()

        async let examsTask: ExamsResponse? = {
            try? await api.getExams(upcoming: true)
        }()

        async let scheduleTask: WebalunoScheduleResponse? = {
            try? await api.getWebalunoSchedule()
        }()

        async let webalunoGradesTask: WebalunoGradesResponse? = {
            try? await api.getWebalunoGrades()
        }()

        let portal = await portalTask
        let grades = await gradesTask
        let exams = await examsTask
        let schedule = await scheduleTask
        let webalunoGrades = await webalunoGradesTask

        let portalGrades = portal?.grades ?? []
        let portalEvals = portal?.evaluations ?? []
        let portalSchedule = portal?.schedule ?? []
        let portalCalendar = portal?.calendar ?? []

        let hasAnyData = !portalGrades.isEmpty
            || !grades.isEmpty
            || (exams?.exams.isEmpty == false)
            || !portalSchedule.isEmpty
            || (webalunoGrades?.grades.isEmpty == false)

        guard hasAnyData else {
            state = .empty
            return
        }

        buildSummary(portalGrades: portalGrades, webalunoGrades: webalunoGrades)
        buildAgenda(portalSchedule: portalSchedule, portalCalendar: portalCalendar, exams: exams?.exams ?? [], schedule: schedule)
        buildDisciplines(portalGrades: portalGrades, webalunoGrades: webalunoGrades)
        buildEvaluations(portalEvals: portalEvals, exams: exams?.exams ?? [], grades: grades)
        buildHistory(portalGrades: portalGrades, webalunoGrades: webalunoGrades)

        state = .loaded
    }

    // MARK: - Build Summary (Block 2.1)

    private func buildSummary(portalGrades: [PortalGrade], webalunoGrades: WebalunoGradesResponse?) {
        let currentSemesterGrades = portalGrades.filter { g in
            let s = g.status?.lowercased() ?? ""
            return s.isEmpty || s == "cursando" || s == "em andamento" || s == "matriculado"
        }
        let gradesForAvg = currentSemesterGrades.isEmpty ? portalGrades : currentSemesterGrades
        let currentSemester = currentSemesterGrades.first?.semester ?? webalunoGrades?.grades.first?.semester ?? ""
        let disciplineCount = gradesForAvg.count

        var gradeSum = 0.0; var gradeCount = 0
        for g in gradesForAvg {
            if let v = parseGrade(g.grade1) { gradeSum += v; gradeCount += 1 }
            if let v = parseGrade(g.grade2) { gradeSum += v; gradeCount += 1 }
            if let v = parseGrade(g.grade3) { gradeSum += v; gradeCount += 1 }
            if let v = parseGrade(g.finalGrade) { gradeSum += v; gradeCount += 1 }
        }
        let avgGrade = gradeCount > 0 ? gradeSum / Double(gradeCount) : nil

        var attSum = 0.0; var attCount = 0
        for g in gradesForAvg {
            if let a = parseGrade(g.attendance) { attSum += a; attCount += 1 }
        }
        let avgAtt = attCount > 0 ? attSum / Double(attCount) : nil

        let atRisk = gradesForAvg.filter { g in
            guard let a = parseGrade(g.attendance) else { return false }
            return a < 75.0
        }.count

        summary = AcademicSummaryVM(
            currentSemester: currentSemester,
            disciplineCount: disciplineCount,
            averageGrade: avgGrade,
            averageAttendance: avgAtt,
            absencesAtRisk: atRisk
        )
    }

    // MARK: - Build Agenda (Block 2.2)

    private func buildAgenda(
        portalSchedule: [PortalScheduleItem],
        portalCalendar: [PortalCalendarItem],
        exams: [ExamEntry],
        schedule: WebalunoScheduleResponse?
    ) {
        var items: [AgendaItemVM] = []
        let today = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: today) - 1

        for exam in exams where exam.daysUntil >= 0 && exam.daysUntil <= 30 {
            let d = parseExamDate(exam.date)
            let examTitle = [exam.subjectName, exam.examType].filter { !$0.isEmpty }.joined(separator: " - ")
            items.append(AgendaItemVM(
                id: "exam-\(exam.id)", title: examTitle,
                subtitle: exam.subjectName, date: d, time: d.map { formatTime($0) },
                type: .exam, daysUntil: exam.daysUntil > 0 ? exam.daysUntil : nil,
                iconName: "doc.text.fill"
            ))
        }

        for cls in portalSchedule {
            guard let dow = cls.dayOfWeek, dow == todayWeekday else { continue }
            items.append(AgendaItemVM(
                id: "class-\(cls.id ?? UUID().uuidString)",
                title: cls.subjectName ?? "",
                subtitle: [cls.professor, cls.room].compactMap { $0 }.joined(separator: " - "),
                date: today, time: cls.startTime, type: .classBlock,
                daysUntil: nil, iconName: "graduationcap.fill"
            ))
        }

        for block in schedule?.schedule ?? [] {
            guard block.dayOfWeek == todayWeekday else { continue }
            let dup = items.contains { $0.title == block.subjectName && $0.type == .classBlock }
            guard !dup else { continue }
            items.append(AgendaItemVM(
                id: "wclass-\(block.subjectName)-\(block.startTime)",
                title: block.subjectName,
                subtitle: [block.professor, block.room].compactMap { $0 }.joined(separator: " - "),
                date: today, time: block.startTime, type: .classBlock,
                daysUntil: nil, iconName: "graduationcap.fill"
            ))
        }

        for c in portalCalendar {
            guard let startAtStr = c.startAt, let startAt = parseExamDate(startAtStr) else { continue }
            let du = cal.dateComponents([.day], from: cal.startOfDay(for: today), to: cal.startOfDay(for: startAt)).day ?? 0
            guard du >= 0 && du <= 14 else { continue }
            items.append(AgendaItemVM(
                id: "cal-\(c.id ?? UUID().uuidString)",
                title: c.title ?? "",
                subtitle: c.subjectName, date: startAt, time: formatTime(startAt),
                type: c.type?.lowercased() == "exam" ? .exam : .event,
                daysUntil: du > 0 ? du : nil,
                iconName: c.type?.lowercased() == "exam" ? "doc.text.fill" : "calendar"
            ))
        }

        agendaItems = items.sorted { a, b in
            if let da = a.date, let db = b.date { return da < db }
            return (a.time ?? "") < (b.time ?? "")
        }
    }

    // MARK: - Build Disciplines (Block 2.3)

    private func buildDisciplines(portalGrades: [PortalGrade], webalunoGrades: WebalunoGradesResponse?) {
        var cards: [DisciplineCardVM] = []

        if !portalGrades.isEmpty {
            let current = portalGrades.filter { g in
                let s = g.status?.lowercased() ?? ""
                return s.isEmpty || s == "cursando" || s == "em andamento" || s == "matriculado"
            }
            let src = current.isEmpty ? portalGrades : current
            for g in src {
                let name = g.subjectName ?? ""
                let slug = slugify(name)
                let att = parseGrade(g.attendance)
                let abs = Int(g.absences ?? "") ?? 0
                let risk = computeRisk(attendance: att)
                cards.append(DisciplineCardVM(
                    id: g.id ?? slug, name: name, professor: g.professor,
                    g1: parseGrade(g.grade1), g2: parseGrade(g.grade2), g3: parseGrade(g.grade3),
                    finalGrade: parseGrade(g.finalGrade), attendance: att, absences: abs,
                    status: g.status, riskLevel: risk, nextEvaluation: nil, iconSlug: slug
                ))
            }
        } else if let wg = webalunoGrades?.grades {
            for g in wg {
                let slug = slugify(g.subjectName)
                let risk = computeRisk(attendance: g.attendance)
                cards.append(DisciplineCardVM(
                    id: g.id, name: g.subjectName, professor: nil,
                    g1: g.grade1, g2: g.grade2, g3: g.grade3,
                    finalGrade: g.finalGrade, attendance: g.attendance, absences: 0,
                    status: g.status, riskLevel: risk, nextEvaluation: nil, iconSlug: slug
                ))
            }
        }

        disciplines = cards.sorted { a, b in
            if a.riskLevel.sortOrder != b.riskLevel.sortOrder { return a.riskLevel.sortOrder > b.riskLevel.sortOrder }
            return a.name < b.name
        }
    }

    // MARK: - Build Evaluations (Block 2.4)

    private func buildEvaluations(portalEvals: [PortalEvaluation], exams: [ExamEntry], grades: [GradeEntry]) {
        var evals: [EvaluationVM] = []

        for e in portalEvals {
            evals.append(EvaluationVM(
                id: e.id ?? UUID().uuidString, title: e.title ?? "", type: e.type ?? "",
                date: parseExamDate(e.date ?? ""), discipline: e.subjectName, score: e.score,
                maxScore: e.pointsPossible, grade: e.grade, status: e.status ?? ""
            ))
        }

        for exam in exams {
            let examTitle = [exam.subjectName, exam.examType].filter { !$0.isEmpty }.joined(separator: " - ")
            guard !evals.contains(where: { $0.title == examTitle }) else { continue }
            evals.append(EvaluationVM(
                id: "exam-\(exam.id)", title: examTitle, type: exam.examType.isEmpty ? "prova" : exam.examType,
                date: parseExamDate(exam.date), discipline: exam.subjectName,
                score: nil, maxScore: nil, grade: nil,
                status: exam.daysUntil <= 0 ? "past" : "upcoming"
            ))
        }

        for g in grades {
            guard !evals.contains(where: { $0.id == g.id }) else { continue }
            evals.append(EvaluationVM(
                id: g.id, title: g.label, type: "avaliacao",
                date: parseExamDate(g.date ?? ""), discipline: nil,
                score: g.value, maxScore: g.maxValue, grade: nil, status: "graded"
            ))
        }

        evaluations = evals.sorted { a, b in
            if let da = a.date, let db = b.date { return da > db }
            return a.title < b.title
        }
    }

    // MARK: - Build History (Block 2.5)

    private func buildHistory(portalGrades: [PortalGrade], webalunoGrades: WebalunoGradesResponse?) {
        var semMap: [String: [HistoryDisciplineVM]] = [:]

        let pastStatuses = ["aprovado", "aprovada", "reprovado", "reprovada", "dispensado", "dispensada", "trancado", "trancada"]
        let past = portalGrades.filter { g in
            let s = g.status?.lowercased() ?? ""
            return pastStatuses.contains(where: { s.contains($0) })
        }

        for g in past {
            let sem = g.semester ?? "Sem semestre"
            let name = g.subjectName ?? ""
            let fg = parseGrade(g.finalGrade)
            let s = g.status?.lowercased() ?? ""
            let ok = s.contains("aprovad") || s.contains("dispensad")
            semMap[sem, default: []].append(HistoryDisciplineVM(
                id: g.id ?? "\(sem)-\(name)", name: name, finalGrade: fg, approved: ok, status: g.status ?? ""
            ))
        }

        if let wg = webalunoGrades?.grades {
            for g in wg {
                let s = g.status?.lowercased() ?? ""
                let isPast = pastStatuses.contains(where: { s.contains($0) })
                guard isPast else { continue }
                let sem = g.semester ?? "Sem semestre"
                if semMap[sem]?.contains(where: { $0.name == g.subjectName }) == true { continue }
                let ok = s.contains("aprovad") || s.contains("dispensad")
                semMap[sem, default: []].append(HistoryDisciplineVM(
                    id: g.id, name: g.subjectName, finalGrade: g.finalGrade, approved: ok, status: g.status ?? ""
                ))
            }
        }

        history = semMap.map { (sem, discs) in
            HistorySemesterVM(
                id: sem, semester: sem,
                disciplines: discs.sorted { $0.name < $1.name },
                approvedCount: discs.filter(\.approved).count,
                failedCount: discs.filter { !$0.approved }.count
            )
        }.sorted { $0.semester > $1.semester }
    }

    // MARK: - Helpers

    private func parseGrade(_ value: String?) -> Double? {
        guard let v = value, !v.isEmpty else { return nil }
        return Double(v.replacingOccurrences(of: ",", with: "."))
    }

    private func parseExamDate(_ dateString: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: dateString) { return d }
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone.current
        for f in ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "dd/MM/yyyy"] {
            fmt.dateFormat = f
            if let d = fmt.date(from: dateString) { return d }
        }
        return nil
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone.current
        return fmt.string(from: date)
    }

    private func slugify(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
    }

    private func computeRisk(attendance: Double?) -> RiskLevel {
        guard let a = attendance else { return .none }
        if a < 70 { return .critical }
        if a < 75 { return .high }
        if a < 80 { return .medium }
        return .none
    }
}

// MARK: - View State Structs

struct AcademicSummaryVM: Equatable {
    let currentSemester: String
    let disciplineCount: Int
    let averageGrade: Double?
    let averageAttendance: Double?
    let absencesAtRisk: Int
    static let empty = AcademicSummaryVM(currentSemester: "", disciplineCount: 0, averageGrade: nil, averageAttendance: nil, absencesAtRisk: 0)
}

struct AgendaItemVM: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let date: Date?
    let time: String?
    let type: AgendaItemType
    let daysUntil: Int?
    let iconName: String
    enum AgendaItemType: Equatable { case exam, classBlock, event }
}

struct DisciplineCardVM: Identifiable, Equatable {
    let id: String
    let name: String
    let professor: String?
    let g1: Double?
    let g2: Double?
    let g3: Double?
    let finalGrade: Double?
    let attendance: Double?
    let absences: Int
    let status: String?
    let riskLevel: RiskLevel
    let nextEvaluation: String?
    let iconSlug: String
}

enum RiskLevel: Equatable {
    case critical, high, medium, none
    var sortOrder: Int {
        switch self { case .critical: 3; case .high: 2; case .medium: 1; case .none: 0 }
    }
}

struct EvaluationVM: Identifiable, Equatable {
    let id: String
    let title: String
    let type: String
    let date: Date?
    let discipline: String?
    let score: Double?
    let maxScore: Double?
    let grade: String?
    let status: String
}

struct HistorySemesterVM: Identifiable, Equatable {
    let id: String
    let semester: String
    let disciplines: [HistoryDisciplineVM]
    let approvedCount: Int
    let failedCount: Int
}

struct HistoryDisciplineVM: Identifiable, Equatable {
    let id: String
    let name: String
    let finalGrade: Double?
    let approved: Bool
    let status: String
}
