import SwiftUI

// MARK: - DisciplineDetailScreen
// Real data from API. Hero card follows FaculdadeHomeScreen pattern.
// Background: fundo-dashboard.webp + 0.75 overlay (dark content screen).

struct DisciplineDetailScreen: View {
    let disciplineId: String
    let disciplineName: String

    var onBack: (() -> Void)?
    var onNavigateToFlashcards: ((String) -> Void)?
    var onNavigateToQBank: (() -> Void)?
    var onNavigateToSimulado: (() -> Void)?

    @State private var vm: DisciplineDetailViewModel?
    @Environment(\.appContainer) private var container

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: fundo-dashboard + dark overlay
            Image("fundo-dashboard")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.75)
                .ignoresSafeArea()

            if let vm {
                if vm.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    content(vm: vm)
                }
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { onBack?() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(disciplineName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if vm == nil {
                vm = DisciplineDetailViewModel(
                    api: container.api,
                    disciplineId: disciplineId,
                    disciplineName: disciplineName
                )
            }
        }
        .task {
            await vm?.load()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(vm: DisciplineDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard(vm: vm)
                gradesTable(vm: vm)
                nextExamSection(vm: vm)
                assignmentsSection(vm: vm)
                studySuggestionsSection(vm: vm)
                documentsSection(vm: vm)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Hero Card

    private func heroCard(vm: DisciplineDetailViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: Dark warm gradient base
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.045),
                    Color(red: 0.05, green: 0.035, blue: 0.022)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 2: Subject-color radial accent (top-trailing)
            RadialGradient(
                colors: [vm.subjectColor.opacity(0.22), Color.clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 140
            )

            // Layer 3: Decorative book icon
            Image(systemName: "book.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(vm.subjectColor.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 16)

            // Layer 4: Content
            heroCardContent(vm: vm)
        }
        .frame(height: 162)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            VitaColors.accent.opacity(0.40),
                            VitaColors.accent.opacity(0.10),
                            VitaColors.accent.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private func heroCardContent(vm: DisciplineDetailViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                // Eyebrow
                HStack(spacing: 6) {
                    Circle()
                        .fill(VitaColors.accent)
                        .frame(width: 5, height: 5)
                    Text(vm.semester.map { "\($0)º SEMESTRE" } ?? "DISCIPLINA")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(VitaColors.accent)
                }
                .padding(.bottom, 6)

                // Title
                Text(disciplineName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .kerning(-0.4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                // Subtitle: professor
                if let prof = vm.professorName {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.75))
                        Text(prof)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)
            }

            Spacer()

            // VitaScore badge
            vitaScoreBadge(score: vm.vitaScore)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func vitaScoreBadge(score: Int) -> some View {
        let tierColor: Color = {
            if score >= 80 { return VitaTokens.PrimitiveColors.amber400 }
            if score >= 60 { return VitaTokens.PrimitiveColors.green400 }
            if score >= 40 { return VitaTokens.PrimitiveColors.cyan400 }
            return VitaTokens.PrimitiveColors.red400
        }()

        return ZStack {
            Circle()
                .fill(tierColor.opacity(0.15))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(tierColor.opacity(0.50), lineWidth: 1.5)
                .frame(width: 52, height: 52)
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tierColor)
                Text("VITA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(tierColor.opacity(0.80))
            }
        }
    }

    // MARK: - Task 5: Grades Table

    @ViewBuilder
    private func gradesTable(vm: DisciplineDetailViewModel) -> some View {
        let slots = vm.gradeSlots
        let hasAny = slots.p1 != nil || slots.p2 != nil || slots.p3 != nil || slots.sf != nil || vm.attendance != nil
        if hasAny {
            VitaGlassCard {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Text("Avaliacoes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        if vm.hasGradeRisk {
                            Text("RISCO")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(VitaTokens.PrimitiveColors.red400)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(VitaTokens.PrimitiveColors.red400.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }

                    // Column headers
                    HStack(spacing: 0) {
                        ForEach(["P1", "P2", "P3", "SF", "Freq"], id: \.self) { label in
                            Text(label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VitaColors.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Values row
                    HStack(spacing: 0) {
                        gradeCell(value: slots.p1)
                        gradeCell(value: slots.p2)
                        gradeCell(value: slots.p3)
                        gradeCell(value: slots.sf)
                        freqCell(value: vm.attendance)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    @ViewBuilder
    private func gradeCell(value: Double?) -> some View {
        let color: Color = {
            guard let v = value else { return VitaColors.textSecondary }
            if v >= 7.0 { return VitaTokens.PrimitiveColors.green400 }
            if v >= 5.0 { return VitaTokens.PrimitiveColors.amber400 }
            return VitaTokens.PrimitiveColors.red400
        }()
        let text: String = {
            guard let v = value else { return "—" }
            return String(format: "%.1f", v)
        }()
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func freqCell(value: Double?) -> some View {
        let color: Color = {
            guard let v = value else { return VitaColors.textSecondary }
            if v >= 75 { return VitaTokens.PrimitiveColors.green400 }
            if v >= 50 { return VitaTokens.PrimitiveColors.amber400 }
            return VitaTokens.PrimitiveColors.red400
        }()
        let text: String = {
            guard let v = value else { return "—" }
            return "\(Int(v))%"
        }()
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Task 6: Next Exam

    @ViewBuilder
    private func nextExamSection(vm: DisciplineDetailViewModel) -> some View {
        if let exam = vm.nextExam {
            let urgencyColor: Color = {
                if exam.daysUntil <= 0 { return VitaTokens.PrimitiveColors.red400 }
                if exam.daysUntil <= 3 { return VitaTokens.PrimitiveColors.amber400 }
                if exam.daysUntil <= 7 { return VitaColors.accent }
                return VitaTokens.PrimitiveColors.green400
            }()

            VitaGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with countdown
                    HStack(alignment: .center) {
                        Text("Proxima Prova")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(max(0, exam.daysUntil))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(urgencyColor)
                            Text("dias")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(urgencyColor.opacity(0.75))
                        }
                    }

                    // Exam title
                    Text(exam.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)

                    // Date row
                    if !exam.date.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(urgencyColor.opacity(0.80))
                            Text(formatExamDate(exam.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }

                    // Notes / topics
                    if let notes = exam.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(VitaColors.textSecondary)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(urgencyColor.opacity(0.30), lineWidth: 1.5)
            )
        }
    }

    private func formatExamDate(_ dateStr: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
        guard let d = date else { return dateStr }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = "dd 'de' MMMM 'de' yyyy"
        return fmt.string(from: d)
    }

    // MARK: - Task 7: Assignments

    @ViewBuilder
    private func assignmentsSection(vm: DisciplineDetailViewModel) -> some View {
        if !vm.pendingAssignments.isEmpty {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Trabalhos")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    ForEach(Array(vm.pendingAssignments.enumerated()), id: \.element.id) { idx, item in
                        if idx > 0 {
                            Divider()
                                .background(VitaColors.glassBorder)
                                .padding(.horizontal, 16)
                        }
                        assignmentRow(item)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func assignmentRow(_ item: TrabalhoItem) -> some View {
        let isOverdue = (item.daysUntil ?? 0) < 0 || item.status == "overdue"
        let deadlineColor: Color = isOverdue ? VitaTokens.PrimitiveColors.red400 : VitaColors.textSecondary

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(isOverdue ? VitaTokens.PrimitiveColors.red400 : VitaColors.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                    if isOverdue {
                        Text("ATRASADO")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(VitaTokens.PrimitiveColors.red400)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VitaTokens.PrimitiveColors.red400.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let days = item.daysUntil {
                        Text(days < 0 ? "\(abs(days))d atrasado" : days == 0 ? "Hoje" : "\(days)d restantes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(deadlineColor)
                    }
                    Text(item.submissionTypeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Task 8: Study Suggestions

    @ViewBuilder
    private func studySuggestionsSection(vm: DisciplineDetailViewModel) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estudar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // Flashcards card
                        studyMiniCard(
                            icon: "rectangle.on.rectangle.angled",
                            title: "Flashcards",
                            detail: vm.flashcardsDue > 0
                                ? "\(vm.flashcardsDue) para revisar"
                                : "\(vm.flashcardsTotal) cards",
                            cta: vm.flashcardsDue > 0 ? "Revisar" : "Estudar",
                            color: VitaColors.toolFlashcards
                        ) {
                            if let deck = vm.subjectDecks.first {
                                onNavigateToFlashcards?(deck.id)
                            } else {
                                onNavigateToFlashcards?("")
                            }
                        }

                        // QBank card
                        studyMiniCard(
                            icon: "list.bullet.clipboard",
                            title: "Questoes",
                            detail: "Banco de questoes",
                            cta: "Praticar",
                            color: VitaColors.toolQBank
                        ) {
                            onNavigateToQBank?()
                        }

                        // Simulado card
                        studyMiniCard(
                            icon: "clock.badge.checkmark",
                            title: "Simulado",
                            detail: "Prova cronometrada",
                            cta: "Iniciar",
                            color: VitaColors.toolSimulados
                        ) {
                            onNavigateToSimulado?()
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func studyMiniCard(
        icon: String,
        title: String,
        detail: String,
        cta: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(cta)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(12)
            .frame(width: 120, height: 130)
            .background(
                Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.80)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VitaColors.glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task 9: Documents

    @ViewBuilder
    private func documentsSection(vm: DisciplineDetailViewModel) -> some View {
        // Documents endpoint available via getDocuments(subjectId:)
        if !vm.subjectDocuments.isEmpty {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Materiais")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    ForEach(Array(vm.subjectDocuments.enumerated()), id: \.element.id) { idx, doc in
                        if idx > 0 {
                            Divider()
                                .background(VitaColors.glassBorder)
                                .padding(.horizontal, 16)
                        }
                        documentRow(doc, color: vm.subjectColor)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: VitaDocument, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.isEmpty ? doc.fileName : doc.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                if let createdAt = doc.createdAt {
                    Text(formatDocDate(createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()

            if doc.totalPages > 0 {
                Text("\(doc.totalPages)p")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatDocDate(_ dateStr: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
        guard let d = date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateStyle = .medium
        return fmt.string(from: d)
    }
}
