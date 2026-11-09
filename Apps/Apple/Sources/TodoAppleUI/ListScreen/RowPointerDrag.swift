// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowPointerDrag.swift
import SwiftUI
import TaskListFeature

#if os(macOS)
/// The Mac's drag of a row or a column's card by the pointer, over the content of the list or of the board, in the
/// content's own coordinates, which the rows report their frames in, as the sidebar's drag is (`ListsTree`'s
/// `pointerDrag(among:)`): a drag of the pointer with its primary button, which starts past SwiftUI's default distance,
/// so that a click is still the row's tap and a secondary click its menu, lifts the row the press began on, as
/// `RowPointerPress` reads it, moves the slot as the pointer moves and reports the drop once, on the release, each stage
/// through `RowLift` as the system's drag's is on iOS; the slot is marked as there, by the line in the block the task
/// came from and the tint over another. A drag SwiftUI cancels puts the row down with no drop (`pointer`); one that
/// ended has put it down already, and the cancel after it moves nothing. While it is carried the row stays where it
/// was, dimmed (`RowDragSource`), and a copy of it, grown to its lift's scale and casting its lift's shadow, follows the
/// pointer as it was grabbed. Nothing of it has a motion of its own: the mark moves at once, as on iOS, and the copy
/// where the pointer does, so Reduce Motion changes nothing here.
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

    /// The press under way, from the drag's first move to its release or its cancel.
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
                if isUp { end(.cancelled) }
            }
    }

    private var drag: some Gesture {
        DragGesture(coordinateSpace: .named(RowLift.contentSpace))
            .updating($pointer) { value, pointer, _ in pointer = value.location }
            .onChanged { value in
                let press = press ?? RowPointerPress(at: value.startLocation, among: blocks, frames: dragState.frames)
                self.press = press
                if let phase = press.phase(at: value.location, lift: lift) { step(phase) }
            }
            .onEnded { _ in end(.ended) }
    }

    /// The press's last stage, its release or its cancel, after which the next press is another.
    private func end(_ phase: RowLift.Phase) {
        step(phase)
        press = nil
    }

    /// A stage of the drag: the lift it leaves and the drop it reports.
    private func step(_ phase: RowLift.Phase) {
        let step = RowLift.after(phase, from: lift, among: blocks, frames: dragState.frames)
        if step.lift != lift { lift = step.lift }
        if let drop = step.drop { send(drop) }
    }

    /// The lifted task's copy under the pointer, standing as it was grabbed (`RowPointerPress`): the row as iOS's copy
    /// draws it (`RowDragCopy`), grown to its lift's scale and casting its lift's shadow, over the content and taking no
    /// pointer. One switch over the kinds of a row, both drawn and none by `default` (`docs/style.md`, "Views"): an open
    /// card is never lifted, so its case draws nothing.
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
                    .scaleEffect(style.scale)
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
