// Apps/Apple/Sources/TodoAppleUI/ListScreen/EdgeSwipeBack.swift
// iOS alone: `interactivePopGestureRecognizer` is `UINavigationController`'s, which the Mac and the watch do not have.
#if os(iOS)
import SwiftUI
import UIKit

/// Keeps the swipe from the screen's left edge going back on a screen that hides its navigation bar, where UIKit turns
/// it off: on an iPhone 17 (the iOS 26.3 simulator, 2026-11-07) that swipe went back from the task screen, whose bar
/// shows, and did nothing on the list screen, whose own glass circle goes back instead. SwiftUI has no way to say so,
/// so while the screen stands on top its view controller answers for the navigation controller's recognizer. The pop it
/// starts is the system's, which writes the shorter path the root view sends as any pop.
///
/// It gives the recognizer back to what answered before, since one that answers yes on a stack's root screen hangs the
/// stack, and it does so only if it took it: a list opened under a task by a link gets `viewWillDisappear` from a swipe
/// cancelled on the task with no `viewDidAppear` before it. The recognizer is held here and not asked of the navigation
/// controller at the end, since a glass Back drops the element and tears this controller down while the pop plays, by
/// when it may have lost its parent; so the end has two ways in, the appearance callback and the explicit dismantling.
struct EdgeSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.giveRecognizerBack()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        /// The recognizer this screen answers for while it stands on top, and nil before it first has.
        private weak var recognizer: UIGestureRecognizer?

        /// What answered for it before this screen came up, which the recognizer holds only weakly.
        private weak var answeredBefore: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer,
                  recognizer.delegate !== self
            else { return }
            answeredBefore = recognizer.delegate
            recognizer.delegate = self
            self.recognizer = recognizer
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            giveRecognizerBack()
        }

        func giveRecognizerBack() {
            guard let recognizer, recognizer.delegate === self else { return }
            recognizer.delegate = answeredBefore
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

/// A plain view placed inside a `ScrollView` that moves sideways, the board's or the tag bar's, which makes its scroll
/// wait for the system's swipe back from the screen's edge to fail, as that swipe does at once away from the edge: such
/// a scroll view took the swipe, at its start too, and it went back nowhere (the iOS 26.3 simulator, 2026-11-07). The
/// list scrolls up and down, so it has no such fight.
///
/// `BackSwipeFirst` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct BackSwipeFirst: UIViewRepresentable {
    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: FinderView, context: Context) {}

    final class FinderView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, let scrollView = enclosingScrollView else { return }
            var responder = scrollView.next
            while let current = responder, !(current is UINavigationController) { responder = current.next }
            guard let backSwipe = (responder as? UINavigationController)?.interactivePopGestureRecognizer else { return }
            scrollView.panGestureRecognizer.require(toFail: backSwipe)
        }
    }
}
#endif
