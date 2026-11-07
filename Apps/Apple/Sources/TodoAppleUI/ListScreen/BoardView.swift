// Apps/Apple/Sources/TodoAppleUI/ListScreen/BoardView.swift
import SwiftUI
import TaskListFeature

/// The list's blocks as the board's columns as its model describes them (`TaskList.Model.Board`; `Phone.dc.html`,
/// `.board`): a `ScrollView` sideways, snapping to a column where the model says so, its columns as high as it is,
/// and after them the dashed "+ Add list" at the height of its own button (`.bcol`'s `align-self`).
struct BoardView: View {
    private let board: TaskList.Model.Board
    private let gestures: ScreenGestures
    private let send: (TaskList.UserAction) -> Void

    init(_ board: TaskList.Model.Board, gestures: ScreenGestures, send: @escaping (TaskList.UserAction) -> Void) {
        self.board = board
        self.gestures = gestures
        self.send = send
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: board.spacing) {
                ForEach(board.columns) { block in
                    if let column = block.column {
                        ColumnView(
                            block, column: column, isDragOver: gestures.lift?.slot?.block == block.id,
                            gestures: gestures, send: send
                        )
                    }
                }
                if let addList = board.addList {
                    AddRowView(addList, send: send)
                }
            }
            .scrollTargetLayout()
            .padding(.trailing, board.endRoom)
            .modifier(rowDragContent)
            // At the top of the scroll view whatever it holds, which would centre what is shorter than itself.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .contentMargins(.horizontal, board.horizontalPadding, for: .scrollContent)
        .contentMargins(.bottom, board.bottomPadding, for: .scrollContent)
        .scrollIndicators(.hidden)
        .modifier(Snapping(snaps: board.snaps))
    }

    /// The board's content as the space a drag finds its place in.
    private var rowDragContent: RowDragContent {
        // iOS alone: its finder is UIKit's.
        #if os(iOS)
        RowDragContent(space: gestures.space, finder: ScrollContentFinder(space: gestures.space))
        #else
        RowDragContent(space: gestures.space)
        #endif
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
