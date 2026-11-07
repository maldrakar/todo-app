// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowDragSpace.swift
import DesignSystem
import SwiftUI
#if os(iOS)
// A drop's point is carried into the content through the window, and a board settles by its scroll view: UIKit's alone.
import UIKit
#endif

/// What the screen's gestures stand at now, which its blocks and rows draw from: the lift, nil while no row is lifted,
/// what the drag knows of the layout, the swipe, and what the screen stands on, which a row of the list stands on too.
struct ScreenGestures {
    let lift: RowLift?
    let space: RowDragSpace
    let swipe: ScreenSwipe
    let ground: DesignSystem.Color
}

/// What a drag and a swipe read of the layout and of the drag under way, and draw nothing from. Kept in a class that
/// nothing observes and held in the screen's state, so that a layout pass that reports frames does not draw the screen
/// again (spike #145).
///
/// `RowDragSpace` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor
final class RowDragSpace {
    /// The frames the screen's rows, blocks and columns last reported.
    var frames = RowLift.Frames()

    #if os(iOS)
    /// The row the system's drag carries, from when `onDrag` asked for its item. It is no lift yet: a press that opens
    /// the menu asks too. A drag gone out of the scroll view and back still carries it.
    var carried: BlockRowID?

    /// Where the drop's view stands in the window, and the content and the scroll view it is drawn in.
    var dropOrigin = CGPoint.zero
    weak var content: UIView?
    weak var scrollView: UIScrollView?

    /// A point of the drop's view, whose frame is the scroll view's, as a point of the content the rows reported their
    /// frames in, through the window (spike #174).
    func contentPoint(fromDrop point: CGPoint) -> CGPoint {
        let window = CGPoint(x: dropOrigin.x + point.x, y: dropOrigin.y + point.y)
        return content?.convert(window, from: nil) ?? point
    }

    /// Brings the board to the nearest column's leading edge, its start or its end, where the system's scroll under a
    /// drag left it between two: that scroll knows nothing of the board's snap (spike #174).
    func settle(inset: CGFloat, animated: Bool) {
        guard let scrollView, let content else { return }
        let low = -scrollView.adjustedContentInset.left
        let high = max(
            low, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right
        )
        let columns = frames.blocks.values.map { frame in
            min(max(content.convert(frame, to: scrollView).minX - inset, low), high)
        }
        let current = scrollView.contentOffset.x
        guard let nearest = (columns + [low, high]).min(by: { abs($0 - current) < abs($1 - current) }),
              nearest != current
        else { return }
        scrollView.setContentOffset(CGPoint(x: nearest, y: scrollView.contentOffset.y), animated: animated)
    }
    #endif
}

extension RowLift {
    /// The name of the space the frames are reported in, which is the content's of the list or of the board.
    fileprivate static let contentSpace = "RowLift.content"

    /// How what a drag finds its place by reports its frame: everything laid out puts its own in the preference, and
    /// the screen keeps the whole of what the last layout reported.
    fileprivate struct FramesKey: PreferenceKey {
        static let defaultValue = Frames()

        static func reduce(value: inout Frames, nextValue: () -> Frames) {
            let next = nextValue()
            value.rows.merge(next.rows) { $1 }
            value.blocks.merge(next.blocks) { $1 }
            value.columns.merge(next.columns) { $1 }
        }
    }
}

extension View {
    /// Reports this view's frame in the content's space, as the frames the closure makes of it.
    func reportsLiftFrame(_ frames: @escaping @Sendable (CGRect) -> RowLift.Frames) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RowLift.FramesKey.self, value: frames(proxy.frame(in: .named(RowLift.contentSpace)))
                )
            }
        }
    }
}

/// The content of the list or of the board as the space a drag finds its place in: the frames reported inside it, kept
/// in the screen's unobserved class, and on iOS what only UIKit gives it (`ScrollContentFinder`).
struct RowDragContent: ViewModifier {
    private let space: RowDragSpace
    #if os(iOS)
    private let finder: ScrollContentFinder
    #endif

    #if os(iOS)
    init(space: RowDragSpace, finder: ScrollContentFinder) {
        self.space = space
        self.finder = finder
    }
    #else
    init(space: RowDragSpace) {
        self.space = space
    }
    #endif

    func body(content: Content) -> some View {
        content
            .coordinateSpace(.named(RowLift.contentSpace))
            .onPreferenceChange(RowLift.FramesKey.self) { [space] frames in
                MainActor.assumeIsolated { space.frames = frames }
            }
            #if os(iOS)
            .background { finder }
            #endif
    }
}
