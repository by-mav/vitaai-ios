import SwiftUI
import UserNotifications

// MARK: - VitaOnboarding — Full onboarding flow coordinator
// Steps (Onda 5b): Sleep -> StatusFaculdade -> Goal -> [RevalidaStage|Welcome] -> Connect -> Syncing -> Subjects -> Notifications -> Trial -> Done
// Fork por journeyType (FACULDADE/INTERNATO/ENAMED/RESIDENCIA/REVALIDA). SOT: agent-brain/decisions/2026-04-27_jornada-3lentes-FINAL.md

struct VitaOnboarding: View {
    @Environment(\.appContainer) private var container
    // Persist current step so if the app restarts mid-onboarding the user
    // resumes where they stopped instead of going back to the sleep intro.
    @AppStorage("vita_onboarding_last_step_v2") private var lastStepRaw: Int = OnboardingStep.sleep.rawValue
    @State private var step: OnboardingStep = .sleep
    @State private var mascotState: VitaMascotState = .sleeping
    @State private var viewModel: OnboardingViewModel?
    @State private var speechText = ""
    @State private var showContent = false
    @State private var isTyping = false
    @State private var sleepOpacity: Double = 1.0
    @State private var wakeFlash: Double = 0
    @State private var mascotScale: CGFloat = 1.0
    // Vita "envergonhada" — bochechas vermelhas durante o "Oiii, não tinha
    // te visto aí" logo após acordar. Disparado pelo wakeUp(). Rafael 2026-04-28.
    @State private var mascotBlushing: Bool = false
    @State private var showManualEntry = false
    @State private var typeTextId: UUID = UUID()
    @State private var wakeSequenceId: UUID = UUID()
    @State private var isWakeReaction = false
    // WhatsApp quick-link sheet, used by the ExtrasStep.
    @State private var showExtrasWAsheet = false
    @State private var waPhone = ""
    @State private var waCode = ""
    @State private var waStep = 0
    @State private var waSending = false
    @State private var waError: String?
    var userName: String = ""
    var onLogout: (() -> Void)?
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            VitaColors.surface
                .ignoresSafeArea()

            // Enhanced starfield with nebula
            OnboardingStarfieldLayer()
                .ignoresSafeArea()

