import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var selectedTab: TabItem = .home
    var activeScreen: Route?
    var hideShell = false
    var showPaywall = false

    /// Mirror of `path` that keeps Route values accessible (NavigationPath is type-erased).
    private(set) var routeStack: [Route] = []
    var currentPath: [Route] { routeStack }

    /// Sync routeStack when NavigationPath changes externally (e.g. swipe-back gesture)
    func syncStackToPath() {
        while routeStack.count > path.count {
            routeStack.removeLast()
        }
    }

    func navigate(to route: Route) {
        path.append(route)
        routeStack.append(route)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
        if !routeStack.isEmpty { routeStack.removeLast() }
    }

    func popToRoot() {
        path = NavigationPath()
        routeStack.removeAll()
    }

    /// Navigate to discipline detail as a subpage of Faculdade tab
    func navigateToDiscipline(id: String, name: String) {
        popToRoot()
        selectedTab = .faculdade
        // Push after a tick so the tab switch + popToRoot settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            navigate(to: .faculdadeMaterias)
            navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name))
        }
    }
}
