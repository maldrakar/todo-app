// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowDragState.swift
import SwiftUI
import TaskListFeature
#if os(iOS)
// A drop's point is carried into the content through the window, and a board settles by its scroll view: UIKit's alone.
import UIKit
#endif

/// What the screen's gestures stand at now, which its blocks and rows draw from: the lift, nil while no row is lifted,
/// what the drag knows of the layout, the swipe, and what a row's Delete sends, which leaves the swipe as it stands,
/// since the row goes from where it stands.
///
/// `RowGestures` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct RowGestures {
    let lift: RowLift?
    let dragState: RowDragState
    let swipe: ScreenSwipe
    let delete: (TaskList.UserAction) -> Void
}

/// What a drag and a swipe read of the layout and of the drag under way, and draw nothing from. Kept in a class that
/// nothing observes and held in the screen's state, so that a layout that reports frames does not draw the screen again
/// (spike #145).
///
/// `RowDragState` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor
final class RowDragState {
    /// The frames the screen's rows, blocks and columns last reported, each as it changed, and kept for one that has
    /// left: what reads them reads those drawn.
    var frames = RowLift.Frames()

    // iOS alone: only there does a system drag stand on the screen, and these are UIKit's.
    #if os(iOS)
    /// The drags `onDrag` has begun.
    var sessions = RowDragSessions()

    /// Whether the drop's delegate has heard of the drag since this was last read (`RowDropTarget`).
    var wasHeard = false

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
    func settle(among blocks: [TaskList.Model.Block], inset: CGFloat, animated: Bool) {
        guard let scrollView, let content else { return }
        let low = -scrollView.adjustedContentInset.left
        let high = max(
            low, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right
        )
        let columns = blocks.compactMap { frames.blocks[$0.id] }.map { frame in
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
}

extension View {
    /// Reports this view's frame in the content's space into a table of the screen's frames, as it changes, which reads
    /// true while a column scrolls under its rows, by `onGeometryChange` and not a preference: measured in a release
    /// build, the swipe's frames took half as long, with the lift and the scroll no different (fix round 1 of #177).
    @MainActor
    func reportsLiftFrame<Key: Hashable & Sendable>(
        _ table: WritableKeyPath<RowLift.Frames, [Key: CGRect]> & Sendable, _ key: Key, to dragState: RowDragState
    ) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(RowLift.contentSpace)) } action: { frame in
            dragState.frames[keyPath: table][key] = frame
        }
    }
}

/// The content of the list or of the board as the space a drag finds its place in, which its rows report their frames
/// in, and on iOS what only UIKit gives it (`ScrollContentFinder`).
struct RowDragContent: ViewModifier {
    private let dragState: RowDragState
    #if os(iOS)
    private let finder: ScrollContentFinder
    #endif

    #if os(iOS)
    init(dragState: RowDragState, finder: ScrollContentFinder) {
        self.dragState = dragState
        self.finder = finder
    }
    #else
    init(dragState: RowDragState) {
        self.dragState = dragState
    }
    #endif

    func body(content: Content) -> some View {
        content
            .coordinateSpace(.named(RowLift.contentSpace))
            #if os(iOS)
            .background { finder }
            #endif
    }
}