            // Wake flash overlay
            if wakeFlash > 0 {
                Color.white.opacity(wakeFlash * 0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Top bar (progress dots + back/logout button)
                if step != .sleep || onLogout != nil {
                    ZStack {
                        // Back button: left
                        HStack {
                            if step != .sleep {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    goBack()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold)) // ds-allow: canonical Vita back chevron
                                        .foregroundStyle(VitaColors.textPrimary)
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "onboarding_a11y_back"))
                                .accessibilityIdentifier("onboardingBackButton")
                            }
                            Spacer()
                            if let onLogout {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onLogout()
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white.opacity(0.04))
                                        .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                                        .clipShape(Circle())
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Sair")
                            }
                        }
                        // Sleep is level 1. Waking Vita advances to level 2, so both
                        // the progress indicator and Back navigation include it.
                        let visibleSteps = OnboardingStep.allCases.filter { !shouldSkipStep($0) }
                        let currentIndex = visibleSteps.firstIndex(of: step) ?? 0
                        OnboardingProgressDots(currentStep: currentIndex, totalDots: visibleSteps.count)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }

                // Later steps retain the established centered mascot. The first
                // conversation levels use the compact side-by-side composition.
                let shrinkForSearch = step == .welcome
                    && !(viewModel?.universityQuery.isEmpty ?? true)
                    && viewModel?.selectedUniversity == nil
                // Onda 5b refined: status precisa de mais espaço pras 3 opções
                // de fase + speech bubble grande não cortar a 3ª opção.
                let shrinkForCompactStep = step == .statusFaculdade
                let mascotSize: CGFloat = {
                    if step == .sleep { return 120 }
                    if shrinkForSearch { return 44 }
                    if shrinkForCompactStep { return 72 }
                    return 100
                }()

                if step == .sleep {
                    VitaMascot(
                        state: mascotState,
                        size: mascotSize,
                        isBlushing: mascotBlushing
                    )
                    .scaleEffect(mascotScale)
                    .padding(.top, 60)
                    .padding(.bottom, VitaTokens.Spacing.sm)
                    .overlay(alignment: .center) {
                        if mascotState == .sleeping {
                            OnboardingSleepingZs()
                                .offset(x: mascotSize * 0.38, y: -mascotSize * 0.34)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if mascotState == .sleeping {
                            OnboardingDreamThoughts()
                                .offset(x: 98, y: -66)
                                .allowsHitTesting(false)
                        }
                    }
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        wakeUp()
                    }
                } else if step != .introduction && step != .statusFaculdade {
                    VitaMascot(
                        state: mascotState,
                        size: mascotSize,
                        isBlushing: mascotBlushing
                    )
                    .scaleEffect(mascotScale)
                    .padding(.top, shrinkForSearch ? 0 : 16)
                    .padding(.bottom, shrinkForSearch ? 0 : 8)
                    .animation(.easeInOut(duration: 0.25), value: shrinkForSearch)
                }

                // Speech bubble + content
                if step == .sleep {
                    SleepStep(onWake: wakeUp)
                        .padding(.top, VitaTokens.Spacing.lg)
                    Spacer(minLength: VitaTokens.Spacing._4xl)
                } else {
                    // Onda 5b refined (Rafael 2026-04-28): scroll indicator
                    // visível pra avisar quando tem conteúdo abaixo do botão
                    // Continuar (caso típico: Welcome com semester picker logo
                    // após escolher faculdade — sem indicador o user não vê).
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            if !speechText.isEmpty {
                                if step == .introduction || step == .statusFaculdade {
                                    OnboardingSpeechBubble(
                                        text: speechText,
                                        isTyping: isTyping,
                                        isReaction: isWakeReaction
                                    )
                                    .padding(.leading, 48)
                                    .overlay(alignment: .bottomLeading) {
                                        VitaMascot(
                                            state: mascotState,
                                            size: 64,
                                            idleEnabled: true,
                                            isBlushing: mascotBlushing
                                        )
                                        .scaleEffect(mascotScale)
                                        .offset(x: -68, y: 62)
                                    }
                                    .layoutPriority(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, VitaTokens.Spacing.lg)
                                    .padding(.top, VitaTokens.Spacing._3xl)
                                    .padding(.bottom, VitaTokens.Spacing.xl)
                                } else {
                                    OnboardingSpeechBubble(text: speechText, isTyping: isTyping)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 16)
                                }
                            }

                            if showContent && step != .introduction {
                                stepContent
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }

                    Spacer()

                    if showContent && step == .introduction {
                        stepContent
                            .padding(.horizontal, VitaTokens.Spacing._2xl)
                            .padding(.bottom, VitaTokens.Spacing.md)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    bottomButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
        .animation(.easeInOut(duration: 0.3), value: showContent)
        // vita-modals-ignore: onboarding multi-step sheet (ManualUniversitySheet)
        .sheet(isPresented: $showManualEntry) {
            ManualUniversitySheet { name, city, state in
                showManualEntry = false
                Task {
                    do {
                        try await container.api.requestUniversity(name: name, city: city, state: state)
                        await MainActor.run {
                            mascotState = .happy
                            typeText(String(localized: "onboarding_uni_request_sent"))
                        }
                    } catch {
                        print("[Onboarding] University request failed: \(error)")
                    }
                }
            }
        }
        // vita-modals-ignore: WhatsApp link sheet multi-step no onboarding
        .sheet(isPresented: $showExtrasWAsheet) {
            OnboardingWhatsAppLinkSheet(
                phone: $waPhone,
                code: $waCode,
                stepIndex: $waStep,
                sending: $waSending,
                error: $waError,
                onSendCode: sendWACode,
                onVerify: verifyWACode,
                onClose: { showExtrasWAsheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(tokenStore: container.tokenStore, api: container.api)
                Task { await viewModel?.loadUniversities() }
            }
            // Onda 5b — migracao AppStorage v1 -> v2 (Rafael 2026-04-27).
            // Enum mudou: sleep=0, statusFaculdade=1, goal=2, revalidaStage=3, welcome=4...
            // Antes: sleep=0, welcome=1, connect=2, extras=3, syncing=4, subjects=5...
            // Mapeamento: legacy >= 1 -> v2 = legacy + 3. Roda 1x se v2 ainda no default.
            if lastStepRaw == OnboardingStep.sleep.rawValue {
                let legacyDefaults = UserDefaults.standard
                let legacyKey = "vita_onboarding_last_step"
                let legacyValue = legacyDefaults.integer(forKey: legacyKey)
                if legacyValue >= 1 && legacyValue <= 8 {
                    let migrated = legacyValue + 3
                    lastStepRaw = migrated
                    print("[Onboarding] Migrated AppStorage v1=\(legacyValue) -> v2=\(migrated)")
                }
                legacyDefaults.removeObject(forKey: legacyKey)
            }
            if let saved = OnboardingStep(rawValue: lastStepRaw),
               saved != .sleep,
               saved != .done {
                step = saved
                mascotState = .awake
                if saved == .introduction {
                    speechText = String(localized: "onboarding_intro_message")
                    isTyping = false
                    showContent = true
                } else if saved == .statusFaculdade {
                    speechText = String(localized: "onboarding_status_speech")
                    isTyping = false
                    showContent = true
                } else {
                    showContent = true
                }
            }
        }
        .onChange(of: step) { newStep in
            // Persist every transition so a mid-flow restart resumes exactly here.
            lastStepRaw = newStep.rawValue
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .sleep:
            EmptyView()

        case .introduction:
            if let vm = viewModel {
                IntroductionNameStep(viewModel: vm) {
                    guard vm.nickname.filter({ $0.isLetter }).count >= 3 else { return }
                    nextStep()
                }
            }

        case .statusFaculdade:
            if let vm = viewModel {
                StatusFaculdadeStep(viewModel: vm)
            }

        case .goal:
            if let vm = viewModel {
                GoalStep(viewModel: vm)
            }

        case .revalidaStage:
            if let vm = viewModel {
                RevalidaStageStep(viewModel: vm)
            }

        case .residenciaSpecialty:
            if let vm = viewModel {
                ResidenciaSpecialtyStep(viewModel: vm, api: container.api)
            }

        case .welcome:
            if let vm = viewModel {
                WelcomeStep(viewModel: vm, showManualEntry: $showManualEntry)
            }

        case .connect:
            ConnectStep(
                university: viewModel?.selectedUniversity,
                allPortalTypes: viewModel?.allPortalTypes ?? [],
                api: container.api
            )

        case .extras:
            ExtrasStep(
                api: container.api,
                onConnectWhatsApp: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    waStep = 0; waPhone = ""; waCode = ""; waError = nil
                    showExtrasWAsheet = true
                },
                onConnectIntegration: { provider in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        // Kicks off OAuth; ConnectorsScreen will show the
                        // result when the user lands on it post-onboarding.
                        _ = try? await container.api.startIntegrationOAuth(provider)
                    }
                }
            )

        case .syncing:
            if let vm = viewModel {
                SyncingStep(api: container.api, viewModel: vm)
            }

        case .subjects:
            if let vm = viewModel {
                SubjectsStep(viewModel: vm)
            }

        case .notifications:
            NotificationsStep()

        case .trial:
            TrialStep()

        case .done:
            if let vm = viewModel {
                DoneStep(userName: userName, viewModel: vm)
            }
        }
    }

    // MARK: - Bottom Button

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

            if step == .welcome || step == .connect || step == .extras || step == .subjects {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nextStep()
                }) {
                    Text(String(localized: "onboarding_btn_skip"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Onda 5b: gating para o bottom button. Cada step tem regra propria.
    private var isContinueDisabled: Bool {
        guard let vm = viewModel else { return true }
        switch step {
        case .introduction:
            return vm.nickname.filter({ $0.isLetter }).count < 3
        case .statusFaculdade:
            // Onda 5b refined: agora 3 fases macro. Continuar libera assim que
            // o usuário escolhe uma das 3 (vestibulando/graduando/residencia).
            return vm.academicPhase == nil
        case .goal:
            return vm.selectedGoal == nil
        case .revalidaStage:
            return vm.revalidaStage == nil
        case .residenciaSpecialty:
            return vm.targetSpecialtySlug == nil
        case .welcome:
            // Onda 5b: agora exige faculdade + semestre nesta tela só.
            return vm.selectedUniversity == nil || vm.selectedSemester < 1
        default:
            return false
        }
    }

    private var buttonText: String {
        switch step {
        case .sleep: return ""
        case .introduction:
            let nickname = viewModel?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !nickname.isEmpty else {
                return String(localized: "onboarding_intro_name_cta")
            }
            return String(localized: "onboarding_intro_name_cta_named")
                .replacingOccurrences(of: "%@", with: nickname)
        case .statusFaculdade: return String(localized: "onboarding_btn_continue")
        case .goal: return String(localized: "onboarding_btn_continue")
        case .revalidaStage: return String(localized: "onboarding_btn_continue")
        case .residenciaSpecialty: return String(localized: "onboarding_btn_continue")
        case .welcome: return String(localized: "onboarding_btn_continue")
        case .connect: return String(localized: "onboarding_btn_continue")
        case .extras: return String(localized: "onboarding_btn_continue")
        case .syncing: return String(localized: "onboarding_btn_continue")
        case .subjects: return String(localized: "onboarding_btn_continue")
        case .notifications: return String(localized: "onboarding_btn_notifications")
        case .trial: return String(localized: "onboarding_btn_trial")
        case .done: return String(localized: "onboarding_btn_done")
        }
    }

    // MARK: - Actions

    private func goBack() {
        guard step != .sleep else { return }
        showContent = false
        wakeSequenceId = UUID()
        typeTextId = UUID()
        isTyping = false
        isWakeReaction = false

        if step == .introduction {
            speechText = ""
            mascotBlushing = false
            withAnimation(.spring(response: 0.4)) {
                step = .sleep
                mascotState = .sleeping
                mascotScale = 1.0
                wakeFlash = 0
            }
            return
        }

        if step == .statusFaculdade {
            speechText = String(localized: "onboarding_intro_message")
            mascotBlushing = false
            withAnimation(.spring(response: 0.4)) {
                step = .introduction
                mascotState = .happy
                mascotScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation { showContent = true }
            }
            return
        }

        // Onda 5b refined: pra Graduando o Goal vem POSPOSTO depois de subjects.
        // Espelha a ordem do nextStep: welcome → status, goal → subjects,
        // notifications → goal.
        let isGraduando = viewModel?.academicPhase == .graduando
        var prevRaw = step.rawValue - 1
        if isGraduando && step == .welcome {
            prevRaw = OnboardingStep.statusFaculdade.rawValue
        } else if isGraduando && step == .goal {
            prevRaw = OnboardingStep.subjects.rawValue
        } else if isGraduando && step == .notifications {
            prevRaw = OnboardingStep.goal.rawValue
        }

        // Respect smart-skip: skip back past steps that should be skipped
        while prevRaw > 1, let candidate = OnboardingStep(rawValue: prevRaw), shouldSkipStep(candidate) {
            prevRaw -= 1
        }
        if let prev = OnboardingStep(rawValue: prevRaw) {
            withAnimation(.spring(response: 0.4)) {
                step = prev
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { showContent = true }
            }
        }
    }


    private func handleBottomButton() {
        switch step {
        case .notifications:
            requestNotificationPermission()
            nextStep()
        case .done:
            withAnimation(.easeIn(duration: 0.5)) {
                mascotScale = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onComplete()
            }
        default:
            nextStep()
        }
    }

    /// Smart skip: if current step has no useful content, jump to next meaningful step
    private func shouldSkipStep(_ step: OnboardingStep) -> Bool {
        guard let vm = viewModel else { return false }
        switch step {
        case .revalidaStage:
            // Onda 5b: so aparece se goal=REVALIDA
            return vm.selectedGoal != .revalida
        case .residenciaSpecialty:
            // Onda 5b Slice 4: so aparece se goal=RESIDENCIA
            return vm.selectedGoal != .residencia
        case .welcome:
            // Onda 5b: universidade so faz sentido se inFaculdade=yes
            return vm.inFaculdade != .yes
        case .connect:
            return vm.inFaculdade != .yes
        case .syncing:
            return vm.activeSyncId == nil
        case .subjects:
            return vm.syncedSubjects.isEmpty
        default:
            return false
        }
    }

    private func wakeUp() {
        guard step == .sleep, mascotState == .sleeping else { return }
        let sequenceId = UUID()
        wakeSequenceId = sequenceId
        typeTextId = UUID()
        speechText = ""
        showContent = false
        isTyping = false
        isWakeReaction = false

        // Phase 1: Mascot grows slightly
        withAnimation(.spring(response: 0.26, dampingFraction: 0.62)) {
            mascotScale = 1.10
            mascotState = .waking
        }

        // Phase 2: Flash + mascot awake
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            guard wakeSequenceId == sequenceId, step == .sleep else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                wakeFlash = 1.0
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                mascotState = .awake
            }
        }

        // Phase 3: Flash fades, mascot settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            guard wakeSequenceId == sequenceId else { return }
            withAnimation(.easeOut(duration: 0.34)) {
                wakeFlash = 0
                mascotScale = 1.0
            }
        }

        // Phase 4: Transition to first real step (status — Onda 5b). A Vita
        // entra envergonhada: bochechas acendem por ~2.5s enquanto fala
        // "Oiii, não tinha te visto aí". Rafael 2026-04-28.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard wakeSequenceId == sequenceId, step == .sleep else { return }
            withAnimation {
                step = .introduction
                mascotState = .happy
                mascotBlushing = true
                isWakeReaction = true
            }
            speechText = String(localized: "onboarding_intro_reaction")
            // Bochechas mantêm cor por 2.5s e voltam ao normal.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    mascotBlushing = false
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.82) {
            guard wakeSequenceId == sequenceId, step == .introduction else { return }
            isWakeReaction = false
            typeText(String(localized: "onboarding_intro_message")) {
                guard wakeSequenceId == sequenceId, step == .introduction else { return }
                withAnimation { showContent = true }
            }
        }
    }

    private func nextStep() {
        showContent = false

        // Onda 5b refined (Rafael 2026-04-28): pra Graduando, Welcome+Connect
        // vêm DIRETO depois do Status. Goal de longo prazo é perguntado só
        // depois da sincronização (subjects → goal). Pra Vestibulando/Residência
        // continua o fluxo padrão (status → goal → ...).
        let isGraduando = viewModel?.academicPhase == .graduando
        var nextRaw = step.rawValue + 1

        if step == .introduction {
            nextRaw = OnboardingStep.statusFaculdade.rawValue
        } else if isGraduando && step == .statusFaculdade {
            // Status → pula Goal e Revalida → cai em Welcome (faculdade+sem).
            nextRaw = OnboardingStep.welcome.rawValue
        } else if isGraduando && step == .subjects {
            // Subjects → Goal (depois dos conectores estarem montados).
            nextRaw = OnboardingStep.goal.rawValue
        } else if isGraduando && step == .goal {
            // Após Goal (já no fim, pós-conectores) → segue pra notifications.
            nextRaw = OnboardingStep.notifications.rawValue
        }

        // Smart skip: jump past steps that have no content
        while let candidate = OnboardingStep(rawValue: nextRaw), shouldSkipStep(candidate) {
            nextRaw += 1
        }

        guard let next = OnboardingStep(rawValue: nextRaw) else {
            onComplete()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4)) {
                step = next
            }

            switch next {
            case .introduction:
                mascotState = .happy
                typeText(String(localized: "onboarding_intro_message"))

            case .statusFaculdade:
                mascotState = .happy
                typeText(String(localized: "onboarding_status_speech"))

            case .goal:
                mascotState = .happy
                typeText(String(localized: "onboarding_goal_speech"))

            case .revalidaStage:
                mascotState = .happy
                typeText(String(localized: "onboarding_revalida_speech"))

            case .residenciaSpecialty:
                mascotState = .happy
                typeText(String(localized: "onboarding_residencia_speech"))

            case .welcome:
                mascotState = .happy
                let firstName = userName.split(separator: " ").first.map(String.init) ?? ""
                typeText(firstName.isEmpty ? String(localized: "onboarding_welcome_speech") : String(localized: "onboarding_welcome_speech_name").replacingOccurrences(of: "%@", with: firstName))

            case .connect:
                mascotState = .happy
                let uniName = viewModel?.selectedUniversity?.shortName ?? "tua faculdade"
                typeText("\(uniName)! Pra poder te ajudar, conecta teu portal de ensino que eu puxo tudo automaticamente!")

            case .syncing:
                mascotState = .thinking
                let uniName = viewModel?.selectedUniversity?.shortName ?? "tua faculdade"
                typeText(String(localized: "onboarding_syncing_speech").replacingOccurrences(of: "%@", with: uniName))

            case .subjects:
                mascotState = .awake
                typeText(String(localized: "onboarding_subjects_speech"))

            case .notifications:
                mascotState = .happy
                typeText(String(localized: "onboarding_notifications_speech"))

            case .trial:
                mascotState = .happy
                typeText(String(localized: "onboarding_trial_speech"))

            case .done:
                mascotState = .happy
                let first = userName.split(separator: " ").first.map(String.init) ?? ""
                typeText(first.isEmpty ? String(localized: "onboarding_done_speech") : String(localized: "onboarding_done_speech_name").replacingOccurrences(of: "%@", with: first))
                Task { await saveOnboarding() }

            default:
                break
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { showContent = true }
            }
        }
    }

    private func typeText(_ text: String, completion: (() -> Void)? = nil) {
        let currentId = UUID()
        typeTextId = currentId
        speechText = ""
        isTyping = true
        guard !text.isEmpty else {
            isTyping = false
            completion?()
            return
        }
        for (index, char) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.018) {
                guard self.typeTextId == currentId else { return }
                speechText += String(char)
                if index == text.count - 1 {
                    isTyping = false
                    completion?()
                }
            }
        }
    }

    private func saveOnboarding() async {
        guard let vm = viewModel else { return }
        await vm.complete()
        AppConfig.setOnboardingComplete(true)
        // Onboarding finished — clear the resume marker so a future fresh login
        // (or an account reset) starts from .sleep again.
        lastStepRaw = OnboardingStep.sleep.rawValue
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - WhatsApp sheet actions (used by ExtrasStep)

    private func sendWACode() {
        Task {
            await MainActor.run { waSending = true; waError = nil }
            do {
                try await container.api.linkWhatsApp(phone: waPhone)
                await MainActor.run { waStep = 1; waSending = false }
            } catch {
                await MainActor.run { waError = "Erro ao enviar código"; waSending = false }
            }
        }
    }

    private func verifyWACode() {
        Task {
            await MainActor.run { waSending = true; waError = nil }
            do {
                _ = try await container.api.verifyWhatsApp(code: waCode)
                await MainActor.run { waStep = 2; waSending = false }
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { showExtrasWAsheet = false }
            } catch {
                await MainActor.run { waError = "Código inválido ou expirado"; waSending = false }
            }
        }
    }
}

// Cascade of 3 Z's drifting up+fading right above the mascot's head —
// classic sleeping cartoon vibe. Only shown while it's actually asleep.
