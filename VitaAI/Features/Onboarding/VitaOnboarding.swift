import SwiftUI
import UserNotifications

private enum WakePresentationPhase {
    case sleeping
    case startled
    case dismissingReaction
    case movingToIntroduction
}

struct VitaOnboarding: View {
    @Environment(\.appContainer) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var mascotSpeechNamespace

    // v3 intentionally does not migrate old raw values. A stale v1/v2 marker
    // must never skip a fresh user into a later screen.
    @AppStorage("vita_onboarding_last_step_v3")
    private var lastStepRaw = OnboardingStep.sleep.rawValue

    @State private var step: OnboardingStep = .sleep
    @State private var mascotState: VitaMascotState = .sleeping
    @State private var viewModel: OnboardingViewModel?
    @State private var speechText = ""
    @State private var speechTargetText = ""
    @State private var speechBubbleVisible = false
    @State private var isMovingMascotToSpeech = false
    @State private var wakePresentationPhase: WakePresentationPhase = .sleeping
    @State private var showContent = false
    @State private var isTyping = false
    @State private var wakeFlash: Double = 0
    @State private var mascotScale: CGFloat = 1
    @State private var mascotBlushing = false
    @State private var showManualEntry = false
    @State private var typeTextID = UUID()
    @State private var wakeSequenceID = UUID()
    @State private var isWakeReaction = false
    @State private var showExtrasWASheet = false
    @State private var waPhone = ""
    @State private var waCode = ""
    @State private var waStep = 0
    @State private var waSending = false
    @State private var waError: String?
    @State private var isKeyboardVisible = false

    var userName: String = ""
    var onLogout: (() -> Void)?
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()
            OnboardingStarfieldLayer().ignoresSafeArea()

