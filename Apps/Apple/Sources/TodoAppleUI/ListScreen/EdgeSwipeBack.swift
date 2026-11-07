// Apps/Apple/Sources/TodoAppleUI/ListScreen/EdgeSwipeBack.swift
#if os(iOS)
import SwiftUI
import UIKit

/// Keeps the swipe from the screen's left edge going back on a screen that hides its navigation bar, where UIKit turns
/// it off: on an iPhone 17 (the iOS 26.3 simulator, 2026-11-07) that swipe went back from the task screen, whose bar
/// shows, and did nothing on the list screen, whose own glass circle goes back instead. SwiftUI has no way to say so,
/// so while the screen stands on top its view controller answers for the navigation controller's recognizer, and gives
/// it back to what answered before when the screen goes, since a recognizer that answers yes on a stack's root screen
/// hangs the stack. The pop it starts is the system's, which writes the shorter path the root view sends as any pop.
struct EdgeSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        /// What answered for the recognizer before this screen came up, which the recognizer holds only weakly.
        private weak var answeredBefore: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if recognizer.delegate !== self {
                answeredBefore = recognizer.delegate
            }
            recognizer.delegate = self
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = answeredBefore
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
#endif
