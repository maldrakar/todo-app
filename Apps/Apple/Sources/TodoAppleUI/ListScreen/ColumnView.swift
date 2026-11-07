// Apps/Apple/Sources/TodoAppleUI/ListScreen/ColumnView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A block as a column of the board as its model describes it (`ColumnModel`; `Phone.dc.html`, `.bcol`): its header,
/// which stays, over its cards and "+ Add task", which scroll on their own, all of it on the column's fill as high as
/// the board. A column's cards are the block's rows drawn in the card's look (`BlockRow`). While a card dragged over it
/// would land in it, which only the drag knows, it takes the block's tint and a ring inside its edge, on its motion.
struct ColumnView: View {
    private let block: TaskList.Model.Block
    private let column: ColumnModel<TaskList.UserAction>
    private let isDragOver: Bool
    private let gestures: RowGestures
    private let send: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ block: TaskList.Model.Block, column: ColumnModel<TaskList.UserAction>, isDragOver: Bool,
        gestures: RowGestures, send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.block = block
        self.column = column
        self.isDragOver = isDragOver
        self.gestures = gestures
        self.send = send
    }

    var body: some View {
        let isTinted = isDragOver && column.isDropTarget
        let motion = reduceMotion ? nil : Animation(column.style.dropAnimation)
        VStack(alignment: .leading, spacing: 0) {
            BlockHeaderView(column.header, send: send)
            ScrollView {
                VStack(alignment: .leading, spacing: column.style.cardSpacing) {
                    ForEach(block.rows) { row in
                        BlockRow(row, in: block.id, column: column.style, gestures: gestures, send: send)
                    }
                    if let addTask = block.addTask {
                        AddRowView(addTask, send: send)
                    }
                }
                .padding(.horizontal, column.style.padding)
                .padding(.bottom, column.style.padding)
            }
            .scrollIndicators(.hidden)
            // What of its cards is in sight, since a card scrolled out of it keeps a frame under its header.
            .reportsLiftFrame(\.columns, block.id, to: gestures.dragState)
        }
        .frame(width: column.style.width)
        .frame(maxHeight: .infinity, alignment: .top)
        // On the tint and the ring alone: over the whole column, a drop's own change of the tint moved its cards on
        // that motion, and the one landing faded in as well as sprang (the iOS 26.3 simulator, 2026-11-07).
        .background {
            RoundedRectangle(cornerRadius: column.style.cornerRadius, style: .circular)
                .fill(Color(isTinted ? column.style.dropTint : column.style.fill))
                .animation(motion, value: isTinted)
        }
        .overlay {
            RoundedRectangle(cornerRadius: column.style.cornerRadius, style: .circular)
                .strokeBorder(Color(column.style.dropRing), lineWidth: column.style.dropRingWidth)
                .opacity(isTinted ? 1 : 0)
                .animation(motion, value: isTinted)
                .allowsHitTesting(false)
        }
        .reportsLiftFrame(\.blocks, block.id, to: gestures.dragState)
    }
}
