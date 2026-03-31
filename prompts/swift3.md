Voce eh SWIFT-3: SAFETY e BUGS. Corrija TODOS os crashes e leaks abaixo no VitaAI iOS. Edite os arquivos diretamente.

1. ARRAY INDEX CRASHES (CRITICAL): AppContainer.swift:87 try! ModelContainer (trocar por do/catch), StrokeFileStorage.swift:25 .urls()[0] (guard let), WelcomeStep.swift:163 portals[0] (guard isEmpty), TrabalhoEditorViewModel.swift:118 assignmentTemplates[0] (guard), InkCanvasView.swift:107 points[0] (guard).

2. MEMORY LEAKS: VitaMascot.swift:454-520 loops recursivos que nunca param (adicionar isCancelled flag no onDisappear), DrawingCanvasView.swift:52-69 NotificationCenter sem removeObserver (cleanup no dismantleUIView), FlashcardSessionScreen.swift:21 Timer sem cancel (onDisappear), SimuladoSessionScreen.swift:471-483 timerTask sem cancel (onDisappear), ProvasViewModel.swift:174-195 pollTask infinito (cancellation check).

3. RACE CONDITIONS: FlashcardViewModel.swift:18 Perceptible sem MainActor (adicionar), AuthManager.swift:214-233 Task bare mutations (MainActor), QBankViewModel.swift:126-276 multiplos Task mutando state, SimuladoViewModel.swift:91-369 mesmo, AppConfigService.swift:26-27 nonisolated unsafe static var (trocar por actor).

4. FORCE UNWRAPS: AppContainer.swift:27-104 7x as! force downcast (trocar por as? com fallback).

5. SPEECH: SpeechRecognitionManager.swift:169-200 callback sem isolation (Task MainActor), VitaVoiceInput.swift:272 captura self sem weak self.

Apos cada fix, explique brevemente.