            if wakeFlash > 0 {
                Color.white
                    .opacity(wakeFlash * 0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                topBar

                if step == .sleep {
                    sleepLayout
                } else {
                    conversationLayout
                }
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.84), value: step)
        .animation(.easeInOut(duration: 0.22), value: showContent)
        .sheet(isPresented: $showManualEntry) {
            ManualUniversitySheet { name, city, state in
                showManualEntry = false
                Task {
                    do {
                        try await container.api.requestUniversity(name: name, city: city, state: state)
                        await MainActor.run {
                            mascotState = .happy
                            presentMessage(String(localized: "onboarding_uni_request_sent"))
                        }
                    } catch {
                        print("[Onboarding] University request failed: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showExtrasWASheet) {
            OnboardingWhatsAppLinkSheet(
                phone: $waPhone,
                code: $waCode,
                stepIndex: $waStep,
                sending: $waSending,
                error: $waError,
                onSendCode: sendWACode,
                onVerify: verifyWACode,
                onClose: { showExtrasWASheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear(perform: prepareOnboarding)
        .onChange(of: step) { newStep in
            lastStepRaw = newStep.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = false }
        }
    }

    // MARK: - Fixed shell

    private var topBar: some View {
        ZStack {
            HStack {
                if step != .sleep {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "onboarding_a11y_back"))
                    .accessibilityIdentifier("onboardingBackButton")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                if let onLogout {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onLogout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(VitaTypography.labelLarge)
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(VitaColors.glassBg)
                            .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
                            .clipShape(Circle())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "onboarding_a11y_logout"))
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }

            OnboardingProgressDots(currentStep: progressIndex, totalDots: 7)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.top, VitaTokens.Spacing.sm)
        .frame(height: 58)
    }

    private var sleepLayout: some View {
        VStack(spacing: 0) {
            VitaMascot(
                state: mascotState,
                size: 120,
                isBlushing: mascotBlushing,
                showsOrbit: false
            )
            .scaleEffect(mascotScale)
            .padding(.top, 60)
            .padding(.bottom, VitaTokens.Spacing.sm)
            .overlay(alignment: .center) {
                if mascotState == .sleeping {
                    OnboardingSleepingZs()
                        .offset(x: 46, y: -41)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if wakePresentationPhase == .startled
                    || wakePresentationPhase == .dismissingReaction {
                    let reaction = String(localized: "onboarding_intro_reaction")
                    OnboardingSpeechBubble(
                        text: reaction,
                        reservedText: reaction,
                        isReaction: true
                    )
                    .frame(width: 244)
                    .opacity(wakePresentationPhase == .startled ? 1 : 0)
                    .scaleEffect(
                        wakePresentationPhase == .startled ? 1 : 0.96,
                        anchor: .bottomLeading
                    )
                    .offset(x: VitaTokens.Spacing._3xl, y: VitaTokens.Spacing._2xl)
                    .allowsHitTesting(false)
                }
            }
            .matchedGeometryEffect(
                id: "onboarding-speaking-mascot",
                in: mascotSpeechNamespace,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                wakeUp()
            }

            if wakePresentationPhase == .sleeping {
                SleepStep(onWake: wakeUp)
                    .padding(.top, VitaTokens.Spacing.lg)
                    .transition(.opacity)
            }

            Spacer(minLength: VitaTokens.Spacing._4xl)
        }
        .overlay(alignment: .topTrailing) {
            if mascotState == .sleeping {
                OnboardingDreamThoughts()
                    .padding(.top, 82)
                    .padding(.trailing, VitaTokens.Spacing.lg)
                    .allowsHitTesting(false)
            }
        }
    }

    private var conversationLayout: some View {
        VStack(spacing: 0) {
            if !isKeyboardVisible && (isMovingMascotToSpeech || !speechTargetText.isEmpty) {
                OnboardingVitaSpeech(
                    text: speechText,
                    reservedText: speechTargetText,
                    mascotNamespace: mascotSpeechNamespace,
                    usesWakeTransition: isMovingMascotToSpeech,
                    showsBubble: speechBubbleVisible,
                    isTyping: isTyping,
                    isReaction: isWakeReaction,
                    mascotState: mascotState,
                    mascotScale: mascotScale,
                    mascotBlushing: mascotBlushing
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.top, VitaTokens.Spacing._4xl)
                .padding(.bottom, VitaTokens.Spacing.md)
                .accessibilityIdentifier("onboardingConversation")
            }

            contentRegion

            bottomButton
                .padding(.horizontal, VitaTokens.Spacing._2xl)
                .padding(.top, VitaTokens.Spacing.md)
                .padding(.bottom, VitaTokens.Spacing._3xl)
        }
    }

    @ViewBuilder
    private var contentRegion: some View {
        if step == .introduction {
            VStack(spacing: 0) {
                Spacer(minLength: VitaTokens.Spacing.lg)
                if showContent {
                    stepContent
                        .padding(.horizontal, VitaTokens.Spacing._2xl)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
        } else if step == .phaseResponse {
            Spacer(minLength: VitaTokens.Spacing.lg)
        } else {
            ScrollView(showsIndicators: true) {
                if showContent {
                    stepContent
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                        .padding(.top, VitaTokens.Spacing.sm)
                        .padding(.bottom, VitaTokens.Spacing.lg)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .sleep, .phaseResponse:
            EmptyView()

        case .introduction:
            if let viewModel {
                IntroductionNameStep(viewModel: viewModel) {
                    guard viewModel.nickname.filter(\.isLetter).count >= 3 else { return }
                    nextStep()
                }
            }

        case .statusFaculdade:
            if let viewModel {
                StatusFaculdadeStep(viewModel: viewModel)
            }

        case .goal:
            if let viewModel {
                GoalStep(viewModel: viewModel)
            }

        case .revalidaStage:
            if let viewModel {
                RevalidaStageStep(viewModel: viewModel)
            }

        case .residenciaSpecialty:
            if let viewModel {
                ResidenciaSpecialtyStep(viewModel: viewModel, api: container.api)
            }

        case .welcome:
            if let viewModel {
                WelcomeStep(viewModel: viewModel, showManualEntry: $showManualEntry)
            }

        case .connect:
            ConnectStep(
                university: viewModel?.selectedUniversity,
                allPortalTypes: viewModel?.allPortalTypes ?? [],
                api: container.api,
                onConnect: { provider in
                    Task { _ = try? await container.api.startIntegrationOAuth(provider) }
                }
            )

        case .extras:
            ExtrasStep(
                api: container.api,
                onConnectWhatsApp: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    waStep = 0
                    waPhone = ""
                    waCode = ""
                    waError = nil
                    showExtrasWASheet = true
                },
                onConnectIntegration: { provider in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        _ = try? await container.api.startIntegrationOAuth(provider)
                    }
                }
            )

        case .syncing:
            if let viewModel {
                SyncingStep(api: container.api, viewModel: viewModel)
            }

        case .subjects:
            if let viewModel {
                SubjectsStep(viewModel: viewModel)
            }

        case .notifications:
            NotificationsStep()

        case .trial:
            TrialStep()

        case .done:
            if let viewModel {
                DoneStep(userName: viewModel.nickname, viewModel: viewModel)
            }
        }
    }

    private var bottomButton: some View {
        VStack(spacing: 0) {
            VitaButton(
                text: buttonText,
                action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    handleBottomButton()
                },
                variant: .primary,
                size: .md,
                isEnabled: !isContinueDisabled,
                trailingSystemImage: step == .done ? "arrow.right" : nil,
                fillsWidth: true
            )
            .accessibilityIdentifier("onboardingPrimaryButton")

            if [.welcome, .connect, .extras, .subjects].contains(step) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nextStep()
                } label: {
                    Text(String(localized: "onboarding_btn_skip"))
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VitaTokens.Spacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboardingSkipButton")
            }
        }
    }

    private var isContinueDisabled: Bool {
        guard let viewModel else { return true }
        switch step {
        case .introduction:
            return viewModel.nickname.filter(\.isLetter).count < 3
        case .statusFaculdade:
            return viewModel.academicPhase == nil
        case .goal:
            return viewModel.selectedGoal == nil
        case .revalidaStage:
            return viewModel.revalidaStage == nil
        case .residenciaSpecialty:
            return viewModel.targetSpecialtySlug == nil
        case .welcome:
            return viewModel.selectedUniversity == nil || viewModel.selectedSemester < 1
        default:
            return false
        }
    }

    private var buttonText: String {
        switch step {
        case .sleep:
            return ""
        case .introduction:
            let name = viewModel?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                return String(localized: "onboarding_intro_name_cta")
            }
            return String(localized: "onboarding_intro_name_cta_named")
                .replacingOccurrences(of: "%@", with: name)
        case .done:
            return String(localized: "onboarding_btn_done")
        case .notifications:
            return String(localized: "onboarding_btn_notifications")
        case .trial:
            return String(localized: "onboarding_btn_trial")
        default:
            return String(localized: "onboarding_btn_continue")
        }
    }

    // MARK: - Navigation

    private func prepareOnboarding() {
        if viewModel == nil {
            viewModel = OnboardingViewModel(
                tokenStore: container.tokenStore,
                api: container.api
            )
            Task { await viewModel?.loadUniversities() }
        }

        guard let saved = OnboardingStep(rawValue: lastStepRaw),
              saved != .sleep,
              saved != .done else { return }
        restoreStep(saved)
    }

    private func handleBottomButton() {
        guard !isContinueDisabled else { return }
        switch step {
        case .notifications:
            requestNotificationPermission()
            nextStep()
        case .done:
            withAnimation(.easeIn(duration: 0.4)) {
                mascotScale = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                onComplete()
            }
        default:
            nextStep()
        }
    }

    private func nextStep() {
        // A focused field must never carry its keyboard into the next screen;
        // it otherwise covers the phase choices and changes the CTA geometry.
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        guard let next = nextStep(after: step) else {
            onComplete()
            return
        }
        enterStep(next)
    }

    private func nextStep(after current: OnboardingStep) -> OnboardingStep? {
        guard let viewModel else { return nil }
        switch current {
        case .sleep: return .introduction
        case .introduction: return .statusFaculdade
        case .statusFaculdade: return .phaseResponse
        case .phaseResponse:
            switch viewModel.academicPhase {
            case .vestibulando: return .notifications
            case .graduando: return .welcome
            case .residencia: return .residenciaSpecialty
            case .professional, .other, nil: return .goal
            }
        case .goal:
            switch viewModel.selectedGoal {
            case .revalida: return .revalidaStage
            case .residencia: return .residenciaSpecialty
            case .faculdade, .enamed, nil: return .notifications
            }
        case .revalidaStage, .residenciaSpecialty:
            return .notifications
        case .welcome:
            return .connect
        case .connect:
            return .extras
        case .extras:
            if viewModel.activeSyncId != nil { return .syncing }
            if !viewModel.syncedSubjects.isEmpty { return .subjects }
            return .goal
        case .syncing:
            return viewModel.syncedSubjects.isEmpty ? .goal : .subjects
        case .subjects:
            return .goal
        case .notifications:
            return .trial
        case .trial:
            return .done
        case .done:
            return nil
        }
    }

    private func previousStep(before current: OnboardingStep) -> OnboardingStep? {
        guard let viewModel else { return nil }
        switch current {
        case .sleep: return nil
        case .introduction: return .sleep
        case .statusFaculdade: return .introduction
        case .phaseResponse: return .statusFaculdade
        case .welcome: return .phaseResponse
        case .connect: return .welcome
        case .extras: return .connect
        case .syncing: return .extras
        case .subjects: return .syncing
        case .goal:
            if viewModel.academicPhase == .graduando {
                return viewModel.syncedSubjects.isEmpty ? .extras : .subjects
            }
            return .phaseResponse
        case .revalidaStage:
            return .goal
        case .residenciaSpecialty:
            return viewModel.academicPhase == .residencia ? .phaseResponse : .goal
        case .notifications:
            if viewModel.academicPhase == .vestibulando { return .phaseResponse }
            if viewModel.selectedGoal == .revalida { return .revalidaStage }
            if viewModel.selectedGoal == .residencia { return .residenciaSpecialty }
            return .goal
        case .trial: return .notifications
        case .done: return .trial
        }
    }

    private func goBack() {
        guard let previous = previousStep(before: step) else { return }
        cancelPresentation()

        if previous == .sleep {
            speechText = ""
            speechTargetText = ""
            speechBubbleVisible = false
            isMovingMascotToSpeech = false
            mascotBlushing = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                step = .sleep
                mascotState = .sleeping
                mascotScale = 1
                wakeFlash = 0
                wakePresentationPhase = .sleeping
            }
            return
        }

        restoreStep(previous)
    }

    private func enterStep(_ next: OnboardingStep) {
        cancelPresentation()
        showContent = false
        mascotState = mascotState(for: next)

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            step = next
        }

        let message = speechMessage(for: next)
        if message.isEmpty {
            speechText = ""
            speechTargetText = ""
            speechBubbleVisible = false
            showContent = true
        } else {
            typeText(message) {
                guard step == next else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    showContent = true
                }
            }
        }

        if next == .done {
            Task { await saveOnboarding() }
        }
    }

