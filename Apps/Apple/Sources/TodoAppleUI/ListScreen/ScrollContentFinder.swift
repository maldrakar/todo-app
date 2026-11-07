// Apps/Apple/Sources/TodoAppleUI/ListScreen/ScrollContentFinder.swift
// iOS alone: the recognizer and the conversion are UIKit's, which the Mac's drag, another task's, and the watch do not
// have.
#if os(iOS)
import DesignSystemComponents
import SwiftUI
import UIKit

/// A plain view placed as the background of a scroll view's content, which gives the screen's gestures what only UIKit
/// can: where a drop's point stands in the content, the scroll view to settle, and, on the list, the row's swipe.
///
/// The swipe is one `UIPanGestureRecognizer` on the `UIScrollView` behind the `ScrollView` (spike #174, round 1), found
/// by walking up from this view once it is in a window, as `ListsDragGesture` finds its own. The scroll waits for it to
/// fail, which it does at once for a pan mostly up or down, or one over no row that has a swipe, so the list scrolls as
/// if it were not there and a pan on the tag bar stays the bar's. How far the finger has moved is read from where it
/// came down and not from the pan's translation, which UIKit starts at zero once the pan begins, past its hysteresis
/// (spike #174). A pan starting in a text field is the field's.
///
/// A pan of the scroll view closes the row left open: its recognizer is public, and its first stage is the scroll's.
///
/// What it holds goes with it: the recognizers leaked per switch of Show as in the spike until they did.
struct ScrollContentFinder: UIViewRepresentable {
    private let space: RowDragSpace
    private let swipe: ScreenSwipe?
    private let rowAt: (_ point: CGPoint, _ moved: CGFloat) -> (row: BlockRowID, style: SwipeStyle)?

    /// The finder of the board, whose cards have no swipe.
    init(space: RowDragSpace) {
        self.space = space
        swipe = nil
        rowAt = { _, _ in nil }
    }

    /// The finder of the list, whose rows are swiped, each found by `rowAt`.
    init(
        space: RowDragSpace, swipe: ScreenSwipe,
        rowAt: @escaping (_ point: CGPoint, _ moved: CGFloat) -> (row: BlockRowID, style: SwipeStyle)?
    ) {
        self.space = space
        self.swipe = swipe
        self.rowAt = rowAt
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        // The view only places the recognizer and measures the content; the rows over it take the touches.
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        context.coordinator.finder = view
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: FinderView, context: Context) {
        context.coordinator.space = space
        context.coordinator.swipe = swipe
        context.coordinator.rowAt = rowAt
    }

    static func dismantleUIView(_ view: FinderView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class FinderView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            if let scrollView = enclosingScrollView { coordinator?.didAppear(in: scrollView) }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var finder: UIView?
        var space: RowDragSpace?
        var swipe: ScreenSwipe?
        var rowAt: (CGPoint, CGFloat) -> (row: BlockRowID, style: SwipeStyle)? = { _, _ in nil }
        private weak var scrollView: UIScrollView?

        /// Where the pan's finger came down, in the content's own coordinates.
        private var start = CGPoint.zero

        private lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panChanged(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            return pan
        }()

        /// This view has come into a window in the scroll view, which makes it the one a drag reads: the list's and the
        /// board's share the screen's space, and what leaves does so with no word of it, after what comes has made its
        /// view, so that a write from anything but this moment left the space with a view gone and a board's drop
        /// unconverted (the iOS 26.3 simulator, 2026-11-07).
        func didAppear(in scrollView: UIScrollView) {
            space?.content = finder
            space?.scrollView = scrollView
            guard self.scrollView !== scrollView else { return }
            removeRecognizers()
            self.scrollView = scrollView
            guard swipe != nil else { return }
            scrollView.addGestureRecognizer(pan)
            scrollView.panGestureRecognizer.require(toFail: pan)
            scrollView.panGestureRecognizer.addTarget(self, action: #selector(scrollChanged(_:)))
        }

        /// Lets go of the scroll view and of what the closures hold, as this view goes.
        func uninstall() {
            removeRecognizers()
            swipe = nil
            rowAt = { _, _ in nil }
        }

        private func removeRecognizers() {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(scrollChanged(_:)))
            scrollView?.removeGestureRecognizer(pan)
            scrollView = nil
        }

        @objc private func panChanged(_ pan: UIPanGestureRecognizer) {
            guard let finder, let swipe else { return }
            let move = pan.location(in: finder).x - start.x
            switch pan.state {
            case .began:
                guard let taken = rowAt(start, move) else { return }
                swipe.step(.began(taken.row, taken.style))
                swipe.step(.changed(move))
            case .changed:
                swipe.step(.changed(move))
            case .ended:
                swipe.step(.ended(move))
            case .cancelled, .failed:
                swipe.step(.cancelled)
            case .possible:
                break
            @unknown default:
                break
            }
        }

        @objc private func scrollChanged(_ pan: UIPanGestureRecognizer) {
            if pan.state == .began { swipe?.close() }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === pan, let finder else { return true }
            let location = pan.location(in: finder)
            let move = CGPoint(x: location.x - start.x, y: location.y - start.y)
            return abs(move.x) > abs(move.y) && rowAt(start, move.x) != nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // While the pan waits for its touch only: a second finger, which it does not follow, moved the row by its
            // distance from the first.
            if pan.state == .possible, let finder { start = touch.location(in: finder) }
            var view = touch.view
            while let current = view {
                if current is UITextInput { return false }
                view = current.superview
            }
            return true
        }
    }
}
#endif
