import SwiftUI

// MARK: - FaculdadeHomeScreen
//
// Dashboard of the Jornada/Faculdade tab. Structure:
//   1. Hero card — institution branding
//   2. Mini cards — compact previews of agenda, disciplines and documents
//
// Every navigable element pushes to its respective full subpage via NavigationStack.
//
// Variant `.internato` (Rafael 2026-04-28): mesma tela, com 3 cortes:
//   - Hero eyebrow vira "INTERNATO" em vez de "Xº SEMESTRE"
//   - Stats strip (CR/Aprov/Cursando) some — internato não tem notas tradicionais
//   - Seção "Minhas Disciplinas" some — agenda + trabalhos + documentos é o que importa

struct FaculdadeHomeScreen: View {
    var variant: JourneyType = .faculdade

    @Environment(\.appData) private var appData
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Router.self) private var router

    // Long-press na pasta: renomear/trocar cor/excluir — REUSA os componentes
    // que ja existem (RenameSubjectSheet, SubjectColorPicker, deleteSubject).
    @State private var renameTarget: SubjectActionTarget?
    @State private var colorTarget: SubjectActionTarget?
    @State private var deleteTarget: SubjectActionTarget?
    @State private var colorRefreshTrigger = UUID()

    private struct SubjectActionTarget: Identifiable {
        let id: String
        let name: String
    }

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    // Institution info from user profile (via onboarding)
    private var institutionName: String { appData.profile?.university ?? "" }
    private var hasFaculdade: Bool { !(appData.profile?.university ?? "").isEmpty }
    @State private var showFaculdadePicker = false
    private var courseName: String { variant == .internato ? "Medicina · Internato" : "Medicina" }
    private var currentSemester: Int { appData.profile?.semester ?? 0 }

    private var isInternato: Bool { variant == .internato }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Ordem (Rafael 2026-07-21): agenda em cima, depois disciplinas,
                // depois trabalhos. Sem hero — abre direto no que importa.
                JornadaWeekAgenda(
                    schedule: appData.classSchedule,
                    evaluations: appData.academicEvaluations
                )
                if !isInternato && !showConnectPortalCTA {
                    disciplinesSection
                        .id(colorRefreshTrigger)
                }
                if showConnectPortalCTA {
                    connectPortalCard
                }
                faculdadeShortcutsCard
                // Clearance pra ultima linha nao ficar atras da TabBar Liquid Glass.
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear {
            Task {
                await appData.silentRefresh()
                ScreenLoadContext.finish(for: "Faculdade")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appData.silentRefresh() }
            }
        }
        .trackScreen("Faculdade")
        .sheet(item: $renameTarget) { t in
            VitaSheet(detents: [.height(260)]) {
                RenameSubjectSheet(
                    subjectId: t.id,
                    currentName: t.name,
                    initialDisplayName: appData.enrolledDisciplines.first(where: { $0.id == t.id })?.displayName
                )
            }
        }
        .sheet(item: $colorTarget) { t in
            VitaSheet(detents: [.height(380)]) {
                SubjectColorPicker(subjectName: t.name) { _ in
                    colorRefreshTrigger = UUID()
                }
                .padding(20)
            }
        }
        .confirmationDialog(
            "Excluir disciplina?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible,
            presenting: deleteTarget
        ) { t in
            Button("Excluir", role: .destructive) {
                let id = t.id
                Task { try? await appData.removeDiscipline(id: id) }
                deleteTarget = nil
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: { t in
            Text("Isso remove \(t.name) e o que esta ligado a ela.")
        }
    }

    // MARK: - In-page actions

    private var journeyActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acesso rápido")
                .font(PixioTypo.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)

            quickActionsRow
        }
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isInternato {
                    quickActionChip(title: "Disciplinas", icon: "graduationcap", route: .faculdadeDisciplinas)
                }
                quickActionChip(title: "Documentos", icon: "doc.text", route: .faculdadeDocumentos)
                quickActionChip(title: "Trabalhos", icon: "doc.richtext", route: .trabalhos)
                quickActionChip(title: "Professores", icon: "person.2", route: .faculdadeProfessores)
            }
            .padding(.vertical, 1)
        }
    }

    private func quickActionChip(title: String, icon: String, route: Route) -> some View {
        Button {
            PixioHaptics.tap()
            router.navigate(to: route)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(PixioTypo.micro)
                Text(title)
                    .font(PixioTypo.caption)
            }
            .foregroundStyle(VitaColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(VitaColors.surfaceElevated.opacity(0.58))
            )
            .overlay(
                Capsule().stroke(VitaColors.surfaceBorder.opacity(0.62), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conectar portal (CTA)
    //
    // Sem disciplinas => portal ainda nao trouxe nada. Em vez de texto morto,
    // um cartao de acao que abre o MESMO fluxo do onboarding (.connections:
    // Canvas/Moodle + tutorial + colar a chave). Conectou => o cartao some e
    // as disciplinas ocupam o lugar.
    // Conectar portal so aparece quando ainda nao ha disciplinas. Quem ja tem
    // materias ve as disciplinas (fim do flag de teste TEMP-CTA-TEST).
    private var showConnectPortalCTA: Bool { appData.canonicalDisciplines.isEmpty }

    private var connectPortalCard: some View {
        Button {
            PixioHaptics.tap()
            router.navigate(to: .connections)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(PixioTypo.sans(size: 18, weight: .semibold))
                    .foregroundStyle(goldPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)  // ds-allow: raio 10 ja e o padrao visual desta tela; sem token exato
                            .fill(goldPrimary.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "faculdade_connect_portal_title"))
                        .font(PixioTypo.sans(size: 14, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Text(String(localized: "onboarding_connect_portal_subtitle"))
                        .font(PixioTypo.sans(size: 11))
                        .foregroundStyle(textWarm.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(PixioTypo.sans(size: 12, weight: .semibold))
                    .foregroundStyle(goldPrimary.opacity(0.70))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
            .overlay(
                RoundedRectangle(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
                    .stroke(goldPrimary.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("faculdadeConnectPortalCTA")
    }

    // MARK: - Hero card (instituição)
    //
    // Card premium sem imagem — gradient vertical sólido + accent dourado na
    // borda + tipografia dominante. Zero variabilidade de fundo, zero ruído
    // atrás do texto, contraste garantido.

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            heroBackground
            heroContent
        }
        .frame(height: 162)
        .glassCard(cornerRadius: 18)  // ds-allow: raio 18 ja e o padrao visual desta tela; sem token exato
        .sheet(isPresented: $showFaculdadePicker) {
            VitaSheet(detents: [.large]) {
                FaculdadePickerSheet()
            }
        }
    }

    // Motif generalizado: ícone de prédio discreto no canto superior direito.
    private var heroBackground: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [goldPrimary.opacity(0.16), Color.clear],
                center: .topTrailing, startRadius: 6, endRadius: 200
            )
            Image(systemName: "building.columns.fill")
                .font(PixioTypo.sans(size: 74, weight: .thin))  // ds-allow: motivo do hero
                .foregroundStyle(
                    LinearGradient(colors: [goldMuted.opacity(0.5), goldPrimary.opacity(0.14)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: goldPrimary.opacity(0.3), radius: 12)
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zona 1: eyebrow no topo
            // Internato (Rafael 2026-04-28): substitui "Xº SEMESTRE" por "INTERNATO"
            // independente do número exato — o aluno está em rotação clínica.
            if isInternato {
                HStack(spacing: 6) {
                    Circle()
                        .fill(goldPrimary)
                        .frame(width: 5, height: 5)
                    Text("INTERNATO")
                        .font(PixioTypo.sans(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(goldPrimary)
                }
                .padding(.bottom, 6)
            } else if currentSemester > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(goldPrimary)
                        .frame(width: 5, height: 5)
                    Text("\(currentSemester)º SEMESTRE")
                        .font(PixioTypo.sans(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(goldPrimary)
                }
                .padding(.bottom, 6)
            }

            // Zona 2: título agrupado (institution CLICAVEL + curso)
            Button { showFaculdadePicker = true } label: {
                Text(hasFaculdade ? institutionName : "Selecionar faculdade")
                    .font(PixioTypo.sans(size: 22, weight: .bold))  // ds-allow: titulo do hero
                    .foregroundStyle(hasFaculdade ? Color.white : goldMuted)
                    .kerning(-0.4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(PixioTypo.sans(size: 10, weight: .semibold))
                    .foregroundStyle(goldMuted.opacity(0.75))
                Text(courseName)
                    .font(PixioTypo.sans(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .padding(.top, 3)

            Spacer(minLength: 0)

            // Zona 3: stats strip embaixo (CR/Aprov/Cursando).
            // Internato não tem notas tradicionais — esconde a strip toda.
            if !isInternato {
                heroStatsStrip
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var heroStatsStrip: some View {
        HStack(spacing: 14) {
            heroStat(label: "CR", value: crValue)
            heroStatDivider
            heroStat(label: "Aprov.", value: "\(appData.completedDisciplines.count)")
            heroStatDivider
            heroStat(label: "Cursando", value: "\(appData.enrolledDisciplines.count)")
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
                .font(PixioTypo.sans(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(goldPrimary)
            Text(label)
                .font(PixioTypo.sans(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private var crValue: String {
        guard let avg = appData.gradesResponse?.summary.averageGrade else { return "—" }
        return String(format: "%.2f", avg)
    }

    // MARK: - Disciplines section (folder grid)

    private var disciplinesSection: some View {
        // Fonte única: matérias em curso (/api/subjects), não derivadas das notas.
        let subjects = appData.canonicalDisciplines

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Minhas Disciplinas")
                    .font(PixioTypo.sans(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer()
                if !subjects.isEmpty {
                    Button {
                        router.navigate(to: .faculdadeDisciplinas)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                                .font(PixioTypo.sans(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(PixioTypo.sans(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            if subjects.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap")
                        .font(PixioTypo.sans(size: 16))
                        .foregroundStyle(goldPrimary.opacity(0.35))
                    Text("Conecte seu portal para ver disciplinas")
                        .font(PixioTypo.sans(size: 12))
                        .foregroundStyle(textDim)
                }
                .padding(.vertical, 8)
            } else {
                // No maximo 2 linhas (6 disciplinas) na home; o resto abre em Ver todas.
                let sorted = Array(sortedByFavorite(subjects).prefix(6))
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sorted) { subject in
                        Button {
                            router.navigate(to: .faculdadeDisciplinas)
                            router.navigate(to: .disciplineDetail(disciplineId: subject.id, disciplineName: subject.preferredName))
                        } label: {
                            DisciplineFolderCard(
                                subjectName: subject.preferredName,
                                itemCount: appData.materialsTotal(forSubjectId: subject.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
                            } label: { Label("Renomear", systemImage: "pencil") }
                            Button {
                                colorTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
                            } label: { Label("Trocar cor", systemImage: "paintpalette") }
                            Button(role: .destructive) {
                                deleteTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
                            } label: { Label("Excluir", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sortedByFavorite(_ subjects: [AcademicSubject]) -> [AcademicSubject] {
        let favs = DisciplineFolderCard.favorites()
        return subjects.sorted { a, b in
            let aFav = favs.contains(a.preferredName)
            let bFav = favs.contains(b.preferredName)
            if aFav != bFav { return aFav }
            return a.preferredName < b.preferredName
        }
    }

    // MARK: - Mini card: Trabalhos

    // Card unico da Faculdade: Provas, Trabalhos e Documentos em linhas
    // tappaveis com contador. Substitui os dois mini-cards soltos — card
    // separado por item era peso visual e empurrava o Documentos pra tras da
    // TabBar (Rafael 2026-07-21).
    private var faculdadeShortcutsCard: some View {
        let exams = appData.academicEvaluations.filter { $0.calendarKind == .exam }
        let provasPend = exams.filter { ev in
            let st = ev.status.lowercased()
            return st != "completed" && st != "graded"
        }.count
        let trabalhosPend = appData.academicEvaluations
            .filter { $0.calendarKind == .assignment || $0.calendarKind == .other }
            .filter { ev in
                let st = ev.status.lowercased()
                return st != "completed" && st != "graded" && st != "submitted"
            }.count

        return VStack(spacing: 0) {
            shortcutRow(
                icon: "checklist", title: "Provas",
                detail: provasPend > 0 ? "\(provasPend) por vir" : "Em dia",
                action: { router.navigate(to: .faculdadeProvas) }
            )
            shortcutDivider
            shortcutRow(
                icon: "doc.richtext", title: "Trabalhos",
                detail: trabalhosPend > 0 ? "\(trabalhosPend) pendente\(trabalhosPend == 1 ? "" : "s")" : "Em dia",
                action: { router.navigate(to: .trabalhos) }
            )
            shortcutDivider
            shortcutRow(
                icon: "folder", title: "Documentos",
                detail: "Planos, slides e materiais",
                action: { router.navigate(to: .faculdadeDocumentos) }
            )
        }
        .glassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
    }

    private var shortcutDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private func shortcutRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(PixioTypo.sans(size: 13, weight: .semibold))
                    .foregroundStyle(goldPrimary.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7).fill(goldPrimary.opacity(0.10)))  // ds-allow: raio 7 ja e o padrao visual desta tela; sem token exato
                Text(title)
                    .font(PixioTypo.sans(size: 14, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Spacer(minLength: 8)
                Text(detail)
                    .font(PixioTypo.sans(size: 11))
                    .foregroundStyle(textWarm.opacity(0.45))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(PixioTypo.sans(size: 10, weight: .semibold))
                    .foregroundStyle(textDim)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func miniTrabalhoLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = SubjectColors.colorFor(subject: subject)
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(eval.title)
                .font(PixioTypo.sans(size: 11, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.80))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let dateStr = eval.date {
                Text(shortDate(dateStr))
                    .font(PixioTypo.sans(size: 10, weight: .medium))
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

    // MARK: - Shared mini card header

    private func miniCardHeader(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(PixioTypo.sans(size: 11, weight: .semibold))
                .foregroundStyle(goldPrimary.opacity(0.80))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6)  // ds-allow: raio 6 ja e o padrao visual desta tela; sem token exato
                        .fill(goldPrimary.opacity(0.10))
                )
            Text(title)
                .font(PixioTypo.sans(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(PixioTypo.sans(size: 10))
                    .foregroundStyle(textDim)
            }
            Image(systemName: "chevron.right")
                .font(PixioTypo.sans(size: 10, weight: .semibold))
                .foregroundStyle(textDim)
        }
    }

}


// MARK: - FaculdadeProvasScreen — notas por disciplina + provas agendadas + adicionar

struct FaculdadeProvasScreen: View {
    let onBack: () -> Void
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData

    @State private var provas: [Prova] = []
    @State private var loading = true
    @State private var showAdd = false

    private var goldPrimary: Color { VitaColors.accentHover }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(title: "Provas", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    notasSection
                    provasSection
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            AdicionarProvaSheet(disciplinas: appData.canonicalDisciplines) { title, subjectId, date, notes in
                await save(title: title, subjectId: subjectId, date: date, notes: notes)
            }
        }
    }

    private var notasSection: some View {
        let subjects = appData.dashboardSubjects.filter { !(($0.name) ?? "").isEmpty && bestGrade($0) != nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Notas por disciplina")
                .font(PixioTypo.sans(size: 10, weight: .semibold)).kerning(0.8).textCase(.uppercase)
                .foregroundStyle(VitaColors.sectionLabel)
            if subjects.isEmpty {
                Text("As notas aparecem aqui quando forem lançadas no portal.")
                    .font(PixioTypo.sans(size: 12)).foregroundStyle(textDim).padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(subjects.enumerated()), id: \.offset) { idx, subj in
                        notaRow(name: (subj.name) ?? "—", grade: bestGrade(subj))
                        if idx < subjects.count - 1 {
                            Rectangle().fill(textWarm.opacity(0.06)).frame(height: 1).padding(.leading, 26)
                        }
                    }
                }
                .glassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
            }
        }
    }

    private func bestGrade(_ s: DashboardSubject) -> Double? {
        s.finalGrade ?? s.grade3 ?? s.grade2 ?? s.grade1
    }

    private func notaRow(name: String, grade: Double?) -> some View {
        HStack(spacing: 12) {
            Circle().fill(SubjectColors.colorFor(subject: name)).frame(width: 6, height: 6)
            Text(name).font(PixioTypo.sans(size: 13, weight: .medium)).foregroundStyle(textPrimary).lineLimit(1)
            Spacer(minLength: 8)
            Text(grade != nil ? String(format: "%.1f", grade!) : "—")
                .font(PixioTypo.sans(size: 14, weight: .semibold)).monospacedDigit()
                .foregroundStyle(grade == nil ? textDim : goldPrimary)
        }
        .padding(.horizontal, 14).frame(height: 46)
    }

    private var provasSorted: [Prova] { provas.sorted { $0.date < $1.date } }

    private var provasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Minhas provas")
                    .font(PixioTypo.sans(size: 10, weight: .semibold)).kerning(0.8).textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer()
                Button { showAdd = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(PixioTypo.sans(size: 9, weight: .bold))
                        Text("Adicionar").font(PixioTypo.sans(size: 10, weight: .medium))
                    }
                    .foregroundStyle(goldPrimary.opacity(0.80))
                }
                .buttonStyle(.plain)
            }
            if loading {
                Text("Carregando…").font(PixioTypo.sans(size: 12)).foregroundStyle(textDim).padding(.vertical, 8)
            } else if provasSorted.isEmpty {
                Button { showAdd = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus").font(PixioTypo.sans(size: 15)).foregroundStyle(goldPrimary.opacity(0.5))
                        Text("Nenhuma prova agendada. Toque para adicionar.").font(PixioTypo.sans(size: 12)).foregroundStyle(textWarm.opacity(0.5))
                        Spacer(minLength: 0)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(provasSorted.enumerated()), id: \.offset) { idx, prova in
                        provaRow(prova)
                        if idx < provasSorted.count - 1 {
                            Rectangle().fill(textWarm.opacity(0.06)).frame(height: 1).padding(.leading, 66)
                        }
                    }
                }
                .glassCard(cornerRadius: 14)  // ds-allow: raio 14 ja e o padrao visual desta tela; sem token exato
            }
        }
    }

    private func provaRow(_ prova: Prova) -> some View {
        let disc = appData.canonicalDisciplines.first { $0.id == prova.subjectId }?.preferredName
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(dayOf(prova.date)).font(PixioTypo.sans(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(textPrimary)
                Text(monthOf(prova.date)).font(PixioTypo.sans(size: 9, weight: .semibold)).textCase(.uppercase).foregroundStyle(textDim)
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(prova.title).font(PixioTypo.sans(size: 13, weight: .semibold)).foregroundStyle(textPrimary).lineLimit(1)
                if let disc { Text(disc).font(PixioTypo.sans(size: 11)).foregroundStyle(textWarm.opacity(0.45)).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
    }

    private func parseDate(_ raw: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "pt_BR")
        return f.date(from: String(raw.prefix(10)))
    }
    private func dayOf(_ raw: String) -> String { guard let d = parseDate(raw) else { return "—" }; let f = DateFormatter(); f.dateFormat = "dd"; return f.string(from: d) }
    private func monthOf(_ raw: String) -> String { guard let d = parseDate(raw) else { return "" }; let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "MMM"; return f.string(from: d) }

    private func load() async {
        loading = true
        provas = (try? await container.api.getProvas()) ?? []
        loading = false
    }
    private func save(title: String, subjectId: String?, date: String, notes: String?) async {
        _ = try? await container.api.createProva(title: title, subjectId: subjectId, date: date, notes: notes)
        await load()
    }
}

// MARK: - AdicionarProvaSheet — form nativo

struct AdicionarProvaSheet: View {
    let disciplinas: [AcademicSubject]
    let onSave: (String, String?, String, String?) async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subjectId = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Prova") {
                    TextField("Título (ex: P1 de Anatomia)", text: $title)
                    Picker("Disciplina", selection: $subjectId) {
                        Text("Nenhuma").tag("")
                        ForEach(disciplinas, id: \.id) { d in
                            Text(d.preferredName).tag(d.id)
                        }
                    }
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                Section("Anotações") {
                    TextField("Opcional", text: $notes, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle("Nova prova")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saving = true
                        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                        let dateStr = f.string(from: date)
                        let sid = subjectId.isEmpty ? nil : subjectId
                        let n = notes.isEmpty ? nil : notes
                        Task { await onSave(title, sid, dateStr, n); dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
