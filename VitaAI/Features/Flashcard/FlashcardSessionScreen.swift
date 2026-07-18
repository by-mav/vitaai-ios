import SwiftUI
import Combine
import Sentry

// MARK: - Flashcard Session accent colors (from flashcard-session-v1.html mockup)
// Gold accent (Vita mono-ouro; roxo do mockup v1 aposentado — Rafael 2026-07-10)
private let flashcardAccent     = VitaColors.accent

// MARK: - Flashcard Session Screen

struct FlashcardSessionScreen: View {

    let deckId: String
    var tagFilter: String? = nil
    var sessionId: String? = nil
    var onBack: () -> Void
    var onFinished: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: FlashcardViewModel?
    @State private var elapsedSeconds: Int = 0
    @State private var timerCancellable: (any Cancellable)?
    @State private var settings = FlashcardSettings()
    @State private var showEndSessionConfirmation = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common)

    var body: some View {
      GeometryReader { screenGeo in
        ZStack {
            // Background handled by shell VitaAmbientBackground — no duplicate here

            if let vm = viewModel {
                switch vm.phase {
                case .loading:
                    FlashcardLoadingSkeleton()

                case .empty:
                    emptyState

                case .studying, .reviewing:
                    studyingBody(vm: vm, screenWidth: screenGeo.size.width)

                case .finished:
                    if let result = vm.result {
                        SessionSummaryScreen(
                            deckTitle: vm.deckTitle,
                            result: result,
                            elapsedSeconds: elapsedSeconds,
                            onBack: onBack,
                            onRestart: { vm.loadDeck(deckId, tagFilter: tagFilter, sessionId: nil) }
                        )
                    }

                case .error(let msg):
                    errorState(message: msg)
                }
            } else {
                FlashcardLoadingSkeleton()
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = FlashcardViewModel(api: container.api, gamificationEvents: container.gamificationEvents)
                viewModel = vm
                Task {
                    vm.loadDeck(deckId, tagFilter: tagFilter, sessionId: sessionId)
                    SentrySDK.reportFullyDisplayed()
                }
            }
            // Share VM + settings with router so pushed settings screen can access them
            router.activeFlashcardVM = viewModel
            router.activeFlashcardSettings = settings
            timerCancellable = timer.connect()
            // Cronômetro honra o toggle "Mostrar cronômetro" da gaveta de ajustes
            // (GET /study/flashcards/settings). Sem esse fetch o default local
            // deixava o timer SEMPRE visível, ignorando a escolha do aluno.
            // Issue vitaai-web#188 (I2).
            Task {
                if let server = try? await container.api.getFlashcardSettings() {
                    settings.showTimer = server.showTimer
                }
            }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
            if let vm = viewModel {
                Task { await vm.persistSession() }
            }
        }
        .onReceive(timer) { _ in
            guard let vm = viewModel else { return }
            // Sessão terminou → congela o tempo exibido (o resumo usa o valor
            // final em vez de continuar contando na tela de summary).
            if case .finished = vm.phase { return }
            elapsedSeconds = vm.elapsedSeconds
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel != nil) {
            router.activeFlashcardVM = viewModel
            router.activeFlashcardSettings = settings
        }
        .trackScreen("FlashcardSession", extra: ["deck_id": deckId])
        .confirmationDialog(
            "Encerrar sessão?",
            isPresented: $showEndSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Encerrar sessão", role: .destructive) {
                guard let vm = viewModel else { return }
                Task {
                    await vm.endSession()
                    onBack()
                }
            }
            Button("Continuar estudando", role: .cancel) {}
        } message: {
            Text("O progresso já feito fica salvo. A sessão só deixará de aparecer na Home depois de ser encerrada.")
        }
        // Estudar = imersivo: a bottom-nav some suavemente enquanto o baralho está
        // aberto e reaparece animada ao sair (o shell anima isImmersiveMode em 0.25s).
        // Rafael 2026-07-17.
        .preference(key: ImmersivePreferenceKey.self, value: true)
      }
    }

    // MARK: Main Study Layout

    @ViewBuilder
    private func studyingBody(vm: FlashcardViewModel, screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // No TOPO: só o < grande + título (igual às outras telas). Rafael 2026-07-15.
            VitaScreenHeader(title: vm.deckTitle, onBack: onBack)

            // Vão: o resto (controle + barra + card) desce e fica agrupado embaixo.
            Spacer(minLength: 8)

            // Logo ACIMA do card: card anterior | Frente/Verso | ⋯
            controlRow(vm: vm)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            // Barra de progresso — colada logo acima do card
            sessionProgressBar(vm: vm)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if let card = vm.currentCard {
                // Card reescrito (FlashcardStudyCard): GeometryReader na própria raiz
                // trava a largura → o texto nunca vaza. Rafael 2026-07-17.
                FlashcardStudyCard(
                    front: card.front,
                    back: card.back,
                    isFlipped: vm.isFlipped,
                    onFlip: { vm.flipCard() }
                )
                // Card scene height: 380pt iPhone, 520pt iPad
                .frame(height: horizontalSizeClass == .regular ? 520 : 380)
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 16)

            ratingSection(vm: vm)
                .padding(.horizontal, 16)

            Spacer(minLength: 20)
        }
        // Ancora no topo (o ZStack pai centralizava e criava o vão acima do header).
        // Largura TRAVADA na da tela (screenWidth, medida na raiz do body ANTES de
        // qualquer inflação por conteúdo). Sem isto, `maxWidth: .infinity` deixava a
        // VStack crescer até a largura do card longo (888pt!) → card e texto saíam da
        // tela. Rafael 2026-07-17.
        .frame(width: screenWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Session Header — chevron+Voltar | title | count (purple)

    // Linha de controle sob o header: card anterior | Frente/Verso | ⋯ (Rafael 2026-07-15).
    // O voltar-grande (sair do baralho) mora no VitaScreenHeader acima.
    private func controlRow(vm: FlashcardViewModel) -> some View {
        HStack(spacing: 0) {
            // Card anterior — onde ficava o < de sair. Só aparece depois de fazer 1 card.
            if vm.canUndo {
                Button(action: { vm.undoLastRating() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.textWarm.opacity(0.70))
                        .frame(width: 44, height: 40, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Card anterior")
                .transition(.opacity)
            } else {
                Color.clear.frame(width: 44, height: 40)
            }

            Spacer()

            // Frente / Verso — centro (+ timer discreto embaixo se ligado)
            VStack(spacing: 2) {
                Text(vm.isFlipped ? "Verso" : "Frente")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                if settings.showTimer {
                    Text(formattedTimer)
                        .font(.system(size: 11, weight: .medium))  // ds-allow: timer de sessão
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        .monospacedDigit()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isFlipped)

            Spacer()

            Menu {
                Button { onOpenSettings() } label: {
                    Label("Ajustes de estudo", systemImage: "slider.horizontal.3")
                }
                Button {
                    router.navigate(to: .cardBrowser(deckId: deckId, deckTitle: vm.deckTitle))
                } label: {
                    Label("Gerenciar cards", systemImage: "square.stack.3d.up")
                }
                if vm.studySessionId != nil {
                    Button(role: .destructive) {
                        showEndSessionConfirmation = true
                    } label: {
                        Label("Encerrar sessão", systemImage: "xmark.circle")
                    }
                }
                // Editar / Mover / Excluir card entram aqui no próximo brick
                // (usam o backend PATCH/DELETE já pronto).
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .frame(width: 44, height: 40, alignment: .trailing)
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.canUndo)
    }

    // MARK: Progress Bar — 3px, rgba(255,255,255,0.06) bg, purple gradient fill

    private func sessionProgressBar(vm: FlashcardViewModel) -> some View {
        // Risquinhos: 1 por card, colorido pela resposta que o aluno deu.
        let total = max(vm.cards.count, 1)
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 999)
                    .fill(segmentColor(vm: vm, index: i))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.ratingHistory.count)
    }

    /// Cor do risquinho: resposta dada (verde/amber/vermelho) · atual (ouro) · pendente (fraco).
    private func segmentColor(vm: FlashcardViewModel, index: Int) -> Color {
        if index < vm.ratingHistory.count { return ratingColor(vm.ratingHistory[index]) }
        if index == vm.ratingHistory.count { return VitaColors.accent.opacity(0.55) }
        return Color.white.opacity(0.08)
    }

    private func ratingColor(_ r: ReviewRating) -> Color {
        switch r {
        case .again: return VitaColors.dataRed        // errei
        case .hard:  return VitaColors.dataAmber       // difícil
        case .good:  return VitaColors.accentHover     // bom (ouro, igual ao botão)
        case .easy:  return VitaColors.dataGreen       // fácil
        }
    }

    // MARK: Rating Section

    @ViewBuilder
    private func ratingSection(vm: FlashcardViewModel) -> some View {
        let isReviewing: Bool = {
            if case .reviewing = vm.phase { return true }
            return false
        }()

        if isReviewing {
            ProgressView()
                .tint(flashcardAccent)
                .frame(height: 72)
        } else if vm.isFlipped {
            RatingButtonsView(
                intervalPreviews: vm.intervalPreviews,
                showIntervals: settings.showIntervalPreview,
                onRate: { rating in vm.rateCard(rating) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            // Placeholder height so layout doesn't jump when buttons appear
            Color.clear.frame(height: 72)
        }
    }


    private var formattedTimer: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(flashcardAccent)

            VStack(spacing: 8) {
                Text("Nenhum card para revisar")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Todos os flashcards deste deck já estão em dia. Volte mais tarde!")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Voltar", action: onBack)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(flashcardAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(flashcardAccent.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(flashcardAccent.opacity(0.18), lineWidth: 1))
        }
        .padding(32)
    }

    // MARK: Error State

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Voltar", action: onBack)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(flashcardAccent)
        }
        .padding(32)
    }
}

// MARK: - Loading Skeleton

private struct FlashcardLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top bar skeleton
            HStack(spacing: 8) {
                Circle()
                    .fill(VitaColors.surfaceElevated)
                    .frame(width: 32, height: 32)
                    .shimmer()

                RoundedRectangle(cornerRadius: 2)
                    .fill(VitaColors.surfaceElevated)
                    .frame(height: 4)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(VitaColors.surfaceElevated)
                    .frame(width: 40, height: 12)
                    .shimmer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(height: 32)

            Spacer().frame(height: 20)

            // Card skeleton — 380pt per mockup .card-scene
            RoundedRectangle(cornerRadius: 22)
                .fill(VitaColors.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(VitaColors.glassBorder, lineWidth: 1))
                .frame(height: 380)
                .shimmer()
                .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            // Rating buttons skeleton
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.surfaceElevated)
                        .frame(height: 72)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)
        }
    }
}

// Uses ShimmerModifier from VitaShimmer.swift (DesignSystem/Components)
