// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowPointerDrag.swift
import SwiftUI
import TaskListFeature

#if os(macOS)
/// The Mac's drag of a row or a column's card by the pointer, over the content of the list or of the board, in the
/// content's own coordinates, which the rows report their frames in, as the sidebar's drag is (`ListsTree`'s
/// `pointerDrag(among:)`): a drag of the pointer with its primary button, which starts past SwiftUI's default distance,
/// so that a click is still the row's tap and a secondary click its menu, lifts the row the press began on, as
/// `RowPointerPress` reads it, moves the slot as the pointer moves and reports the drop once, on the release, each
/// stage through `RowLift` as the system's drag's is on iOS; the slot is marked as there, by the line in the block the
/// task came from and the tint over another. A drag SwiftUI cancels puts the row down with no drop (`pointer`); one
/// that ended has put it down already, and the cancel after it moves nothing. While it is carried the row stays where
/// it was, dimmed (`RowDragSource`), and a copy of it, grown to its lift's scale and casting its lift's shadow, follows
/// the pointer as it was grabbed. Nothing of it has a motion of its own: the mark moves at once, as on iOS, and the
/// copy where the pointer does, so Reduce Motion changes nothing here.
///
/// Outside the part of the content in sight (`RowDragState.viewport`), the pointer lets go of nothing: the lift is put
/// down, and comes back when the pointer does (`RowPointerPress`; the controller's ruling R218). So a release over the
/// sidebar, the window's bar or beyond the window drops nothing, nor one above the pane's top where the nearest block
/// is scrolled out of sight.
///
/// It scrolls nothing by itself, as the sidebar's does not (the controller's ruling R202): a scroll of the content
/// under a held pointer, by the wheel or the trackpad, carries the copy with the content until the pointer next moves,
/// which reads its point in the content as it then stands, the frames being the content's. Esc does not put the row
/// down, as it does not the sidebar's: the pane's Esc closes a card as before (`ListPane`), and a release over the
/// row's own place leaves it there. A drag that begins in a field is the field's, which AppKit hands its text's
/// selection with none of it reaching this gesture (a probe of 2026-11-09 on macOS 26 with Xcode 27.1, mouse events
/// handed to an off-screen window of a throwaway's own).
///
/// `RowPointerDrag` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct RowPointerDrag: ViewModifier {
    private let blocks: [TaskList.Model.Block]
    @Binding private var lift: RowLift?
    private let dragState: RowDragState
    private let send: (TaskList.UserAction) -> Void

    /// Where the pointer that holds a press stands in the content, from the drag's first move, and nil while none does:
    /// SwiftUI puts it back when the gesture ends, let go or cancelled, which a cancel says by no other means.
    @GestureState private var pointer: CGPoint?

    /// The press under way, from the drag's first move to its release or its cancel, which only its reading moves
    /// (`RowPointerPress.after(_:from:lift:among:frames:viewport:)`).
    @State private var press: RowPointerPress?

    /// The drag over a content of the blocks drawn, the lift it moves, what it reads of the layout, and what a drop
    /// sends.
    init(
        _ blocks: [TaskList.Model.Block], lift: Binding<RowLift?>, dragState: RowDragState,
        send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.blocks = blocks
        _lift = lift
        self.dragState = dragState
        self.send = send
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) { copy }
            .highPriorityGesture(drag)
            .onChange(of: pointer == nil) { _, isUp in
                if isUp { step(.cancelled) }
            }
            // Where the content stands in its scroll view, which with the scroll view's size says what of it is in
            // sight (`RowDragState.viewport`; a probe of 2026-11-09 on macOS 26: in a split view's detail under a 52
            // high bar, the content stood at (0, 0) in a 759 by 460 scroll view and at (0, -200) scrolled by 200; on
            // a board with 24 of margin at (24, 0), and at (-76, 0) scrolled by 100).
            .onGeometryChange(for: CGPoint.self) { proxy in
                proxy.frame(in: .named(RowLift.viewportSpace)).origin
            } action: { [dragState] origin in
                dragState.contentOrigin = origin
            }
    }

    private var drag: some Gesture {
        DragGesture(coordinateSpace: .named(RowLift.contentSpace))
            .updating($pointer) { value, pointer, _ in pointer = value.location }
            .onChanged { value in step(.moved(from: value.startLocation, to: value.location)) }
            .onEnded { _ in step(.released) }
    }

    /// An event of the drag: the press it leaves, and the stage of the lift it makes, with the lift it leaves and the
    /// drop it reports.
    private func step(_ event: RowPointerPress.Event) {
        let step = RowPointerPress.after(
            event, from: press, lift: lift, among: blocks, frames: dragState.frames, viewport: dragState.viewport
        )
        press = step.press
        if let phase = step.phase {
            RowLift.step(phase, of: $lift, among: blocks, frames: dragState.frames, send: send)
        }
    }

    /// The lifted task's copy under the pointer, standing as it was grabbed (`RowPointerPress`): the row as iOS's copy
    /// draws it (`RowDragCopy`), grown to its lift's scale about the grabbed point, so that it stays under the pointer,
    /// and casting its lift's shadow, over the content and taking no pointer. One switch over the kinds of a row, both
    /// drawn and none by `default` (`docs/style.md`, "Views"): an open card is never lifted, so its case draws nothing.
    @ViewBuilder private var copy: some View {
        if let lift, let pointer, let press, let row = lift.row(among: blocks) {
            switch row {
            case .task(_, let task):
                if let style = task.style.lift {
                    let origin = press.copyOrigin(at: pointer)
                    RowDragCopy(
                        task: task, lift: style, row: BlockRowID(block: lift.source, task: lift.task),
                        dragState: dragState
                    )
                    // One shadow, the copy's outline's, and not one under each of its words.
                    .compositingGroup()
                    .shadow(style.shadow)
                    .scaleEffect(style.scale, anchor: UnitPoint(x: press.copyAnchor.x, y: press.copyAnchor.y))
                    .offset(x: origin.x, y: origin.y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            case .card:
                EmptyView()
            }
        }
    }
}
#endif
