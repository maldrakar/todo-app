// Apps/Apple/Sources/TodoAppleUI/ListScreen/ColumnView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A block as a column of the board as its model describes it (`ColumnModel`; `Phone.dc.html`, `.bcol`): its header,
/// which stays, over its cards and "+ Add task", which scroll on their own, all of it on the column's fill as high as
/// the board. A column's cards are the block's rows drawn in the card's look (`BlockRow`).
struct ColumnView: View {
    private let block: TaskList.Model.Block
    private let column: ColumnModel<TaskList.UserAction>
    private let send: (TaskList.UserAction) -> Void

    init(
        _ block: TaskList.Model.Block, column: ColumnModel<TaskList.UserAction>,
        send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.block = block
        self.column = column
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockHeaderView(column.header, send: send)
            ScrollView {
                VStack(alignment: .leading, spacing: column.style.cardSpacing) {
                    ForEach(block.rows) { row in
                        BlockRow(row, column: column.style, send: send)
                    }
                    if let addTask = block.addTask {
                        AddRowView(addTask, send: send)
                    }
                }
                .padding(.horizontal, column.style.padding)
                .padding(.bottom, column.style.padding)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: column.style.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            Color(column.style.fill), in: .rect(cornerRadius: column.style.cornerRadius, style: .circular)
        )
    }
}
