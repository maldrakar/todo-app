// Apps/Apple/Sources/TodoAppleUI/ListScreen/BlockView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature
import TodoCore

/// A block of the list as its model describes it (`TaskList.Model.Block`; `Phone.dc.html`, the group): its header where
/// it has one, its rows, and "+ Add task" at its end where its rule reads as an edit. What it holds arrives finished in
/// the model, and folding it takes its rows out of it, so this view decides nothing. While a dragged task would land in
/// it, which only the drag knows, the block's mark of the place opens a gap among its rows where the task was dragged
/// from it, and where it was dragged from another block the block is tinted, as a column is, with no place marked.
///
/// It draws the parts of the block it is given, the whole block or what of it one of the list's runs holds
/// (`ListRuns`), and has no stack of its own, so that its parts are the lazy stack's children, each laid out only in
/// sight (#196). Each part is the screen's width and reports its frame, whose union is the block's
/// (`RowLift.Frames.report`), and the tint is drawn over the content at that union (`BlockDropTints`).
struct BlockView: View {
    private let block: TaskList.Model.Block
    private let parts: Parts
    private let gestures: RowGestures
    private let send: (TaskList.UserAction) -> Void

    /// What of a block a view draws: its header, the mark at its top, a range of its rows, each with the mark after
    /// it, and its "+ Add task", each where the block has it.
    struct Parts {
        let header: Bool
        let topMark: Bool
        let rows: Range<Int>
        let add: Bool
    }

    init(
        _ block: TaskList.Model.Block, parts: Parts, gestures: RowGestures,
        send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.block = block
        self.parts = parts
        self.gestures = gestures
        self.send = send
    }

    var body: some View {
        if parts.header, let header = block.header {
            BlockHeaderView(header, send: send)
                .blockPart(.header, of: block.id, to: gestures.dragState)
        }
        if parts.topMark {
            mark(after: nil)
        }
        // Each row by its block and its task, which the lazy stack keys its children by: by its task alone, a task
        // dropped into another block, or drawn in two, was one child in both places and drew as it stood before.
        ForEach(block.rows[parts.rows].map { Item(block: block.id, row: $0) }) { item in
            BlockRow(item.row, in: block.id, gestures: gestures, send: send)
                .equatable()
                .blockPart(.row(item.row.id), of: block.id, to: gestures.dragState)
            mark(after: item.row.id)
        }
        if parts.add, let addTask = block.addTask {
            AddRowView(addTask, send: send)
                .blockPart(.add, of: block.id, to: gestures.dragState)
        }
    }

    /// A row of the block as the lazy stack's child, by its block and its task (`BlockRowID`).
    private struct Item: Identifiable {
        let block: TaskList.Model.BlockID
        let row: TaskList.Model.Row

        var id: BlockRowID { BlockRowID(block: block, task: row.id) }
    }

    /// The mark, where the lift's slot stands after this row, nil for the block's top, from the rows' leading edge. It
    /// stands in the flow, as the canvas's does (`Phone.dc.html`, `slotBefore`).
    @ViewBuilder private func mark(after row: TaskID?) -> some View {
        if gestures.lift?.slot == .place(block.id, after: row), let indicator = block.indicator {
            DropIndicator(indicator, from: 0, visibleRight: gestures.dragState.frames.lineEnd(in: block.id))
                .accessibilityHidden(true)
        }
    }
}

/// The tints of the list's blocks a task dragged from another block would land in, over the content, each at the
/// union of the frames its block's parts last reported (`RowLift.Frames.report`), since the parts stand in a lazy
/// stack with no view of the block round them, and the one the slot names at that union as the drag lays its block
/// out, the auto-scroll's parts among them (`BlockTintFrame`). It takes no touch.
struct BlockDropTints: View {
    private let blocks: [TaskList.Model.Block]
    private let gestures: RowGestures

