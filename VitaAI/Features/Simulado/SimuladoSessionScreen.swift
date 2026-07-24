import SwiftUI
import Sentry

// Gold accent → VitaColors references
private let quizGold     = VitaColors.glassInnerLight   // rgba(200,155,70)
private let quizGoldHi   = VitaColors.accentHover       // rgba(255,200,120)
private let quizBg       = VitaColors.surface            // #08060a

private let optionLetters = ["A", "B", "C", "D", "E"]

struct SimuladoSessionScreen: View {
    let attemptId: String
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onFinished: (String) -> Void

    @State private var showGrid = false
    @State private var showFinishDialog = false
    @State private var showExplanationSheet = false
    @State private var elapsedSeconds = 0
    @State private var timerTask: Task<Void, Never>? = nil

    private var totalSeconds: Int {
        guard let vm else { return 1 }
        // Limite real da prova cronometrada (template); fallback 2min/questao.
        if let mins = vm.state.timeLimitMinutes, mins > 0 { return mins * 60 }
        return max(1, vm.state.questions.count * 120)
    }

    private var remainingSeconds: Int {
        max(0, totalSeconds - elapsedSeconds)
    }

    private var timerStr: String {
        let secs = vm?.state.timedMode == true ? remainingSeconds : elapsedSeconds
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private var timerWarning: Bool {
        guard vm?.state.timedMode == true else { return false }
        return remainingSeconds < 300 && remainingSeconds >= 120
    }

    private var timerCritical: Bool {
        guard vm?.state.timedMode == true else { return false }
        return remainingSeconds < 120
    }

    var body: some View {
        Group {
            if let vm {
                ZStack {
                    Color.clear.ignoresSafeArea()

                    if vm.state.isLoading || vm.state.currentQuestion == nil {
                        loadingView
                    } else {
                        sessionContent(vm: vm)
                    }
                }
                .onChange(of: vm.state.result) { result in
                    if result != nil {
                        onFinished(vm.state.currentAttemptId ?? attemptId)
                    }
                }
                .onChange(of: vm.state.timedMode) { timed in
                    if timed && remainingSeconds <= 0 { vm.finishSimulado() }
                }
                // vita-modals-ignore: gridSheet/explanationSheet already wrap VitaSheet internally
                .sheet(isPresented: $showGrid) { gridSheet(vm: vm) }
                .sheet(isPresented: $showExplanationSheet) { explanationSheet(vm: vm) }
                .vitaAlert(
                    isPresented: $showFinishDialog,
                    title: "Finalizar?",
                    message: {
                        let unanswered = vm.state.questions.count - vm.state.answers.count
                        return unanswered > 0
                            ? "Você ainda tem \(unanswered) questão(ões) sem resposta. Deseja finalizar mesmo assim?"
                            : "Tem certeza que deseja finalizar a prova?"
                    }(),
                    destructiveLabel: "Finalizar",
                    cancelLabel: "Continuar",
                    onConfirm: { vm.finishSimulado() }
                )
            } else {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    loadingView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api, gamificationEvents: container.gamificationEvents, dataManager: container.dataManager) }
            guard let vm else { return }
            Task {
                if vm.state.currentAttemptId != attemptId || vm.state.questions.isEmpty {
                    vm.loadSession(attemptId)
                }
                SentrySDK.reportFullyDisplayed()
            }
            startTimer()
        }
        .onDisappear { timerTask?.cancel() }
        .trackScreen("SimuladoSession", extra: ["attempt_id": attemptId])
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            DashboardSkeleton()
                .tint(quizGold)
                .scaleEffect(1.2)
            Text("Carregando simulado...")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.white.opacity(0.55))
        }
    }

    // MARK: - Session

    @ViewBuilder
    private func sessionContent(vm: SimuladoViewModel) -> some View {
        if let question = vm.state.currentQuestion {
            let options = question.parsedOptions
            let selectedIdx = vm.state.answers[question.id]
            let isExam = vm.state.isExamMode
            let showFeedback = vm.state.showFeedback && !isExam
            let isAnswered = showFeedback

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Sair")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        .frame(minWidth: 52, alignment: .leading)
                    }
                    .accessibilityIdentifier("backButton")

                    Spacer()

                    Text("Questão \(vm.state.currentQuestionIndex + 1) de \(vm.state.questions.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VitaColors.white.opacity(0.65))

                    Spacer()

                    if vm.state.timedMode {
                        Text(timerStr)
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(timerCritical
                                ? Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.92)
                                : timerWarning
                                    ? Color(red: 245/255, green: 180/255, blue: 60/255).opacity(0.92)
                                    : VitaColors.white.opacity(0.85))
                            .frame(minWidth: 52, alignment: .trailing)
                            .opacity(timerCritical ? (elapsedSeconds % 2 == 0 ? 1 : 0.55) : 1)
                            .animation(.easeInOut(duration: 0.4), value: elapsedSeconds)
                    } else {
                        Spacer().frame(minWidth: 52)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // ── Progress bar (3px gold gradient) ───────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        let pct = vm.state.questions.isEmpty ? 0.0
                            : CGFloat(vm.state.currentQuestionIndex) / CGFloat(vm.state.questions.count)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [quizGold.opacity(0.70), quizGoldHi.opacity(0.50)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * pct)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.state.currentQuestionIndex)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)

                // ── Scrollable content ───────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Question card ──────────────────────
                        ZStack(alignment: .topLeading) {
                            // Card background
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: [
                                        Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.94),
                                        Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.90)
                                    ],
                                    startPoint: UnitPoint(x: 0.5, y: 0),
                                    endPoint: UnitPoint(x: 0.5, y: 1)
                                ))
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(quizGold.opacity(0.10), lineWidth: 1)
                            // Inner corner glow
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(VitaColors.textWarm.opacity(0.10), lineWidth: 0.5)
                                .padding(0.5)

                            VStack(alignment: .leading, spacing: 14) {
                                // Topic tag
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.45))
                                        .frame(width: 4, height: 4)
                                    Text((question.topic ?? question.subject ?? "Geral").uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundStyle(Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.65))
                                }

                                // Question text
                                Text(question.statement)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(VitaColors.white.opacity(0.92))
                                    .lineSpacing(5.4)
                                    .tracking(-0.15)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .shadow(color: .black.opacity(0.50), radius: 25, y: 10)

                        // ── Options ────────────────────────────
                        VStack(spacing: 8) {
                            ForEach(Array(options.enumerated()), id: \.offset) { idx, optionText in
                                QuizOptionRow(
                                    idx: idx,
                                    text: optionText,
                                    selectedIdx: selectedIdx,
                                    correctIdx: question.correctIdx,
                                    showFeedback: showFeedback
                                ) {
                                    vm.selectAnswer(questionId: question.id, chosenIdx: idx)
                                    if !isExam { vm.confirmAnswer() }
                                    else { vm.confirmAnswer() }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                        // ── Inline feedback card ───────────────
                        if isAnswered {
                            let isCorrect = vm.state.lastAnswerCorrect == true
                            QuizFeedbackCard(
                                isCorrect: isCorrect,
                                explanation: question.explanation,
                                onViewDetail: question.explanation == nil ? {
                                    vm.loadExplanation(questionId: question.id)
                                    showExplanationSheet = true
                                } : nil
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 6)),
                                removal: .opacity
                            ))
                        }

                        Spacer(minLength: 120)
                    }
                }

                // ── Bottom actions ─────────────────────────────
                VStack(spacing: 8) {
                    if isAnswered {
                        // Full-width gold nav button
                        let isLast = vm.state.currentQuestionIndex == vm.state.questions.count - 1
                        Button {
                            if isLast { vm.finishSimulado() }
                            else { vm.nextQuestion() }
                        } label: {
                            Text(isLast ? "Finalizar Simulado" : "Próxima Questão →")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(-0.15)
                                .foregroundStyle(Color.white.opacity(0.96))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [quizGold.opacity(0.80), Color(red: 160/255, green: 110/255, blue: 40/255).opacity(0.65)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: quizGold.opacity(0.25), radius: 12, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 1, green: 235/255, blue: 180/255).opacity(0.22),
                                                lineWidth: 0.5)
                                        .padding(0.5)
                                )
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 4)),
                            removal: .opacity
                        ))
                    } else if isExam {
                        // Exam mode: mark + grid + confirm
                        HStack(spacing: 8) {
                            Button {
                                vm.toggleMark(question.questionNo)
                            } label: {
                                Image(systemName: vm.state.markedQuestions.contains(question.questionNo) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 18))
                                    .foregroundStyle(vm.state.markedQuestions.contains(question.questionNo)
                                        ? VitaColors.dataAmber : VitaColors.textTertiary)
                                    .frame(width: 44, height: 44)
                            }

                            Button {
                                showGrid = true
                            } label: {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 18))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .frame(width: 44, height: 44)
                            }

                            Spacer()

                            Button {
                                vm.confirmAnswer()
                            } label: {
                                Text("Confirmar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(quizBg)
                                    .padding(.horizontal, 32)
                                    .frame(height: 46)
                                    .background(selectedIdx != nil ? quizGold : quizGold.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(selectedIdx == nil)
                        }
                    }

                    Button {
                        showFinishDialog = true
                    } label: {
                        Text(isExam ? "Finalizar Prova" : "Encerrar Simulado")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                // Limpa a VitaTabBar (overlay global ~90pt) pra o CTA nao ficar
                // escondido atras da barra de navegacao. Rafael 2026-07-12.
                .padding(.bottom, 92)
                .animation(.easeInOut(duration: 0.3), value: isAnswered)
            }
        }
    }

    // MARK: - Grid Sheet

    @ViewBuilder
    private func gridSheet(vm: SimuladoViewModel) -> some View {
        VitaSheet(title: "Questões") {
        VStack(alignment: .leading, spacing: 16) {

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(Array(vm.state.questions.enumerated()), id: \.offset) { idx, q in
                    let isAnswered = vm.state.answers[q.id] != nil
                    let isMarked = vm.state.markedQuestions.contains(q.questionNo)
                    let isCurrent = idx == vm.state.currentQuestionIndex
                    let bg: Color = isMarked ? VitaColors.dataAmber : isAnswered ? quizGold : VitaColors.glassBorder

                    Button {
                        vm.goToQuestion(idx)
                        showGrid = false
                    } label: {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                            .foregroundStyle(isAnswered || isMarked ? quizBg : VitaColors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(bg.opacity(isCurrent ? 1 : 0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VitaButton(text: "Finalizar Prova", action: {
                showGrid = false
                showFinishDialog = true
            }, variant: .secondary)
        }
        .padding(20)
        }
    }

    // MARK: - Explanation Sheet

    @ViewBuilder
    private func explanationSheet(vm: SimuladoViewModel) -> some View {
        VitaSheet(title: "Explicação") {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                if vm.state.isLoadingExplanation {
                    HStack { Spacer(); ProgressView().tint(quizGold); Spacer() }
                        .frame(height: 80)
                } else if let explanation = vm.state.currentExplanation {
                    Text(explanation.general)
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineSpacing(3)

                    if !explanation.perOption.isEmpty {
                        Text("Por alternativa")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.top, 8)

                        ForEach(explanation.perOption) { opt in
                            let letter = optionLetters.indices.contains(opt.index) ? optionLetters[opt.index] : "\(opt.index + 1)"
                            let isCorrect = opt.index == vm.state.currentQuestion?.correctIdx
                            HStack(alignment: .top, spacing: 4) {
                                Text("\(letter))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                Text(opt.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textPrimary)
                            }
                        }
                    }
                } else {
                    Text("Explicação não disponível")
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        }
        .onDisappear { vm.dismissExplanation() }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        let start = vm?.state.sessionStartDate ?? Date()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds = Int(Date().timeIntervalSince(start))
                if vm?.state.timedMode == true && remainingSeconds <= 0 {
                    vm?.finishSimulado()
                    break
                }
            }
        }
    }
}

// MARK: - Canonical QBank exam surface

/// Official/catalog exams use canonical QBank data, but must feel like a real
/// exam: one continuous paper, no immediate feedback and a persistent map/submit bar.
struct QBankSimuladoSessionScreen: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    @State private var showMap = false
    @State private var showFinishDialog = false
    @State private var scrollQuestionId: Int?
    @State private var timerTask: Task<Void, Never>?

    private var questions: [QBankQuestionDetail] { vm.state.simuladoQuestions }
    private var answeredCount: Int { vm.state.simuladoSelections.count }
    private var totalQuestions: Int { questions.count }
    private var progress: Double {
        totalQuestions > 0 ? Double(answeredCount) / Double(totalQuestions) : 0
    }
    private var remainingSeconds: Int {
        max(0, (vm.state.timeLimitSeconds ?? max(1, totalQuestions * 180)) - vm.state.elapsedSeconds)
    }
    private var timerText: String {
        let hours = remainingSeconds / 3_600
        let minutes = (remainingSeconds % 3_600) / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        ZStack {
            Color(red: 4/255, green: 12/255, blue: 21/255).ignoresSafeArea()  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)

            if vm.state.questionLoading {
                loadingView
            } else if questions.isEmpty {
                emptyView
            } else {
                examContent
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showMap) { mapSheet }
        .vitaAlert(
            isPresented: $showFinishDialog,
            title: "Finalizar prova?",
            message: unansweredCount > 0
                ? "Você ainda tem \(unansweredCount) questão(ões) sem resposta. Deseja finalizar mesmo assim?"
                : "Suas respostas serão entregues e o resultado será calculado.",
            destructiveLabel: "Finalizar",
            cancelLabel: "Continuar",
            onConfirm: { vm.finishSimuladoExam() }
        )
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
        .trackScreen("QBankSimuladoSession", extra: ["session_id": vm.state.session?.id ?? ""])
    }

    private var unansweredCount: Int { max(0, totalQuestions - answeredCount) }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            Text("Carregando a prova completa...")
                .font(.system(size: 14, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                .foregroundStyle(Color.white.opacity(0.64))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                .foregroundStyle(Color.orange)
            Text(vm.state.error ?? "Não foi possível carregar as questões desta prova.")
                .font(.system(size: 14))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Voltar", action: onBack)
                .font(.system(size: 14, weight: .semibold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                .foregroundStyle(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
        }
    }

    private var examContent: some View {
        VStack(spacing: 0) {
            examHeader

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.10))
                    Rectangle()
                        .fill(Color(red: 76/255, green: 157/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .frame(width: geometry.size.width * progress)
                        .animation(.easeInOut(duration: 0.2), value: progress)
                }
            }
            .frame(height: 3)

            GeometryReader { viewport in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                                QBankSimuladoQuestionBlock(
                                    question: question,
                                    number: index + 1,
                                    selectedAlternativeId: vm.state.simuladoSelections[question.id],
                                    isMarked: vm.state.markedForReview.contains(question.id),
                                    isSaving: vm.state.simuladoSavingQuestionIds.contains(question.id),
                                    saveFailed: vm.state.simuladoSaveFailures.contains(question.id),
                                    onSelect: { alternativeId in
                                        vm.selectSimuladoAnswer(
                                            questionId: question.id,
                                            alternativeId: alternativeId
                                        )
                                    },
                                    onToggleMark: {
                                        if vm.state.markedForReview.contains(question.id) {
                                            vm.state.markedForReview.remove(question.id)
                                        } else {
                                            vm.state.markedForReview.insert(question.id)
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(question.id)
                            }
                        }
                        .frame(
                            width: max(0, viewport.size.width - 36),
                            alignment: .topLeading
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 24)
                        .padding(.bottom, 30)
                    }
                    .frame(
                        width: viewport.size.width,
                        height: viewport.size.height,
                        alignment: .topLeading
                    )
                    .onChange(of: scrollQuestionId) { _, questionId in
                        guard let questionId else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(questionId, anchor: .top)
                        }
                        scrollQuestionId = nil
                    }
                }
            }

            if let error = vm.state.answerError {
                Text(error)
                    .font(.system(size: 11, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color(red: 255/255, green: 150/255, blue: 140/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Color(red: 80/255, green: 20/255, blue: 20/255).opacity(0.35))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            }

            bottomBar
        }
    }

    private var examHeader: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color.white.opacity(0.86))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.white.opacity(0.035)))
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sair da prova")

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.state.session?.title ?? "Simulado")
                    .font(.system(size: 18, weight: .semibold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                Text("Prova oficial · \(totalQuestions) questões")
                    .font(.system(size: 12))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                Text(timerText)
                    .font(.system(size: 16, weight: .medium).monospacedDigit())  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            }
            .foregroundStyle(
                remainingSeconds < 300
                    ? Color(red: 255/255, green: 110/255, blue: 100/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    : Color(red: 245/255, green: 183/255, blue: 56/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Color(red: 4/255, green: 12/255, blue: 21/255).opacity(0.98))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: { showMap = true }) {
                HStack(spacing: 7) {
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    Text("Mapa")
                        .font(.system(size: 14, weight: .semibold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                }
                .foregroundStyle(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 5) {
                if !vm.state.simuladoSavingQuestionIds.isEmpty {
                    ProgressView().controlSize(.small).tint(Color.white.opacity(0.55))
                }
                Text("\(answeredCount)/\(totalQuestions)")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                Text("respondidas")
                    .font(.system(size: 12))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            Button(action: { showFinishDialog = true }) {
                Text("Finalizar")
                    .font(.system(size: 15, weight: .semibold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 63/255, green: 138/255, blue: 235/255),  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                Color(red: 86/255, green: 161/255, blue: 255/255),  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }

    private var mapSheet: some View {
        VitaSheet(title: "Mapa da prova") {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                    spacing: 10
                ) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        let answered = vm.state.simuladoSelections[question.id] != nil
                        let marked = vm.state.markedForReview.contains(question.id)
                        Button {
                            scrollQuestionId = question.id
                            showMap = false
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .semibold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                    .foregroundStyle(answered ? Color.white : VitaColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                            .fill(
                                                answered
                                                    ? Color(red: 63/255, green: 138/255, blue: 235/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                                    : VitaColors.surfaceElevated
                                            )
                                    )
                                if marked {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 8))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                        .foregroundStyle(Color(red: 245/255, green: 183/255, blue: 56/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                        .padding(5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }

    private func startTimer() {
        guard timerTask == nil else { return }
        timerTask = Task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                vm.tickTimer()
            }
            if remainingSeconds == 0, !Task.isCancelled {
                showFinishDialog = true
            }
        }
    }
}

private struct QBankSimuladoQuestionBlock: View {
    let question: QBankQuestionDetail
    let number: Int
    let selectedAlternativeId: Int?
    let isMarked: Bool
    let isSaving: Bool
    let saveFailed: Bool
    let onSelect: (Int) -> Void
    let onToggleMark: () -> Void

    private var metadata: String {
        [question.topics.first?.title, question.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUESTÃO \(number)")
                        .font(.system(size: 15, weight: .bold))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.system(size: 12))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView().controlSize(.small).tint(Color.white.opacity(0.5))
                    } else if saveFailed {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(Color(red: 255/255, green: 130/255, blue: 115/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    }
                    Button(action: onToggleMark) {
                        Image(systemName: isMarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 19, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                            .foregroundStyle(
                                isMarked
                                    ? Color(red: 245/255, green: 183/255, blue: 56/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                    : Color.white.opacity(0.80)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(question.statement.qbankPlainText)
                .font(.system(size: 16))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                .foregroundStyle(Color.white.opacity(0.93))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(question.images.filter { $0.alternativeId == nil }) { image in
                QBankSimuladoImage(image: image)
            }

            VStack(spacing: 9) {
                ForEach(Array(question.alternatives.enumerated()), id: \.element.id) { index, alternative in
                    QBankSimuladoAlternativeRow(
                        index: index,
                        alternative: alternative,
                        images: question.images.filter { $0.alternativeId == alternative.id },
                        selected: selectedAlternativeId == alternative.id,
                        action: { onSelect(alternative.id) }
                    )
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.top, 16)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QBankSimuladoAlternativeRow: View {
    let index: Int
    let alternative: QBankAlternative
    let images: [QBankImage]
    let selected: Bool
    let action: () -> Void

    private var letter: String {
        optionLetters.indices.contains(index) ? optionLetters[index] : String(index + 1)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.system(size: 15, weight: .medium))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .foregroundStyle(selected ? Color(red: 93/255, green: 165/255, blue: 255/255) : Color.white.opacity(0.72))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(selected ? Color(red: 32/255, green: 91/255, blue: 155/255).opacity(0.25) : Color.clear))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .overlay(
                        Circle().stroke(
                            selected
                                ? Color(red: 93/255, green: 165/255, blue: 255/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                                : Color.white.opacity(0.38),
                            lineWidth: 1.2
                        )
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(alternative.text.qbankPlainText)
                        .font(.system(size: 14))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .foregroundStyle(Color.white.opacity(selected ? 0.94 : 0.68))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(images) { image in
                        QBankSimuladoImage(image: image)
                    }
                }

                if selected {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 22))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .foregroundStyle(Color(red: 93/255, green: 165/255, blue: 255/255))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .fill(selected ? Color(red: 22/255, green: 55/255, blue: 90/255).opacity(0.40) : Color.black.opacity(0.16))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                    .stroke(
                        selected
                            ? Color(red: 93/255, green: 165/255, blue: 255/255)  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                            : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QBankSimuladoImage: View {
    let image: QBankImage

    var body: some View {
        if let url = URL(string: image.imageUrl), !image.imageUrl.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loaded):
                    loaded
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                case .failure:
                    Label("Imagem indisponível", systemImage: "photo")  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .font(.system(size: 12))  // ds-allow: paleta propria do Simulado (SF + cores proprias), intencional (Rafael 2026-07-24)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity, minHeight: 72)
                default:
                    ProgressView()
                        .tint(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
            }
        }
    }
}

// MARK: - Quiz Option Row

private struct QuizOptionRow: View {
    let idx: Int
    let text: String
    let selectedIdx: Int?
    let correctIdx: Int
    let showFeedback: Bool
    let onSelect: () -> Void

    private var isSelected: Bool { selectedIdx == idx }
    private var isCorrect: Bool { idx == correctIdx }
    private var isWrong: Bool { showFeedback && isSelected && !isCorrect }

    private var borderColor: Color {
        if showFeedback && isCorrect { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.45) }
        if isWrong { return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.40) }
        if isSelected { return VitaColors.accentHover.opacity(0.40) }
        return VitaColors.accentHover.opacity(0.10)
    }

    private var bgColors: [Color] {
        if showFeedback && isCorrect {
            return [Color(red: 8/255, green: 24/255, blue: 14/255).opacity(0.95),
                    Color(red: 6/255, green: 18/255, blue: 10/255).opacity(0.92)]
        }
        if isWrong {
            return [Color(red: 22/255, green: 8/255, blue: 8/255).opacity(0.95),
                    Color(red: 16/255, green: 6/255, blue: 6/255).opacity(0.92)]
        }
        if isSelected {
            return [Color(red: 24/255, green: 16/255, blue: 8/255).opacity(0.95),
                    Color(red: 16/255, green: 11/255, blue: 7/255).opacity(0.92)]
        }
        return [Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.85),
                Color(red: 10/255, green: 8/255, blue: 6/255).opacity(0.80)]
    }

    private var letterBg: Color {
        if showFeedback && isCorrect { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.20) }
        if isWrong { return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.20) }
        if isSelected { return Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.20) }
        return Color.white.opacity(0.06)
    }

    private var letterBorder: Color {
        if showFeedback && isCorrect { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.35) }
        if isWrong { return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.30) }
        if isSelected { return VitaColors.accentHover.opacity(0.30) }
        return VitaColors.accentHover.opacity(0.12)
    }

    private var letterFg: Color {
        if showFeedback && isCorrect { return Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.92) }
        if isWrong { return Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.92) }
        if isSelected { return VitaColors.accentLight.opacity(0.90) }
        return VitaColors.textWarm.opacity(0.55)
    }

    private var textFg: Color {
        if showFeedback && isCorrect { return Color(red: 200/255, green: 240/255, blue: 210/255).opacity(0.92) }
        if isWrong { return Color(red: 255/255, green: 200/255, blue: 190/255).opacity(0.85) }
        return VitaColors.white.opacity(0.82)
    }

    private var letter: String {
        optionLetters.indices.contains(idx) ? optionLetters[idx] : "\(idx + 1)"
    }

    var body: some View {
        Button(action: { if !showFeedback { onSelect() } }) {
            HStack(alignment: .top, spacing: 12) {
                // Letter badge: 24×24, cornerRadius 8 (rounded square per mockup)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(letterBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(letterBorder, lineWidth: 1)
                        )
                    Text(letter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(letterFg)
                }
                .frame(width: 24, height: 24)

                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textFg)
                    .lineSpacing(2.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: bgColors,
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(showFeedback)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: showFeedback)
    }
}

// MARK: - Inline Feedback Card

private struct QuizFeedbackCard: View {
    let isCorrect: Bool
    let explanation: String?
    let onViewDetail: (() -> Void)?

    private var accent: Color {
        isCorrect ? Color(red: 34/255, green: 197/255, blue: 94/255)
                  : Color(red: 239/255, green: 68/255, blue: 68/255)
    }

    private var bgColors: [Color] {
        isCorrect
            ? [Color(red: 8/255, green: 20/255, blue: 12/255).opacity(0.90),
               Color(red: 6/255, green: 16/255, blue: 10/255).opacity(0.88)]
            : [Color(red: 20/255, green: 8/255, blue: 8/255).opacity(0.90),
               Color(red: 16/255, green: 6/255, blue: 6/255).opacity(0.88)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isCorrect ? "✓ Correto!" : "✗ Incorreto")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(
                    isCorrect
                        ? Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.90)
                        : Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.90)
                )

            if let explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.white.opacity(0.65))
                    .lineSpacing(3.3)
            } else if let onViewDetail {
                Button(action: onViewDetail) {
                    Text("Ver explicação detalhada →")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.80))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: bgColors,
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.06), radius: 7)
    }
}
