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
                vm = QBankViewModel(api: container.api, gamificationEvents: container.gamificationEvents, dataManager: container.dataManager)
                Task {
                    vm?.loadHomeData()
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
        case .home:
            // Builder unificado — Hero + Lente + Disciplinas chips + Filtros + Recents + CTA Iniciar.
            // O antigo "Configurar Sessão" foi fundido ao Home. `.config` é alias preservado pra
            // compat (ex: navegação programática que ainda chamava goToConfig).
            ZStack {
                QBankBackground()
                QBankConfigContent(vm: vm, onBack: onBack)
            }

        case .topics:
            QBankTopicsContent(vm: vm, onBack: {
                vm.goBackTopics()
            })

        case .disciplines:
            QBankDisciplineContent(vm: vm, onBack: {
                vm.goBackDiscipline()
            })

        case .config:
            // Alias do home (mesmo conteúdo). Mantido pra rotas legadas.
            ZStack {
                QBankBackground()
                QBankConfigContent(vm: vm, onBack: onBack)
            }

        case .session:
            QBankSessionContent(vm: vm, onBack: {
                vm.goToHome()
            })

        case .result:
            QBankResultContent(vm: vm, onBack: onBack, onNewSession: {
                vm.startNewSession()
            })
        }
    }
}
