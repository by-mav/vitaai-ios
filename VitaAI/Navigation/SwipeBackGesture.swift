import SwiftUI
import UIKit

// Re-enables the native iOS swipe-back gesture when the navigation bar is hidden.
// Without this, `.toolbar(.hidden, for: .navigationBar)` disables
// UINavigationController.interactivePopGestureRecognizer.

struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackHostController()
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

private final class SwipeBackHostController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableSwipeBack()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enableSwipeBack()
    }

    private func enableSwipeBack() {
        guard let nav = navigationController else { return }
        nav.interactivePopGestureRecognizer?.isEnabled = true
        nav.interactivePopGestureRecognizer?.delegate = nil
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler().frame(width: 0, height: 0))
    }
}
