import SwiftUI
import UIKit

// MARK: - Re-enable native interactive pop gesture when nav bar is hidden

/// When `.navigationBarHidden(true)` is set, UIKit disables the interactivePopGestureRecognizer.
/// This representable re-enables it so the native edge-swipe back works smoothly.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackController {
        SwipeBackController()
    }
    func updateUIViewController(_ uiViewController: SwipeBackController, context: Context) {}
}

final class SwipeBackController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Walk up to find the UINavigationController and re-enable the gesture
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    /// Ensures native iOS swipe-back gesture works even when the navigation bar is hidden.
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}
