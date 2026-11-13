// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreenGestures.swift
import SwiftUI
import TaskListFeature

/// What a list screen keeps of its rows' gestures, the view's own, which nothing else can know: the drag in progress,
/// the row a dropped copy settles onto, what the drag reads of the layout, and the row swiped aside; and what its views
/// take of them.
///
/// `ListScreenGestures` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor
struct ListScreenGestures: DynamicProperty {
    /// The task a drag has lifted, the system's on iOS or the pointer's on the Mac, and nil while none is.
    @State private var lift: RowLift?

    /// The row a dropped task's copy is settling onto, hidden under it, and nil while none is (#211).
    @State private var settling: BlockRowID?

    /// What the drag and the swipe read of the layout, which nothing observes.
    @State private var dragState = RowDragState()

    /// The row a swipe has moved aside.
    @State private var swipe = ScreenSwipe()

    /// What they stand at now, for the rows to draw from, with what a row's Delete sends.
    func forRows(delete: @escaping (TaskList.UserAction) -> Void) -> RowGestures {
        RowGestures(lift: lift, settling: settling, dragState: dragState, swipe: swipe, delete: delete)
    }

    func closeSwipe() {
        swipe.close()
    }

    /// Forgets the frames of the parts the list's blocks no longer draw (`RowDragState.forgetParts(notDrawnBy:)`).
    func forgetParts(notDrawnBy blocks: [TaskList.Model.Block]) {
        dragState.forgetParts(notDrawnBy: blocks)
    }

    /// Forgets every frame the layout that is gone reported (`RowDragState.forgetLayout`).
    func forgetLayout() {
        dragState.forgetLayout()
    }

    /// The scroll view as what the Mac's pointer drag reads of it (`RowDragViewport`).
    func dragViewport() -> RowDragViewport {
        RowDragViewport(dragState: dragState)
    }

    /// The list's content as the space a drag finds its place in, with the system's drag of its rows and what their
    /// swipe reads there on iOS, or the pointer's drag over it on the Mac, each sending its drop.
    func listContent(
        _ blocks: [TaskList.Model.Block], send: @escaping (TaskList.UserAction) -> Void
    ) -> RowDragContent {
        // iOS alone: its finder is UIKit's. The Mac alone: the drag is its pointer's.
        #if os(iOS)
        RowDragContent(
            dragState: dragState,
            finder: ScrollContentFinder(drag: systemDrag(blocks, settleInset: nil, send: send)) {
                [dragState, swipe] point, moved in
                RowSwipe.row(at: point, moved: moved, from: swipe.current, among: blocks, frames: dragState.frames)
            }
        )
        #elseif os(macOS)
        RowDragContent(dragState: dragState, pointerDrag: pointerDrag(blocks, send: send))
        #else
        RowDragContent(dragState: dragState)
        #endif
    }

    /// The board's content as the space a drag finds its place in, with the system's drag of its cards on iOS, which
    /// brings the board to rest on a column by the inset given where it snaps, or the pointer's drag over it on the
    /// Mac, each sending its drop.
    func boardContent(
        _ columns: [TaskList.Model.Block], settleInset: CGFloat?, send: @escaping (TaskList.UserAction) -> Void
    ) -> RowDragContent {
        // iOS alone: its finder is UIKit's. The Mac alone: the drag is its pointer's.
        #if os(iOS)
        let drag = systemDrag(columns, settleInset: settleInset, send: send)
        return RowDragContent(dragState: dragState, finder: ScrollContentFinder(drag: drag))
        #elseif os(macOS)
        RowDragContent(dragState: dragState, pointerDrag: pointerDrag(columns, send: send))
        #else
        RowDragContent(dragState: dragState)
        #endif
    }

    #if os(iOS)
    /// What the system's drag over a content of the blocks drawn reads and writes of the screen.
    private func systemDrag(
        _ blocks: [TaskList.Model.Block], settleInset: CGFloat?, send: @escaping (TaskList.UserAction) -> Void
    ) -> RowSystemDrag.Screen {
        RowSystemDrag.Screen(
            blocks: blocks, lift: $lift, settling: $settling, gestures: forRows(delete: send), settleInset: settleInset,
            send: send
        )
    }
    #elseif os(macOS)
    /// The pointer's drag over a content of the blocks drawn, the list's or the board's.
    private func pointerDrag(
        _ blocks: [TaskList.Model.Block], send: @escaping (TaskList.UserAction) -> Void
    ) -> RowPointerDrag {
        RowPointerDrag(blocks, lift: $lift, settling: $settling, dragState: dragState, send: send)
    }
    #endif
}