    private func restoreStep(_ restored: OnboardingStep) {
        cancelPresentation()
        step = restored
        mascotState = mascotState(for: restored)
        let message = speechMessage(for: restored)
        speechTargetText = message
        speechText = message
        speechBubbleVisible = !message.isEmpty
        showContent = true
        isTyping = false
    }

    private func cancelPresentation() {
        typeTextID = UUID()
        wakeSequenceID = UUID()
        isTyping = false
        isWakeReaction = false
        isMovingMascotToSpeech = false
    }

    // MARK: - Copy and progress

    private func speechMessage(for destination: OnboardingStep) -> String {
        switch destination {
        case .sleep:
            return ""
        case .introduction:
            return String(localized: "onboarding_intro_message")
        case .statusFaculdade:
            let name = viewModel?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return String(localized: "onboarding_phase_prompt")
                .replacingOccurrences(of: "%@", with: name)
        case .phaseResponse:
            return viewModel?.academicPhase?.reaction ?? ""
        case .goal:
            return String(localized: "onboarding_goal_speech")
        case .revalidaStage:
            return String(localized: "onboarding_revalida_speech")
        case .residenciaSpecialty:
            return String(localized: "onboarding_residencia_speech")
        case .welcome:
            return String(localized: "onboarding_welcome_speech_name")
                .replacingOccurrences(
                    of: "%@",
                    with: viewModel?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                )
        case .connect:
            let university = viewModel?.selectedUniversity?.shortName
                ?? String(localized: "onboarding_university_fallback")
            return String(localized: "onboarding_connect_speech")
                .replacingOccurrences(of: "%@", with: university)
        case .extras:
            return String(localized: "onboarding_extras_speech")
        case .syncing:
            let university = viewModel?.selectedUniversity?.shortName
                ?? String(localized: "onboarding_university_fallback")
            return String(localized: "onboarding_syncing_speech")
                .replacingOccurrences(of: "%@", with: university)
        case .subjects:
            return String(localized: "onboarding_subjects_speech")
        case .notifications:
            return String(localized: "onboarding_notifications_speech")
        case .trial:
            return String(localized: "onboarding_trial_speech")
        case .done:
            let name = viewModel?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty
                ? String(localized: "onboarding_done_speech")
                : String(localized: "onboarding_done_speech_name")
                    .replacingOccurrences(of: "%@", with: name)
        }
    }

