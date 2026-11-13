// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowPointerDrag.swift
import DesignSystemComponents
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
/// the pointer as it was grabbed, with no motion of its own. The mark moves on the slot's motion, as on iOS
/// (`RowLift.step`).
///
/// Let go, the copy settles on the slot's motion, as iOS's does (#211; `RowLift.Settling`): onto the row the task
/// landed as, or back onto its own where nothing landed, at the place the drop's layout stood it, which that row gives
/// in the same pass (`SettlingRowBounds`), shrinking to its size and turning into the row as its block draws it
/// (`RowFace`) while that row stands hidden under it; or, where the row is out of sight or not laid out, toward the
/// edge of what is in sight or into its block's tinted area, fading as it goes. Where a person asked for less motion
/// the copy goes at once and the mark moves at once.
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
    @Binding private var settling: BlockRowID?
    private let dragState: RowDragState
    private let send: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the pointer that holds a press stands in the content, from the drag's first move, and nil while none does:
    /// SwiftUI puts it back when the gesture ends, let go or cancelled, which a cancel says by no other means.
    @GestureState private var pointer: CGPoint?

    /// The press under way, from the drag's first move to its release or its cancel, which only its reading moves
    /// (`RowPointerPress.after(_:from:lift:among:frames:viewport:)`).
    @State private var press: RowPointerPress?

    /// The copy let go, from its release to the end of its settling, and nil while none settles.
    @State private var settle: Settle?

    /// A copy let go: the lift as the release found it, the row it settles onto, the task it draws and its lift, the
    /// look of the column it settles into, nil for a list's block, and where its top left corner, its size and the
    /// point it grew about stood as it was let go.
    private struct Settle {
        let released: RowLift
        let row: BlockRowID
        let task: TaskRowModel<TaskList.UserAction>
        let style: TaskLiftStyle
        let column: ColumnStyle?
        let origin: CGPoint
        let size: CGSize
        let anchor: UnitPoint
    }

    /// The drag over a content of the blocks drawn, the lift and the row a copy settles onto, which it moves, what it
    /// reads of the layout, and what a drop sends.
    init(
        _ blocks: [TaskList.Model.Block], lift: Binding<RowLift?>, settling: Binding<BlockRowID?>,
        dragState: RowDragState, send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.blocks = blocks
        _lift = lift
        _settling = settling
        self.dragState = dragState
        self.send = send
    }

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(SettlingRowBounds.self, alignment: .topLeading) { bounds in
                GeometryReader { proxy in
                    copy(settlingInto: bounds.map { proxy[$0] })
                }
            }
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
            .onEnded { value in release(at: value.location) }
    }

    /// An event of the drag: the press it leaves, and the stage of the lift it makes, with the lift it leaves and the
    /// drop it reports; and that stage.
    @discardableResult
    private func step(_ event: RowPointerPress.Event) -> RowLift.Phase? {
        let step = RowPointerPress.after(
            event, from: press, lift: lift, among: blocks, frames: dragState.frames, viewport: dragState.viewport
        )
        press = step.press
        if let phase = step.phase {
            RowLift.step(
                phase, of: $lift, among: blocks, frames: dragState.frames, reduceMotion: reduceMotion, send: send
            )
        }
        return step.phase
    }

    /// The release with the pointer at the point: the drop, and the copy of the press's own lift settling, with the
    /// row it settles onto hidden, until its motion ends.
    private func release(at point: CGPoint) {
        let released = lift
        let grabbed = press
        guard case .ended = step(.released), !reduceMotion, let released, let grabbed else { return }
        let source = BlockRowID(block: released.source, task: released.task)
        guard let task = source.rowModel(among: blocks), let style = task.style.lift,
              let frame = dragState.frames.rows[source]
        else { return }
        let row = BlockRowID(block: released.slot?.block ?? released.source, task: released.task)
        let column = blocks.first { $0.id == row.block }?.column?.style
        settling = row
        withAnimation(Animation(style.slotAnimation), completionCriteria: .logicallyComplete) {
            settle = Settle(
                released: released, row: row, task: task, style: style, column: column,
                origin: grabbed.copyOrigin(at: point), size: frame.size,
                anchor: UnitPoint(x: grabbed.copyAnchor.x, y: grabbed.copyAnchor.y)
            )
        } completion: {
            if settle?.row == row { settle = nil }
            if settling == row { settling = nil }
        }
    }

    /// Where the copy stands and how it looks: under the pointer while it is carried, grown to its lift's scale about
    /// the point the press grabbed, on its lift's background and casting its lift's shadow; and settling once let go,
    /// at the row's place in the drop's layout, given here as the row's bounds where it is laid out.
    private struct CopyPlace {
        let task: TaskRowModel<TaskList.UserAction>
        let style: TaskLiftStyle
        let column: ColumnStyle?
        let row: BlockRowID
        let origin: CGPoint
        let scale: Double
        let anchor: UnitPoint
        let isLifted: Bool
        let isFading: Bool
    }

    private func place(settlingInto bounds: CGRect?) -> CopyPlace? {
        if let settle {
            var frames = dragState.frames
            frames.rows[settle.row] = bounds
            let settling = RowLift.settling(
                onto: settle.row, among: blocks, frames: frames, inSight: dragState.viewport
            )
            let turnsIntoRow = settling?.turnsIntoRow ?? false
            return CopyPlace(
                task: settle.task, style: settle.style, column: settle.column,
                row: BlockRowID(block: settle.released.source, task: settle.released.task),
                origin: settling?.origin(forCopyOf: settle.size) ?? settle.origin,
                scale: turnsIntoRow ? 1 : settle.style.scale, anchor: settle.anchor, isLifted: !turnsIntoRow,
                isFading: !turnsIntoRow
            )
        }
        let row = lift.map { BlockRowID(block: $0.source, task: $0.task) }
        guard let row, let pointer, let press, let task = row.rowModel(among: blocks), let style = task.style.lift
        else { return nil }
        return CopyPlace(
            task: task, style: style, column: blocks.first { $0.id == row.block }?.column?.style, row: row,
            origin: press.copyOrigin(at: pointer), scale: style.scale,
            anchor: UnitPoint(x: press.copyAnchor.x, y: press.copyAnchor.y), isLifted: true, isFading: false
        )
    }

    /// The lifted task's copy, carried or settling (`CopyPlace`): the row as iOS's copy draws it (`RowDragCopy`),
    /// turning on its way into the row as its block draws it (`RowFace`), as wide as the row stood, over the content
    /// and taking no pointer. An open card is never lifted, so it has none.
    @ViewBuilder private func copy(settlingInto bounds: CGRect?) -> some View {
        if let place = place(settlingInto: bounds) {
            let width = dragState.frames.rows[place.row]?.width ?? settle?.size.width
            ZStack(alignment: .topLeading) {
                RowFace(place.task, column: place.column, send: { _ in })
                    .frame(width: width)
                    .opacity(place.isLifted ? 0 : 1)
                RowDragCopy(task: place.task, lift: place.style, row: place.row, dragState: dragState)
                    // One shadow, the copy's outline's, and not one under each of its words.
                    .compositingGroup()
                    .shadow(place.style.shadow)
                    .opacity(place.isLifted ? 1 : 0)
            }
            .scaleEffect(place.scale, anchor: place.anchor)
            .opacity(place.isFading ? 0 : 1)
            .offset(x: place.origin.x, y: place.origin.y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
#endif
