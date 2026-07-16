import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var selectedTab: TabItem = .home
    var activeScreen: Route?
    var hideShell = false
    var showPaywall = false
    /// Rota aguardando a troca de tab terminar. O MainTabView consome este
    /// valor depois de limpar a pilha antiga, evitando perder o primeiro push.
    var pendingRouteAfterTabChange: Route?

    // Shared state for flashcard session → settings screen communication
    var activeFlashcardVM: FlashcardViewModel?
    var activeFlashcardSettings: FlashcardSettings?

    /// Mirror of `path` that keeps Route values accessible (NavigationPath is type-erased).
    private(set) var routeStack: [Route] = []
    var currentPath: [Route] { routeStack }

    init() {
        // QA: `--vita-tab <home|estudos|jornada|progresso>` abre direto na aba no
        // cold launch (screenshot/QA sem depender de idb). Só afeta a aba inicial.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--vita-tab"), i + 1 < args.count {
            switch args[i + 1].lowercased() {
            case "estudos": selectedTab = .estudos
            case "jornada", "faculdade": selectedTab = .faculdade
            case "progresso": selectedTab = .progresso
            case "home": selectedTab = .home
            default: break
            }
        }
    }

    /// Sync routeStack when NavigationPath changes externally (e.g. swipe-back gesture)
    func syncStackToPath() {
        while routeStack.count > path.count {
            routeStack.removeLast()
        }
    }

    func navigate(to route: Route) {
        // Dedup: no-op if the current top of the stack is the same route.
        // Prevents breadcrumb spam like "Home > Perfil > Perfil > Perfil"
        // when the same menu item or destination is tapped repeatedly.
        if routeStack.last == route { return }
        path.append(route)
        routeStack.append(route)
    }

    /// Navigate from the global menu popout (Perfil, Configurações, Conectores, …).
    /// These destinations are conceptually modal — unrelated to whatever tab or
    /// sub-page the user was on. Reset the stack to home root first so the
    /// breadcrumb reads `Home > Perfil` instead of `Home > Flashcards > Perfil`.
    func navigateFromMenu(to route: Route) {
        popToRoot()
        selectedTab = .home
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            navigate(to: route)
        }
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
        if !routeStack.isEmpty { routeStack.removeLast() }
    }

    func replaceTop(with route: Route) {
        if !path.isEmpty {
            path.removeLast()
            if !routeStack.isEmpty { routeStack.removeLast() }
        }
        navigate(to: route)
    }

    func popToRoot() {
        path = NavigationPath()
        routeStack.removeAll()
    }

    /// Navigate from a notification route string (e.g. "/study/grades", "/study/flashcards", "/planner")
    func navigateToRoute(_ route: String) {
        // Handle parameterized routes first
        let parts = route.split(separator: "/").map(String.init)

        // /materiais/{subjectId}/{subjectName} → discipline detail
        if parts.count >= 2 && parts[0] == "materiais" {
            let subjectId = parts[1]
            let subjectName = parts.count >= 3 ? parts[2].removingPercentEncoding ?? parts[2] : ""
            NSLog("[Router] navigateToRoute /materiais → discipline %@ (%@)", subjectId, subjectName)
            navigateToDiscipline(id: subjectId, name: subjectName)
            return
        }

        let mapping: [String: (TabItem, Route?)] = [
            "/study/grades": (.faculdade, .faculdadeMaterias),
            "/study/flashcards": (.estudos, .flashcardHome()),
            "/study/trabalhos": (.faculdade, .trabalhos),
            "/study/provas": (.faculdade, .faculdadeMaterias),
            "/materiais": (.faculdade, .faculdadeDocumentos),
            "/faculdade": (.faculdade, nil),
            "/progress": (.progresso, nil),
            "/achievements": (.progresso, .achievements),
            "/settings": (.progresso, .connections),
        ]
        if let (tab, dest) = mapping[route] {
            NSLog("[Router] navigateToRoute matched: %@ → tab=%@ route=%@", route, String(describing: tab), String(describing: dest))
            popToRoot()
            selectedTab = tab
            if let dest {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
                    navigate(to: dest)
                }
            }
        } else {
            NSLog("[Router] navigateToRoute NO MATCH for: %@", route)
        }
    }

    /// Navigate to discipline detail as a subpage of Faculdade tab
    func navigateToDiscipline(id: String, name: String) {
        popToRoot()
        selectedTab = .faculdade
        // Push after a tick so the tab switch + popToRoot settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            navigate(to: .faculdadeDisciplinas)
            navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name))
        }
    }
}