    init(_ blocks: [TaskList.Model.Block], gestures: RowGestures) {
        self.blocks = blocks
        self.gestures = gestures
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(blocks) { block in
                if let style = block.dropStyle {
                    BlockDropTint(style, of: block.id, gestures: gestures)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .onChange(of: gestures.lift?.slot, initial: true) { _, slot in gestures.dragState.watch(slot) }
    }
}

extension View {
    /// A part of a list's block, the screen's width whatever it holds, reporting its frame among its block's
    /// (`RowDragState.report`): a block of "+ Add task" alone was only as wide as that row, its tint a pill round it
    /// and its frame a drop's nearest block for none of the screen's right side.
    @MainActor
    fileprivate func blockPart(
        _ part: RowLift.Frames.BlockPart, of block: TaskList.Model.BlockID, to dragState: RowDragState
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(RowLift.contentSpace)) } action: { frame in
                dragState.report(part, of: block, frame)
            }
    }
}

/// The tint of a block a task dragged from another block would land in, and the ring inside its edge, as a column's
/// (`ColumnView`), in from the screen's sides as its style says, at its block's frame: the one the drag follows while
/// the slot names it, which this view alone observes, and otherwise the one last reported, where it fades. Over the
/// block and not under it, since its rows stand on the paper, which would hide it, and the tint lets them show through;
/// it takes no touch. On its motion, or at once where a person asked for less motion.
private struct BlockDropTint: View {
    private let style: BlockDropStyle
    private let block: TaskList.Model.BlockID
    private let gestures: RowGestures

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ style: BlockDropStyle, of block: TaskList.Model.BlockID, gestures: RowGestures) {
        self.style = style
        self.block = block
        self.gestures = gestures
    }

    var body: some View {
        let dragState = gestures.dragState
        if let frame = dragState.tint.frame(of: block) ?? dragState.frames.blocks[block] {
            let isOn = gestures.lift?.slot == .into(block)
            let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .circular)
            ZStack {
                shape.fill(Color(style.tint))
                shape.strokeBorder(Color(style.ring), lineWidth: style.ringWidth)
            }
            .padding(.horizontal, style.inset)
            .opacity(isOn ? 1 : 0)
            .animation(reduceMotion ? nil : Animation(style.animation), value: isOn)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
        }
    }
}

/// A row of a block, of the strip or of a column, by its kind: the one switch over a row's kinds, every case drawn and
/// none by `default` (`docs/style.md`, "Views"). In a column, whose style it is given, a row stands on the card's look
/// and an open card, which draws its own surface and shadow, has only the card's hairline round it (`Phone.dc.html`,
/// `.card`).
///
/// A row of a block or a column has the screen's gestures and reports its frame to them: a task's row lands, opens its
/// menu, is dragged and swiped where its model says it can be (`TaskLanding`, `RowDragSource`, `SwipeToDelete`), and an
/// open card, which is neither lifted nor has a menu, is only a row a drag can stand after. A row of the strip has none
/// of them. A tap on a row while a row stands swiped open only closes that one (`Phone.dc.html`, `expand`), and a
/// Delete takes the row away on its leaving motion. A row stands on its style's ground, which the system's menu lifts
/// with it, and which its swipe moves off the Delete behind it: with nothing under it, the menu's shadow showed through
/// the row (the iOS 26.3 simulator, 2026-11-07).
struct BlockRow: View {
    private let row: TaskList.Model.Row
    private let block: TaskList.Model.BlockID?
    private let column: ColumnStyle?
    private let gestures: RowGestures?
    private let send: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A row of a block or of a column, whose style it is given.
    init(
        _ row: TaskList.Model.Row, in block: TaskList.Model.BlockID, column: ColumnStyle? = nil,
        gestures: RowGestures, send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.row = row
        self.block = block
        self.column = column
        self.gestures = gestures
        self.send = send
    }

    /// A row of the strip.
    init(_ row: TaskList.Model.Row, send: @escaping (TaskList.UserAction) -> Void) {
        self.row = row
        block = nil
        column = nil
        gestures = nil
        self.send = send
    }