    private func mascotState(for destination: OnboardingStep) -> VitaMascotState {
        switch destination {
        case .syncing: return .thinking
        case .subjects: return .awake
        case .sleep: return .sleeping
        default: return .happy
        }
    }

    private var progressIndex: Int {
        switch step {
        case .sleep: return 0
        case .introduction: return 1
        case .statusFaculdade, .phaseResponse: return 2
        case .goal, .welcome, .revalidaStage, .residenciaSpecialty: return 3
        case .connect, .extras, .syncing, .subjects: return 4
        case .notifications, .trial: return 5
        case .done: return 6
        }
    }

    // MARK: - Wake choreography

    private func wakeUp() {
        guard step == .sleep, mascotState == .sleeping else { return }
        let sequenceID = UUID()
        wakeSequenceID = sequenceID
        typeTextID = UUID()
        speechText = ""
        speechTargetText = ""
        speechBubbleVisible = false
        isMovingMascotToSpeech = false
        showContent = false
        isTyping = false
        isWakeReaction = false

        withAnimation(.easeOut(duration: 0.18)) {
            mascotScale = 1.12
            mascotState = .waking
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard wakeSequenceID == sequenceID, step == .sleep else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                wakeFlash = 1
                mascotState = .awake
                wakePresentationPhase = .startled
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            guard wakeSequenceID == sequenceID, step == .sleep else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                wakeFlash = 0
                mascotScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.48) {
            guard wakeSequenceID == sequenceID, step == .sleep else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                wakePresentationPhase = .dismissingReaction
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.72) {
            guard wakeSequenceID == sequenceID, step == .sleep else { return }
            let message = String(localized: "onboarding_intro_message")
            speechTargetText = message
            speechText = ""
            speechBubbleVisible = false
            isMovingMascotToSpeech = true
            wakePresentationPhase = .movingToIntroduction
            mascotState = .happy
            mascotBlushing = true
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.48)) {
                step = .introduction
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.22) {
            guard wakeSequenceID == sequenceID, step == .introduction else { return }
            isMovingMascotToSpeech = false
            speechBubbleVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.46) {
            guard wakeSequenceID == sequenceID, step == .introduction else { return }
            typeText(String(localized: "onboarding_intro_message"), bubbleAlreadySettled: true) {
                guard wakeSequenceID == sequenceID, step == .introduction else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    showContent = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    mascotBlushing = false
                }
            }
        }
    }

    private func presentMessage(_ message: String) {
        typeText(message) {
            withAnimation(.easeOut(duration: 0.18)) {
                showContent = true
            }
        }
    }

    private func typeText(
        _ text: String,
        bubbleAlreadySettled: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let currentID = UUID()
        typeTextID = currentID
        speechTargetText = text
        speechBubbleVisible = true
        speechText = ""
        isTyping = true

        guard !text.isEmpty else {
            isTyping = false
            completion?()
            return
        }

        let typingDelay = bubbleAlreadySettled || reduceMotion ? 0 : 0.22
        if reduceMotion {
            speechText = text
            isTyping = false
            completion?()
            return
        }

        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + typingDelay + Double(index) * 0.014
            ) {
                guard typeTextID == currentID else { return }
                speechText += String(character)
                if index == text.count - 1 {
                    isTyping = false
                    completion?()
                }
            }
        }
    }

    // MARK: - Completion and permissions

    private func saveOnboarding() async {
        guard let viewModel else { return }
        await viewModel.complete()
        AppConfig.setOnboardingComplete(true)
        lastStepRaw = OnboardingStep.sleep.rawValue
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - WhatsApp

    private func sendWACode() {
        Task {
            await MainActor.run {
                waSending = true
                waError = nil
            }
            do {
                try await container.api.linkWhatsApp(phone: waPhone)
                await MainActor.run {
                    waStep = 1
                    waSending = false
                }
            } catch {
                await MainActor.run {
                    waError = String(localized: "onboarding_whatsapp_send_error")
                    waSending = false
                }
            }
        }
    }

    private func verifyWACode() {
        Task {
            await MainActor.run {
                waSending = true
                waError = nil
            }
            do {
                _ = try await container.api.verifyWhatsApp(code: waCode)
                await MainActor.run {
                    waStep = 2
                    waSending = false
                }
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    showExtrasWASheet = false
                }
            } catch {
                await MainActor.run {
                    waError = String(localized: "onboarding_whatsapp_verify_error")
                    waSending = false
                }
            }
        }
    }
}
