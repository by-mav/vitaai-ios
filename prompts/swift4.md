Voce eh SWIFT-4: INFRA e QA. Corrija os problemas de infra no VitaAI iOS. Edite os arquivos diretamente.

1. NSAllowsArbitraryLoads (CRITICO - App Store rejeita): Info.plist remover NSAllowsArbitraryLoads:true. Adicionar NSExceptionDomains apenas para localhost em dev.

2. VERSAO INCONSISTENTE: Info.plist diz 1.0, project.yml diz 0.1.0. Unificar.

3. USAGE DESCRIPTIONS: Adicionar NSMicrophoneUsageDescription no Info.plist (app tem transcricao/voz). Adicionar NSCameraUsageDescription se necessario.

4. CLEANUP: Adicionar ao .gitignore os PNGs de debug na raiz (e2e-*, fast-*, debug-*, 00-*) e o diretorio build/.

5. DATEFORMATTERS: Date+Helpers.swift:15-18, FlashcardStatsView.swift:313,402,589, AgendaScreen.swift:565-566, InsightsScreen.swift:892-895 - DateFormatter recriado em computed property. Trocar todos por static let.

6. EMPTY CATCH: OnboardingViewModel.swift:107,118,127, SyncingStep.swift:227,246, ConnectionsScreen.swift:725 - catch {} vazio. Adicionar log do erro.

7. APOS TODOS OS FIXES: rodar xcodebuild -project VitaAI.xcodeproj -scheme VitaAI -sdk iphonesimulator build 2>&1 | tail -30. Reportar resultado.

Apos cada fix, explique brevemente.