    var body: some View {
        switch row {
        case .task(let id, let task):
            // The face skips its body where only the lift changed the row.
            let face = TaskRowView(task, send: sendFromRow(task))
            .equatable()
            .modifier(ColumnCardSurface(column: column))
            .modifier(ColumnCardRing(column: column))
            .modifier(TaskLanding(task.style))
            if let block, let gestures {
                let row = BlockRowID(block: block, task: id)
                let delete = { (action: TaskList.UserAction) in
                    sendDelete(action, row: row, leaving: task.style.leaving, gestures: gestures)
                }
                face
                    .background { task.style.ground.map { Color($0) } }
                    .modifier(RowDragSource(task, row: row, gestures: gestures, delete: delete))
                    .modifier(SwipeToDelete(task.swipe, of: row, in: gestures.swipe, delete: delete))
                    .reportsLiftFrame(\.rows, row, to: gestures.dragState)
            } else {
                face
            }
        case .card(let id, let card):
            let face = TaskCardView(
                card, titleChanged: { .titleFieldChanged($0) }, notesChanged: { .notesFieldChanged($0) },
                subtaskChanged: { .subtaskFieldChanged($0) }, send: send
            )
            .modifier(ColumnCardRing(column: column))
            if let block, let gestures {
                let row = BlockRowID(block: block, task: id)
                face.reportsLiftFrame(\.rows, row, to: gestures.dragState)
            } else {
                face
            }
        }
    }

    /// What a task's row sends: a tap on it beside its check, its model's `tap`, only closes the row a swipe left open,
    /// and the rest closes it and acts, as every control of the screen does (`Phone.dc.html`, `expand` and `complete`).
    private func sendFromRow(_ task: TaskRowModel<TaskList.UserAction>) -> (TaskList.UserAction) -> Void {
        { action in
            if action == task.tap, let swipe = gestures?.swipe, swipe.isOpen {
                swipe.close()
            } else {
                send(action)
            }
        }
    }

    /// Sends a Delete, on the motion that takes the row away as a done row leaves with no wait, the rows under it
    /// closing up. A swiped row goes from where it stands, aside, and its swipe ends with the motion, which brings it
    /// back where the store refused.
    private func sendDelete(
        _ action: TaskList.UserAction, row: BlockRowID, leaving: TaskLeavingStyle, gestures: RowGestures
    ) {
        guard !reduceMotion else {
            gestures.delete(action)
            gestures.swipe.rowLeft(row)
            return
        }
        withAnimation(Animation(leaving.deleteAnimation), completionCriteria: .logicallyComplete) {
            gestures.delete(action)
        } completion: {
            gestures.swipe.rowLeft(row)
        }
    }

    /// What a card of a column stands on, casting its shadow, or the deeper one its style gives while the pointer is
    /// over it (`Hovering`; `Mac.dc.html`, `.card:hover`); and nothing for a row of the list.
    private struct ColumnCardSurface: ViewModifier {
        let column: ColumnStyle?

        func body(content: Content) -> some View {
            if let column {
                content.modifier(Hovering(animation: column.cardHover?.animation) { isHovered in
                    RoundedRectangle(cornerRadius: column.cardCornerRadius, style: .circular)
                        .fill(Color(column.cardBackground))
                        .shadow(isHovered ? column.cardHover?.shadow ?? column.cardShadow : column.cardShadow)
                })
            } else {
                content
            }
        }
    }

    /// The hairline round a card of a column, and nothing for a row of the list.
    private struct ColumnCardRing: ViewModifier {
        let column: ColumnStyle?

        func body(content: Content) -> some View {
            if let column {
                content.overlay {
                    RoundedRectangle(cornerRadius: column.cardCornerRadius, style: .circular)
                        .stroke(column.cardRing)
                }
            } else {
                content
            }
        }
    }
}

/// A row is drawn from its row, its block, its column's look and whether the drag has lifted it, with its screen's drag
/// and swipe, and a row none of them changed skips its body: a change to one row ran every row's body, twice (#196).
/// Its `send` and its gestures' Delete are left out, since whichever pass made them they reach the same screen's one
/// `send`, and SwiftUI would compare them by identity, which every pass changes; and so is the row swiped aside, which
/// `SwipeToDelete` reads where it is drawn. On the main actor, since the gestures' Delete is not `Sendable`.
extension BlockRow: @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.block == rhs.block && lhs.column == rhs.column && lhs.isLifted == rhs.isLifted
            && lhs.gestures?.dragState === rhs.gestures?.dragState && lhs.gestures?.swipe === rhs.gestures?.swipe
    }

    /// Whether the drag has lifted this row, which a row of the strip never is.
    private var isLifted: Bool {
        guard let block, let gestures else { return false }
        return gestures.isLifted(BlockRowID(block: block, task: row.id))
    }
}
