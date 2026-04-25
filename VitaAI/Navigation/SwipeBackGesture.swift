import SwiftUI

// Pure-SwiftUI swipe-back: edge-pan DragGesture that pops the router path.
//
// Why this approach (not interactivePopGestureRecognizer):
// In iOS 17+ NavigationStack the system gesture stops working reliably
// once the nav bar is hidden — even with a custom gesture delegate the
// underlying UINavigationController can be unreachable from a background
// representable. Going SwiftUI-native sidesteps the whole UIKit path:
// any drag that starts on the leading edge and travels right pops the
// top route via Router.goBack().
//
// Setup: applied once on the NavigationStack content in AppRouter.

extension View {
    /// Edge-pan swipe-back. Drag that starts within `edgeWidth` pt of the
    /// leading edge and travels right past `threshold` pt pops the route.
    func enableSwipeBack(
        router: Router,
        edgeWidth: CGFloat = 30,
        threshold: CGFloat = 80
    ) -> some View {
        modifier(SwipeBackModifier(router: router, edgeWidth: edgeWidth, threshold: threshold))
    }
}

private struct SwipeBackModifier: ViewModifier {
    let router: Router
    let edgeWidth: CGFloat
    let threshold: CGFloat

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onEnded { value in
                        guard !router.path.isEmpty else { return }
                        let startedOnEdge = value.startLocation.x < edgeWidth
                        let movedRight = value.translation.width > threshold
                        let mostlyHorizontal = value.translation.width > abs(value.translation.height) * 1.5
                        if startedOnEdge && movedRight && mostlyHorizontal {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            router.goBack()
                        }
                    }
            )
    }
}
