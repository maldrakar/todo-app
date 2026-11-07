// Apps/Apple/Sources/TodoAppleUI/ListScreen/BlockView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature
import TodoCore

/// A block of the list as its model describes it (`TaskList.Model.Block`; `Phone.dc.html`, the group): its header where
/// it has one, its rows, and "+ Add task" at its end where its rule reads as an edit. What it holds arrives finished in
/// the model, and folding it takes its rows out of it, so this view decides nothing. While a dragged task would land in
/// it, which only the drag knows, the mark of the place opens a gap among its rows, in the colour of its own rows' list
/// where it has one and otherwise of the row lifted.
struct BlockView: View {
    private let block: TaskList.Model.Block
    private let gestures: ScreenGestures
    private let send: (TaskList.UserAction) -> Void

    init(_ block: TaskList.Model.Block, gestures: ScreenGestures, send: @escaping (TaskList.UserAction) -> Void) {
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
        .reportsLiftFrame { [id = block.id] in RowLift.Frames(blocks: [id: $0]) }
    }

    /// The mark, where the lift's slot stands after this row, nil for the block's top, from the rows' leading edge. It
    /// stands in the flow, as the canvas's does (`Phone.dc.html`, `slotBefore`).
    @ViewBuilder private func mark(after row: TaskID?) -> some View {
        if let lift = gestures.lift, lift.slot == RowLift.Slot(block: block.id, after: row),
           let indicator = block.rows.lazy.compactMap(\.lift).first?.indicator ?? lift.style.indicator {
            DropIndicator(indicator, from: 0, visibleRight: gestures.space.frames.blocks[block.id]?.maxX ?? 0)
                .accessibilityHidden(true)
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
/// Delete takes the row away on its leaving motion. A row of the list stands on the screen's ground, which the system's
/// menu lifts with it, and which its swipe moves off the Delete behind it: with nothing under it, the menu's shadow
/// showed through the row (the iOS 26.3 simulator, 2026-11-07). A column's card has its surface.
struct BlockRow: View {
    private let row: TaskList.Model.Row
    private let block: TaskList.Model.BlockID?
    private let column: ColumnStyle?
    private let gestures: ScreenGestures?
    private let send: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A row of a block or of a column, whose style it is given.
    init(
        _ row: TaskList.Model.Row, in block: TaskList.Model.BlockID, column: ColumnStyle? = nil,
        gestures: ScreenGestures, send: @escaping (TaskList.UserAction) -> Void
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
            let face = TaskRowView(task) { action in
                if action == task.tap, gestures?.swipe.current != nil {
                    gestures?.swipe.current = nil
                } else {
                    send(action)
                }
            }
            .modifier(ColumnCardSurface(column: column))
            .modifier(ColumnCardRing(column: column))
            .modifier(TaskLanding(task.style))
            if let block, let gestures {
                let row = BlockRowID(block: block, task: id)
                let delete = { (action: TaskList.UserAction) in
                    deleted(action, row: row, leaving: task.style.leaving, gestures: gestures)
                }
                face
                    .background { if column == nil { Color(gestures.ground) } }
                    .modifier(RowDragSource(task, row: row, gestures: gestures, delete: delete))
                    .modifier(SwipeToDelete(task.swipe, of: row, in: gestures.swipe, delete: delete))
                    .reportsLiftFrame { RowLift.Frames(rows: [row: $0]) }
            } else {
                face
            }
        case .card(let id, let card):
            let face = TaskCardView(
                card, titleChanged: { .titleFieldChanged($0) }, notesChanged: { .notesFieldChanged($0) },
                subtaskChanged: { .subtaskFieldChanged($0) }, send: send
            )
            .modifier(ColumnCardRing(column: column))
            if let block {
                let row = BlockRowID(block: block, task: id)
                face.reportsLiftFrame { RowLift.Frames(rows: [row: $0]) }
            } else {
                face
            }
        }
    }

    /// Sends a Delete, on the motion that takes the row away as a done row leaves with no wait, the rows under it
    /// closing up. A swiped row goes from where it stands, aside, and its swipe ends with the motion, which brings it
    /// back where the store refused.
    private func deleted(
        _ action: TaskList.UserAction, row: BlockRowID, leaving: TaskLeavingStyle, gestures: ScreenGestures
    ) {
        func endSwipe() {
            if gestures.swipe.current?.row == row { gestures.swipe.current = nil }
        }
        guard !reduceMotion else {
            gestures.delete(action)
            endSwipe()
            return
        }
        withAnimation(Animation(leaving.deleteAnimation), completionCriteria: .logicallyComplete) {
            gestures.delete(action)
        } completion: {
            endSwipe()
        }
    }

    /// What a card of a column stands on, and nothing for a row of the list.
    private struct ColumnCardSurface: ViewModifier {
        let column: ColumnStyle?

        func body(content: Content) -> some View {
            if let column {
                content.background {
                    RoundedRectangle(cornerRadius: column.cardCornerRadius, style: .circular)
                        .fill(Color(column.cardBackground))
                        .shadow(column.cardShadow)
                }
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
