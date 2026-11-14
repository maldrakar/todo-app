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
/// landed as, or back onto its own where nothing landed, shrinking to its size and turning into the row as its block
/// draws it (`RowGround`) while that row stands hidden under it; or, where the row is wholly out of sight or not laid
/// out, toward the edge of what is in sight or into its block's tinted area, fading as it goes. Where the row stands
/// is read from the frames the drop's layout reports, which the rows have reported by the next turn of the main run
/// loop: until then the copy holds where it was let go. The row's place as it is drawn moves on the slot's motion
/// with the rows round it, from where it stood, and a copy that went by it went back to that place first (macOS 26,
/// 2026-11-14). Where a person asked for less motion the copy goes at once and the mark moves at once.
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
    @Binding private var settling: RowSettling?
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
    /// point it grew about stood as it was let go; and, once the drop's layout has reported, that it is on its way and
    /// where to, nil where it has nowhere to go.
    private struct Settle {
        let released: RowLift
        let row: BlockRowID
        let task: TaskRowModel<TaskList.UserAction>
        let style: TaskLiftStyle
        let column: ColumnStyle?
        let origin: CGPoint
        let size: CGSize
        let anchor: UnitPoint
        var isGoing = false
        var settling: RowLift.Settling?
    }

    /// The drag over a content of the blocks drawn, the lift and the rows a copy settles between, which it moves, what
    /// it reads of the layout, and what a drop sends.
    init(
        _ blocks: [TaskList.Model.Block], lift: Binding<RowLift?>, settling: Binding<RowSettling?>,
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
            .onEnded { value in release(at: value.location) }
    }

    /// An event of the drag: the press it leaves, and the stage of the lift it makes, with the lift it leaves and the
    /// drop it reports; and that stage.
    @discardableResult
    private func step(_ event: RowPointerPress.Event) -> RowLift.Phase? {
        make(after(event))
    }

    /// The press and the stage of the lift an event of the drag would leave, made by nothing yet.
    private func after(_ event: RowPointerPress.Event) -> (press: RowPointerPress?, phase: RowLift.Phase?) {
        RowPointerPress.after(
            event, from: press, lift: lift, among: blocks, frames: dragState.frames, viewport: dragState.viewport
        )
    }

    /// Makes what an event of the drag leaves (`after(_:)`), and answers its stage.
    @discardableResult
    private func make(_ step: (press: RowPointerPress?, phase: RowLift.Phase?)) -> RowLift.Phase? {
        press = step.press
        if let phase = step.phase {
            RowLift.step(
                phase, of: $lift, among: blocks, frames: dragState.frames, reduceMotion: reduceMotion, send: send
            )
        }
        return step.phase
    }

    /// The release with the pointer at the point: the drop, and the copy of the press's own lift settling, with the
    /// rows it settles between hidden (`RowSettling`) until its motion ends. The copy is held and the rows hidden
    /// before the drop is sent, the key window, the one let go in, laid out between, as iOS's are: hidden in the same
    /// pass as the drop, which the pointer's release sends from inside SwiftUI's gesture, the row the task left faded
    /// where it stood, dimmed, as the rows under it closed up through it (macOS 26, 2026-11-14).
    private func release(at point: CGPoint) {
        let released = lift
        let grabbed = press
        let release = after(.released)
        guard case .ended? = release.phase, !reduceMotion, let released, let grabbed else {
            make(release)
            return
        }
        let source = BlockRowID(block: released.source, task: released.task)
        guard let task = source.rowModel(among: blocks), let style = task.style.lift,
              let frame = dragState.frames.rows[source]
        else {
            make(release)
            return
        }
        let row = BlockRowID(block: released.slot?.block ?? released.source, task: released.task)
        let column = blocks.first { $0.id == row.block }?.column?.style
        settle = Settle(
            released: released, row: row, task: task, style: style, column: column,
            origin: grabbed.copyOrigin(at: point), size: frame.size,
            anchor: UnitPoint(x: grabbed.copyAnchor.x, y: grabbed.copyAnchor.y)
        )
        settling = RowSettling(onto: row, from: source)
        NSApp.keyWindow?.contentView?.layoutSubtreeIfNeeded()
        make(release)
        dragState.frames.forgetRow(row, notDrawnBy: blocks)
        Task { @MainActor in
            guard settle?.row == row else { return }
            let target = RowLift.settling(
                onto: row, among: blocks, frames: dragState.frames, inSight: dragState.viewport
            )
            withAnimation(Animation(style.slotAnimation), completionCriteria: .logicallyComplete) {
                settle?.isGoing = true
                settle?.settling = target
            } completion: {
                if settle?.row == row { settle = nil }
                if settling?.onto == row { settling = nil }
            }
        }
    }

    /// Where the copy stands and how it looks: under the pointer while it is carried, grown to its lift's scale about
    /// the point the press grabbed, on its lift's background and casting its lift's shadow; held where it was let go;
    /// and then settling as it goes (`RowLift.Settling`), drawing the row it settles onto as the blocks now draw it,
    /// which a drop into another list's block draws with that list's colour on its check, changing on the motion, and
    /// as wide as that row where it goes onto it.
    private struct CopyPlace {
        let task: TaskRowModel<TaskList.UserAction>
        let style: TaskLiftStyle
        let column: ColumnStyle?
        let width: CGFloat?
        let origin: CGPoint
        let scale: Double
        let anchor: UnitPoint
        let isLifted: Bool
        let isFading: Bool
    }

    private var place: CopyPlace? {
        if let settle {
            let turnsIntoRow = settle.settling?.turnsIntoRow ?? false
            let width = if case .onto(_, let frame)? = settle.settling { frame.width } else { settle.size.width }
            return CopyPlace(
                task: settle.isGoing ? settle.row.rowModel(among: blocks) ?? settle.task : settle.task,
                style: settle.style, column: settle.column, width: width,
                origin: settle.settling?.origin(forCopyOf: settle.size) ?? settle.origin,
                scale: turnsIntoRow ? 1 : settle.style.scale, anchor: settle.anchor, isLifted: !turnsIntoRow,
                isFading: settle.isGoing && !turnsIntoRow
            )
        }
        let row = lift.map { BlockRowID(block: $0.source, task: $0.task) }
        guard let row, let pointer, let press, let task = row.rowModel(among: blocks), let style = task.style.lift
        else { return nil }
        return CopyPlace(
            task: task, style: style, column: blocks.first { $0.id == row.block }?.column?.style,
            width: dragState.frames.rows[row]?.width, origin: press.copyOrigin(at: pointer), scale: style.scale,
            anchor: UnitPoint(x: press.copyAnchor.x, y: press.copyAnchor.y), isLifted: true, isFading: false
        )
    }

    /// The lifted task's copy, carried or settling (`CopyPlace`): its words on its lift's ground (`LiftGround`),
    /// casting its lift's shadow, as iOS's copy draws them, that ground turning on its way into what the row stands on
    /// as its block draws it (`RowGround`); as wide as the row stands, over the content and taking no
    /// pointer. The words are drawn once, over both: drawn with each look, they faded halfway through the motion
    /// (macOS 26, 2026-11-14). An open card is never lifted, so it has none.
    @ViewBuilder private var copy: some View {
        if let place {
            TaskRowView(place.task, send: { _ in })
                .frame(width: place.width)
                .background {
                    ZStack {
                        RowGround(column: place.column)
                            .opacity(place.isLifted ? 0 : 1)
                        LiftGround(place.style)
                            .shadow(place.style.shadow)
                            .opacity(place.isLifted ? 1 : 0)
                    }
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
