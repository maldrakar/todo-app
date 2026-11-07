// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreenGestures.swift
import SwiftUI
import TaskListFeature

/// What a list screen keeps of its rows' gestures, the view's own, which nothing else can know: the drag in progress,
/// what it reads of the layout, and the row swiped aside; and what its views take of them.
///
/// `ListScreenGestures` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor
struct ListScreenGestures: DynamicProperty {
    /// The task the system's drag has lifted, and nil while none is.
    @State private var lift: RowLift?

    /// What the drag and the swipe read of the layout, which nothing observes.
    @State private var dragState = RowDragState()

    /// The row a swipe has moved aside.
    @State private var swipe = ScreenSwipe()

    /// What they stand at now, for the rows to draw from, with what a row's Delete sends.
    func forRows(delete: @escaping (TaskList.UserAction) -> Void) -> RowGestures {
        RowGestures(lift: lift, dragState: dragState, swipe: swipe, delete: delete)
    }

    func closeSwipe() {
        swipe.close()
    }

    /// The scroll view as the system's drag's target over the blocks drawn.
    func dropTarget(
        _ blocks: [TaskList.Model.Block], settleInset: CGFloat?, send: @escaping (TaskList.UserAction) -> Void
    ) -> RowDropTarget {
        RowDropTarget(blocks, lift: $lift, gestures: forRows(delete: send), settleInset: settleInset, send: send)
    }

    /// The list's content as the space a drag finds its place in, and what its rows' swipe reads there.
    func listContent(_ blocks: [TaskList.Model.Block]) -> RowDragContent {
        // iOS alone: its finder is UIKit's.
        #if os(iOS)
        RowDragContent(
            dragState: dragState,
            finder: ScrollContentFinder(dragState: dragState, swipe: swipe) { [dragState, swipe] point, moved in
                RowSwipe.row(at: point, moved: moved, from: swipe.current, among: blocks, frames: dragState.frames)
            }
        )
        #else
        RowDragContent(dragState: dragState)
        #endif
    }
}
