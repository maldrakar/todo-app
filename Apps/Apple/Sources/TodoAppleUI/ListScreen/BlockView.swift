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
struct BlockView: View {
    private let block: TaskList.Model.Block
    private let gestures: RowGestures
    private let send: (TaskList.UserAction) -> Void

    init(_ block: TaskList.Model.Block, gestures: RowGestures, send: @escaping (TaskList.UserAction) -> Void) {
        self.block = block
        self.gestures = gestures
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = block.header {
                BlockHeaderView(header, send: send)
            }
            mark(after: nil)
            ForEach(block.rows) { row in
                BlockRow(row, in: block.id, gestures: gestures, send: send)
                mark(after: row.id)
            }
            if let addTask = block.addTask {
                AddRowView(addTask, send: send)
            }
        }
        // The screen's width, whatever it holds: a block with no header and no rows, its "+ Add task" alone, was only
        // as wide as that row, its tint a pill round it and its frame a drop's nearest block for none of the screen's
        // right side.
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if let style = block.dropStyle {
                BlockDropTint(style, isOn: gestures.lift?.slot == .into(block.id))
            }
        }
        .reportsLiftFrame(\.blocks, block.id, to: gestures.dragState)
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

/// The tint of a block a task dragged from another block would land in, and the ring inside its edge, as a column's
/// (`ColumnView`), in from the screen's sides as its style says. Over the block and not under it, since its rows stand
/// on the paper, which would hide it, and the tint lets them show through; it takes no touch. On its motion, or at once
/// where a person asked for less motion.
private struct BlockDropTint: View {
    private let style: BlockDropStyle
    private let isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ style: BlockDropStyle, isOn: Bool) {
        self.style = style
        self.isOn = isOn
    }

    var body: some View {
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
            let face = TaskRowView(task, send: sendFromRow(task))
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
