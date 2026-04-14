import SwiftUI

// MARK: - FaculdadeHomeScreen
//
// Dashboard of the Faculdade tab. Structure:
//   1. Subtab pills (Agenda · Matérias · Documentos) at top — navigation shortcut
//   2. Hero card — institution branding (background image or fallback gradient)
//   3. Mini cards — compact previews of each subpage content (today, CR, recent docs)
//
// Every navigable element pushes to its respective full subpage via NavigationStack.

struct FaculdadeHomeScreen: View {
    @Environment(\.appData) private var appData
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Router.self) private var router

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    // Institution info from user profile (via onboarding)
    private var institutionName: String { appData.profile?.university ?? "Minha Faculdade" }
    private var courseName: String { "Medicina" }
    private var currentSemester: Int { appData.profile?.semester ?? 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                subTabRow
                heroCard
                disciplinesSection
                agendaMiniCard
                MateriasAgendaWidget(
                    subjects: appData.gradesResponse?.current ?? [],
                    schedule: appData.classSchedule,
                    evaluations: appData.academicEvaluations,
                    onNavigateToDiscipline: { id, name in
                        router.navigate(to: .faculdadeDisciplinas)
                        router.navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name))
                    }
                )
                trabalhosMiniCard
                documentosMiniCard
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear {
            Task { await appData.silentRefresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appData.silentRefresh() }
            }
        }
    }

    // MARK: - Subtab row (navigation shortcuts)

    private var subTabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                subTabPill(title: "Disciplinas", icon: "graduationcap", route: .faculdadeDisciplinas)
                subTabPill(title: "Agenda", icon: "calendar", route: .faculdadeAgenda)
                subTabPill(title: "Documentos", icon: "doc.text", route: .faculdadeDocumentos)
                subTabPill(title: "Trabalhos", icon: "doc.richtext", route: .trabalhos)
                subTabPill(title: "Professores", icon: "person.2", route: .faculdadeProfessores)
            }
        }
    }

    private func subTabPill(title: String, icon: String, route: Route) -> some View {
        Button {
            router.navigate(to: route)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(goldMuted.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(VitaColors.glassInnerLight.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(goldPrimary.opacity(0.16), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero card (instituição)
    //
    // Card premium sem imagem — gradient vertical sólido + accent dourado na
    // borda + tipografia dominante. Zero variabilidade de fundo, zero ruído
    // atrás do texto, contraste garantido.

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            heroSolidBackground
            heroGoldAccent
            heroBuildingMotif
            heroContent
        }
        .frame(height: 162)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            goldPrimary.opacity(0.40),
                            goldPrimary.opacity(0.10),
                            goldPrimary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    // Motif generalizado: ícone de prédio discreto no canto superior direito,
    // fora da zona de texto, baixa opacidade.
    private var heroBuildingMotif: some View {
        Image(systemName: "building.columns.fill")
            .font(.system(size: 64, weight: .ultraLight))
            .foregroundStyle(goldPrimary.opacity(0.08))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 14)
            .padding(.trailing, 16)
    }

    // Gradient vertical escuro — previsível, uniforme, texto sempre sobre zona escura.
    private var heroSolidBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.07, blue: 0.045),
                Color(red: 0.05, green: 0.035, blue: 0.022)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Accent dourado minúsculo no canto superior direito — só uma luz suave,
    // longe da zona do texto, dá sensação premium sem interferir na leitura.
    private var heroGoldAccent: some View {
        RadialGradient(
            colors: [goldPrimary.opacity(0.22), Color.clear],
            center: UnitPoint(x: 1.0, y: 0.0),
            startRadius: 0,
            endRadius: 140
        )
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zona 1: eyebrow no topo
            if currentSemester > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(goldPrimary)
                        .frame(width: 5, height: 5)
                    Text("\(currentSemester)º SEMESTRE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(goldPrimary)
                }
                .padding(.bottom, 6)
            }

            // Zona 2: título agrupado (institution + curso)
            Text(institutionName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .kerning(-0.4)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(goldMuted.opacity(0.75))
                Text(courseName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.top, 3)

            Spacer(minLength: 0)

            // Zona 3: stats strip embaixo
            heroStatsStrip
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var heroStatsStrip: some View {
        HStack(spacing: 14) {
            heroStat(label: "CR", value: crValue)
            heroStatDivider
            heroStat(label: "Aprov.", value: "\(appData.gradesResponse?.completed.count ?? 0)")
            heroStatDivider
            heroStat(label: "Cursando", value: "\(appData.gradesResponse?.current.count ?? 0)")
            Spacer()
        }
    }

    private var heroStatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private func heroStat(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(goldPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private var crValue: String {
        guard let avg = appData.gradesResponse?.summary.averageGrade else { return "—" }
        return String(format: "%.2f", avg)
    }

    // MARK: - Disciplines section (preview + navigate to full list)

    private var disciplinesSection: some View {
        let subjects = appData.gradesResponse?.current ?? []
        let names = subjects.map(\.subjectName)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Minhas Disciplinas")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer()
                if !names.isEmpty {
                    Button {
                        router.navigate(to: .faculdadeDisciplinas)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            if names.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 16))
                        .foregroundStyle(goldPrimary.opacity(0.35))
                    Text("Conecte seu portal para ver disciplinas")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                }
                .padding(.vertical, 8)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            router.navigate(to: .faculdadeDisciplinas)
                            router.navigate(to: .disciplineDetail(disciplineId: name, disciplineName: name))
                        } label: {
                            glassDisciplineCard(name: name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func glassDisciplineCard(name: String) -> some View {
        let shortName = name
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        HStack(spacing: 10) {
            Circle()
                .fill(goldPrimary.opacity(0.35))
                .frame(width: 8, height: 8)

            Text(shortName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.85))
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textWarm.opacity(0.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.35))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Mini card: Agenda (preview só de hoje)

    private var agendaMiniCard: some View {
        Button {
            router.navigate(to: .faculdadeAgenda)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(icon: "calendar", title: "Hoje", trailing: todayShort)

                let aulas = appData.classSchedule.filter { $0.dayOfWeek == todayWeekdayAPI }
                    .sorted { $0.startTime < $1.startTime }
                let evals = todayEvaluations

                if aulas.isEmpty && evals.isEmpty {
                    Text("Nenhum compromisso hoje")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(evals.prefix(2).enumerated()), id: \.offset) { _, eval in
                            miniEvalLine(eval)
                        }
                        ForEach(Array(aulas.prefix(3).enumerated()), id: \.offset) { _, aula in
                            miniAulaLine(aula)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var todayShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: Date()).capitalized
    }

    private var todayWeekdayAPI: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        // Foundation: 1=Sun ... 7=Sat → API: 1=Mon ... 7=Sun
        return ((wd + 5) % 7) + 1
    }

    private var todayEvaluations: [AgendaEvaluation] {
        let today = Date()
        let cal = Calendar.current
        return appData.academicEvaluations.filter { eval in
            guard let s = eval.date else { return false }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            guard let d = fmt.date(from: s) ?? fmt2.date(from: s) else { return false }
            return cal.isDate(d, inSameDayAs: today)
        }
    }

    private func miniEvalLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = SubjectColors.colorFor(subject: subject)
        let prova = eval.type.uppercased().contains("EXAM") || eval.type.uppercased().contains("PROVA")
        return HStack(spacing: 8) {
            Group {
                if prova {
                    Circle().fill(color).frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.5), radius: 2)
                } else {
                    Circle().stroke(color, lineWidth: 1.3).frame(width: 7, height: 7)
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

    private func miniAulaLine(_ aula: AgendaClassBlock) -> some View {
        let color = SubjectColors.colorFor(subject: aula.subjectName)
        return HStack(spacing: 8) {
            Text(String(aula.startTime.prefix(5)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.55))
                .frame(width: 36, alignment: .leading)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 12)
            Text(aula.subjectName)
                .font(.system(size: 11))
                .foregroundStyle(textWarm.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Mini card: Trabalhos

    private var trabalhosMiniCard: some View {
        let assignments = appData.academicEvaluations.filter {
            $0.type == "assignment" || $0.type == "exam"
        }
        let upcoming = assignments.filter { eval in
            guard let s = eval.date else { return eval.status == "pending" }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            guard let d = fmt.date(from: s) ?? fmt2.date(from: s) else { return false }
            return d > Date().addingTimeInterval(-86400)  // include today
        }.sorted { a, b in
            (a.date ?? "") < (b.date ?? "")
        }

        return Button {
            router.navigate(to: .trabalhos)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(
                    icon: "doc.richtext",
                    title: "Trabalhos",
                    trailing: upcoming.isEmpty ? "" : "\(upcoming.count) pendente\(upcoming.count == 1 ? "" : "s")"
                )

                if upcoming.isEmpty {
                    Text("Nenhum trabalho pendente")
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(upcoming.prefix(3).enumerated()), id: \.offset) { _, eval in
                            miniTrabalhoLine(eval)
                        }
                        if upcoming.count > 3 {
                            Text("+ \(upcoming.count - 3) mais")
                                .font(.system(size: 10))
                                .foregroundStyle(textDim)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniTrabalhoLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = SubjectColors.colorFor(subject: subject)
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(eval.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.80))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let dateStr = eval.date {
                Text(shortDate(dateStr))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textDim)
            }
        }
    }

    private func shortDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        fmt2.formatOptions = [.withInternetDateTime]
        guard let d = fmt.date(from: iso) ?? fmt2.date(from: iso) else { return "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "d MMM"
        return df.string(from: d)
    }

    // MARK: - Mini card: Documentos

    private var documentosMiniCard: some View {
        Button {
            router.navigate(to: .faculdadeDocumentos)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(icon: "doc.text", title: "Documentos", trailing: "")
                Text("Planos de ensino, slides e materiais do portal")
                    .font(.system(size: 11))
                    .foregroundStyle(textWarm.opacity(0.45))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared mini card header

    private func miniCardHeader(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(goldPrimary.opacity(0.80))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(goldPrimary.opacity(0.10))
                )
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 10))
                    .foregroundStyle(textDim)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textDim)
        }
    }

}
