import SwiftUI
import Sentry

/// Top-level coordinator that owns the single QBankViewModel instance and routes
/// between the home / config / session / result sub-screens based on vm.state.activeScreen.
/// This is the entry point registered in Route + AppRouter.
///
/// Sub-screens live in separate files:
///   - QBankHomeContent.swift       (home + background + hero + cards)
///   - QBankDisciplineContent.swift  (discipline tree selection)
///   - QBankConfigContent.swift      (session config: filters, difficulty, institutions)
///   - QBankSessionContent.swift     (active question + alternatives + timer)
///   - QBankResultContent.swift      (score ring + stats + review)
///   - QBankExplanationSheet.swift   (answer explanation + statistics)
///   - QBankShared.swift             (Badge, HTMLText, Chip, FlowLayout, helpers)
struct QBankCoordinatorScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: QBankViewModel?
    let onBack: () -> Void
    var onHome: (() -> Void)? = nil
    var initialSessionId: String? = nil
    var initialMode: QBankMode = .pratica

    var body: some View {
        Group {
            if let vm {
                coordinator(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
            }
        }
        .onAppear {
            if vm == nil {
                let createdVM = QBankViewModel(api: container.api, gamificationEvents: container.gamificationEvents, dataManager: container.dataManager)
                vm = createdVM
                Task {
                    if let initialSessionId {
                        await createdVM.openSession(sessionId: initialSessionId, mode: initialMode)
                    } else {
                        createdVM.loadHomeData()
                    }
                    // Filters are loaded on-demand when user navigates to disciplines/config
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .navigationBarHidden(true)
        .trackScreen("QBank")
    }

    @ViewBuilder
    private func coordinator(vm: QBankViewModel) -> some View {
        switch vm.state.activeScreen {
        case .home, .config:
            // Builder unificado (Fase 3 reescrita 2026-04-28). Substitui
            // QBankHomeContent + QBankConfigContent. Hero + Lente + Filtros
            // inline + Recents + CTA sticky.
            QBankBuilderScreen(
                onBack: onBack,
                onSessionCreated: { sessionId, mode in
                    Task { await vm.openSession(sessionId: sessionId, mode: mode) }
                }
            )

        case .topics:
            QBankTopicsContent(vm: vm, onBack: {
                vm.goBackTopics()
            })

        case .disciplines:
            QBankDisciplineContent(vm: vm, onBack: {
                vm.goBackDiscipline()
            })

        case .session:
            QBankSessionContent(vm: vm, onBack: {
                vm.goToHome()
            })

        case .result:
            QBankResultContent(vm: vm, onBack: onHome ?? onBack, onNewSession: {
                vm.startNewSession()
            })
        }
    }
}
