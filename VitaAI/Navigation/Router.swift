import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var selectedTab: TabItem = .home

    func navigate(to route: Route) {
        path.append(route)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
