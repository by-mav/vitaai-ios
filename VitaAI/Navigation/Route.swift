import Foundation

enum Route: Hashable {
    case login
    case onboarding
    case home
    case estudos
    case trabalhos
    case agenda
    case insights
    case profile
    case canvasConnect
    case webalunoConnect
    case vitaChat(prompt: String? = nil)
    case notebookList
    case notebookEditor(notebookId: String)
}
