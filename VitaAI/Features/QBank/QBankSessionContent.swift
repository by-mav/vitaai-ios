import SwiftUI

// MARK: - Session content

struct QBankSessionContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showFinishAlert = false
    @State private var showExplanationSheet = false
    @State private var timerTask: Task<Void, Never>? = nil

    // Cap image height so it never overflows on iPad.
    // iPhone: 260pt max. iPad (regular width): 400pt max.
    private var maxImageHeight: CGFloat {
        horizontalSizeClass == .regular ? 400 : 260
    }

    var timerStr: String {
        let s = vm.state.elapsedSeconds
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            if vm.state.questionLoading || vm.state.currentQuestionDetail == nil {
                VStack(spacing: 12) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Carregando questão...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            } else if let question = vm.state.currentQuestionDetail {
                sessionContent(question: question)
            }
        }
        .sheet(isPresented: $showExplanationSheet) {
            VitaSheet(title: "Explicação") {
                if let question = vm.state.currentQuestionDetail {
                    QBankExplanationSheet(
                        question: question,
                        selectedAlternativeId: vm.state.selectedAlternativeId
                    )
                }
            }
        }
        .vitaAlert(
            isPresented: $showFinishAlert,
            title: "Encerrar Sessão?",
            message: "Você respondeu \(vm.state.sessionAnswers.count) de \(vm.state.totalInSession) questões. Deseja encerrar?",
            destructiveLabel: "Encerrar",
            cancelLabel: "Continuar",
            onConfirm: { vm.finishSession() }
        )
        .preference(key: ImmersivePreferenceKey.self, value: true)
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    @ViewBuilder
    private func sessionContent(question: QBankQuestionDetail) -> some View {
        let sortedAlts = question.alternatives.sorted { $0.sortOrder < $1.sortOrder }
        let questionImages = question.images.filter { ($0.alternativeId ?? 0) == 0 }
        let alternativeImagesById = Dictionary(
            grouping: question.images.filter { ($0.alternativeId ?? 0) > 0 },
            by: { $0.alternativeId ?? 0 }
        )

        VStack(spacing: 0) {
            sessionHeader(question: question)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    topicRail(question: question)

                    QBankQuestionPanel {
                        questionBadges(question: question)

                        Text(question.statement.qbankPlainText)
                            .font(PixioTypo.sans(size: 16, weight: .regular))
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        if !questionImages.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(questionImages) { image in
                                    QBankImageFrame(image: image, maxHeight: maxImageHeight)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alternativas")
                            .font(PixioTypo.sectionLabel)
                            .foregroundStyle(VitaColors.sectionLabel)

                        ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                            QBankAlternativeCard(
                                idx: idx,
                                alternative: alt,
                                images: alternativeImagesById[alt.id] ?? [],
                                selectedId: vm.state.selectedAlternativeId,
                                showFeedback: vm.state.showFeedback
                            ) {
                                PixioHaptics.tap()
                                vm.selectAlternative(id: alt.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if vm.state.showFeedback, let explanation = question.explanation, !explanation.isEmpty {
                        QBankExplanationPanel(explanation: explanation.qbankPlainText)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 132)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar()
        }
        .animation(.easeInOut(duration: 0.25), value: vm.state.showFeedback)
    }

    private func sessionHeader(question: QBankQuestionDetail) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VitaColors.glassBg.opacity(0.82)))
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Questão \(vm.state.progress1Based)")
                        .font(PixioTypo.sans(size: 18, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(vm.state.progress1Based) de \(vm.state.totalInSession)")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer(minLength: 8)

                QBankMetaChip(icon: "timer", text: timerStr, prominent: true)
            }

            HStack(spacing: 8) {
                if let year = question.year {
                    QBankMetaChip(icon: "calendar", text: "\(year)")
                }
                QBankMetaChip(icon: "gauge.with.dots.needle.33percent", text: question.difficulty.difficultyLabel)
                if let inst = question.institutionName, !inst.isEmpty {
                    QBankMetaChip(icon: "building.columns", text: inst)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(VitaColors.glassBorder.opacity(0.72))
                    Capsule()
                        .fill(VitaColors.goldBarGradient)
                        .frame(width: max(8, geo.size.width * CGFloat(vm.state.sessionProgress)))
                        .shadow(color: VitaColors.accent.opacity(0.35), radius: 8, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.35), value: vm.state.sessionProgress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [VitaColors.surface.opacity(0.98), VitaColors.surface.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    @ViewBuilder
    private func topicRail(question: QBankQuestionDetail) -> some View {
        if !question.topics.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(question.topics) { topic in
                        Text(topic.title)
                            .font(PixioTypo.caption)
                            .foregroundStyle(VitaColors.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .pixioFieldSurface(cornerRadius: PixioRadius.chip)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func questionBadges(question: QBankQuestionDetail) -> some View {
        let hasBadges = question.isResidence || question.isCancelled || question.isOutdated
        if hasBadges {
            HStack(spacing: 8) {
                if question.isResidence { QBankBadge(text: "Residência", color: VitaColors.dataBlue) }
                if question.isCancelled { QBankBadge(text: "Anulada", color: VitaColors.dataAmber) }
                if question.isOutdated { QBankBadge(text: "Desatualizada", color: VitaColors.textTertiary) }
            }
        }
    }

    private func bottomActionBar() -> some View {
        VStack(spacing: 10) {
            if let answerError = vm.state.answerError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.dataRed)
                    Text(answerError)
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.dataRed)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(VitaColors.dataRed.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if vm.state.showFeedback {
                HStack(spacing: 10) {
                    QBankActionButton(title: "Detalhes", style: .secondary) {
                        showExplanationSheet = true
                    }
                    QBankActionButton(
                        title: vm.state.isLastQuestion ? "Ver resultado" : "Próxima",
                        style: .primary
                    ) {
                        PixioHaptics.confirm()
                        if vm.state.isLastQuestion { vm.finishSession() } else { vm.nextQuestion() }
                    }
                }
            } else {
                QBankActionButton(
                    title: "Confirmar",
                    style: vm.state.selectedAlternativeId == nil ? .disabled : .primary
                ) {
                    vm.confirmAnswer()
                }
                .disabled(vm.state.selectedAlternativeId == nil)
            }

            Button { showFinishAlert = true } label: {
                Text("Encerrar sessão")
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [VitaColors.surface.opacity(0.58), VitaColors.surface.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                vm.tickTimer()
            }
        }
    }
}

// MARK: - Premium session pieces

private struct QBankQuestionPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixioRaised(in: RoundedRectangle(cornerRadius: PixioRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PixioRadius.card, style: .continuous)
                .stroke(VitaColors.glassHighlight, lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
}

private struct QBankMetaChip: View {
    let icon: String
    let text: String
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(PixioTypo.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .foregroundStyle(prominent ? VitaColors.accentLight : VitaColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background((prominent ? VitaColors.accent.opacity(0.14) : VitaColors.glassBg.opacity(0.72)))
        .overlay(
            Capsule()
                .stroke(prominent ? VitaColors.accent.opacity(0.30) : VitaColors.glassBorder, lineWidth: 0.75)
        )
        .clipShape(Capsule())
    }
}

private struct QBankImageFrame: View {
    let image: QBankImage
    let maxHeight: CGFloat
    var compact: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: image.imageUrl)) { phase in
                ZStack {
                    shape.fill(Color.black.opacity(0.24))

                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: maxHeight)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Imagem indisponível")
                                .font(PixioTypo.caption)
                        }
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: compact ? 120 : 180)
                    default:
                        ProgressView()
                            .tint(VitaColors.accent)
                            .frame(maxWidth: .infinity, minHeight: compact ? 120 : 180)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(shape)
                .overlay(shape.stroke(VitaColors.glassBorder, lineWidth: 0.75))
            }

            if let caption = image.caption, !caption.isEmpty {
                Text(caption)
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textTertiary)
                    .italic()
            }
        }
    }
}

private struct QBankExplanationPanel: View {
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight)
                Text("Comentário")
                    .font(PixioTypo.sectionLabel)
                    .foregroundStyle(VitaColors.sectionLabel)
            }
            Text(explanation)
                .font(PixioTypo.sans(size: 14, weight: .regular))
                .foregroundStyle(VitaColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VitaColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 0.75)
        )
    }
}

