// Apps/Apple/Sources/TodoAppleUI/ListScreen/BoardView.swift
import SwiftUI
import TaskListFeature

/// The list's blocks as the board's columns as its model describes them (`TaskList.Model.Board`; `Phone.dc.html`,
/// `.board`): a `ScrollView` sideways, snapping to a column where the model says so, its columns as high as it is,
/// and after them the dashed "+ Add list" at the height of its own button (`.bcol`'s `align-self`).
struct BoardView: View {
    private let board: TaskList.Model.Board
    private let send: (TaskList.UserAction) -> Void

    init(_ board: TaskList.Model.Board, send: @escaping (TaskList.UserAction) -> Void) {
        self.board = board
        self.send = send
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: board.spacing) {
                ForEach(board.columns) { block in
                    if let column = block.column {
                        // Nothing is dragged yet: the drag arrives with the screen's gestures (list screen plan, Task
                        // 8).
                        ColumnView(block, column: column, isDragOver: false, send: send)
                    }
                }
                if let addList = board.addList {
                    AddRowView(addList, send: send)
                }
            }
            .scrollTargetLayout()
            .padding(.trailing, board.endRoom)
            // At the top of the scroll view whatever it holds, which would centre what is shorter than itself.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .contentMargins(.horizontal, board.horizontalPadding, for: .scrollContent)
        .contentMargins(.bottom, board.bottomPadding, for: .scrollContent)
        .scrollIndicators(.hidden)
        .modifier(Snapping(snaps: board.snaps))
        // The columns end above the screen's bottom and not above the safe area's (`.board`'s padding), and the
        // keyboard still shortens them, its region not ignored.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// The snap to a column, and none where the board scrolls freely, whose two behaviours have different types.
    private struct Snapping: ViewModifier {
        let snaps: Bool

        func body(content: Content) -> some View {
            if snaps {
                content.scrollTargetBehavior(.viewAligned)
            } else {
                content
            }
        }
    }
}
