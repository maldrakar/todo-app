// Apps/Apple/Sources/TodoAppleUI/ListScreen/BlockView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A block of the list as its model describes it (`TaskList.Model.Block`; `Phone.dc.html`, the group): its header where
/// it has one, its rows, and "+ Add task" at its end where its rule reads as an edit. What it holds arrives finished in
/// the model, and folding it takes its rows out of it, so this view decides nothing.
struct BlockView: View {
    private let block: TaskList.Model.Block
    private let send: (TaskList.UserAction) -> Void

    init(_ block: TaskList.Model.Block, send: @escaping (TaskList.UserAction) -> Void) {
        self.block = block
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = block.header {
                BlockHeaderView(header, send: send)
            }
            ForEach(block.rows) { row in
                BlockRow(row, send: send)
            }
            if let addTask = block.addTask {
                AddRowView(addTask, send: send)
            }
        }
    }
}

/// A row of a block, of the strip or of a column, by its kind: the one switch over a row's kinds, every case drawn and
/// none by `default` (`docs/style.md`, "Views"). In a column, whose style it is given, a row stands on the card's look
/// and an open card, which draws its own surface and shadow, has only the card's hairline round it (`Phone.dc.html`,
/// `.card`).
struct BlockRow: View {
    private let row: TaskList.Model.Row
    private let column: ColumnStyle?
    private let send: (TaskList.UserAction) -> Void

    init(_ row: TaskList.Model.Row, column: ColumnStyle? = nil, send: @escaping (TaskList.UserAction) -> Void) {
        self.row = row
        self.column = column
        self.send = send
    }

    var body: some View {
        switch row {
        case .task(_, let task):
            TaskRowView(task, send: send)
                .modifier(ColumnCardSurface(column: column))
                .modifier(ColumnCardRing(column: column))
        case .card(_, let card):
            TaskCardView(
                card, titleChanged: { .titleFieldChanged($0) }, notesChanged: { .notesFieldChanged($0) },
                subtaskChanged: { .subtaskFieldChanged($0) }, send: send
            )
            .modifier(ColumnCardRing(column: column))
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