private enum QBankActionButtonStyle {
    case primary
    case secondary
    case disabled
}

private struct QBankActionButton: View {
    let title: String
    let style: QBankActionButtonStyle
    let action: () -> Void

    private var foreground: Color {
        switch style {
        case .primary: return VitaColors.surface
        case .secondary: return VitaColors.accentLight
        case .disabled: return VitaColors.surface.opacity(0.68)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PixioTypo.sans(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(background)
                .overlay(border)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VitaColors.goldBarGradient)
                .shadow(color: VitaColors.accent.opacity(0.24), radius: 12, x: 0, y: 5)
        case .secondary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VitaColors.glassBg.opacity(0.78))
        case .disabled:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VitaColors.accent.opacity(0.36))
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .primary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VitaColors.accentLight.opacity(0.18), lineWidth: 0.75)
        case .secondary:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VitaColors.accent.opacity(0.34), lineWidth: 0.9)
        case .disabled:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.clear, lineWidth: 0)
        }
    }
}

// MARK: - Alternative Card (standalone for coordinator use)

struct QBankAlternativeCard: View {
    let idx: Int
    let alternative: QBankAlternative
    let images: [QBankImage]
    let selectedId: Int?
    let showFeedback: Bool
    let onSelect: () -> Void

    private static let letters = ["A", "B", "C", "D", "E"]

    private var isSelected: Bool { selectedId == alternative.id }
    private var isCorrect: Bool { alternative.isCorrect }
    private var isWrongChoice: Bool { showFeedback && isSelected && !isCorrect }

    private var borderColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.glassBorder
    }
    private var bgColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen.opacity(0.10) }
        if isWrongChoice { return VitaColors.dataRed.opacity(0.10) }
        if isSelected { return VitaColors.accent.opacity(0.08) }
        return VitaColors.glassBg.opacity(0.76)
    }
    private var letterColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.textTertiary
    }
    private var letter: String {
        Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx + 1)"
    }

    private var accessibilityStateLabel: String {
        if showFeedback && isCorrect { return ". Resposta correta" }
        if isWrongChoice { return ". Resposta incorreta selecionada" }
        if isSelected { return ". Selecionada" }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected || (showFeedback && isCorrect) ? borderColor.opacity(0.20) : Color.white.opacity(0.06))
                        .frame(width: 28, height: 28)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor.opacity(showFeedback ? 0.45 : 0.18), lineWidth: 1)
                        .frame(width: 28, height: 28)
                    if showFeedback && isCorrect {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.dataGreen)
                    } else if isWrongChoice {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.dataRed)
                    } else {
                        Text(letter)
                            .font(PixioTypo.sans(size: 12, weight: .bold))
                            .foregroundStyle(letterColor)
                    }
                }

                Text(alternative.text.qbankPlainText)
                    .font(PixioTypo.sans(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showFeedback && (isCorrect || isWrongChoice) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isCorrect ? VitaColors.dataGreen : VitaColors.dataRed)
                }
            }

            if !images.isEmpty {
                VStack(spacing: 8) {
                    ForEach(images) { image in
                        QBankImageFrame(image: image, maxHeight: 220, compact: true)
                    }
                }
                .padding(.leading, 40)
            }
        }
        .padding(14)
        .background(bgColor)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor.opacity(showFeedback ? 0.95 : 0.62), lineWidth: 1)
            if isSelected {
                QBankSelectedAnswerHalo(color: borderColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: isSelected ? borderColor.opacity(0.15) : .clear, radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { if !showFeedback { onSelect() } }
        .animation(.easeInOut(duration: 0.2), value: showFeedback)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alternativa \(letter): \(alternative.text.qbankPlainText)\(accessibilityStateLabel)")
        .accessibilityHint(showFeedback ? "" : "Toque para selecionar esta alternativa")
        .accessibilityAddTraits(.isButton)
    }
}

private struct QBankSelectedAnswerHalo: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        .white.opacity(0.76),
                        color.opacity(0.98),
                        color.opacity(0.22),
                        .white.opacity(0.48),
                        color.opacity(0.98)
                    ],
                    center: .center,
                    angle: .degrees(pulse ? 360 : 0)
                ),
                lineWidth: 1.35
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(pulse ? 0.30 : 0.14), lineWidth: 7)
                    .blur(radius: pulse ? 10 : 5)
            )
            .shadow(color: color.opacity(pulse ? 0.34 : 0.14), radius: pulse ? 20 : 8, y: pulse ? 7 : 3)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
