// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowDrag.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A row's or a column's closed card's menu and drag, both only where its model gives it a menu and a lift, which the
/// module gives together: while it is lifted the row it was dragged from dims to its lift's opacity on the lift's
/// motion. On iOS the menu and the drag are the system's, paired (spike #174, y1, the owner's choice): a still press
/// opens the menu, and a move after the press drags. They stand on the screen's scroll view, which finds the row under
/// the finger (`RowSystemDrag`, #211), so that the dragged copy keeps its size, which SwiftUI's drag cannot. On the Mac
/// the menu is the secondary click's, sending what `delete` does, on its way out, and the drag is the pointer's, on the
/// content (`RowPointerDrag`), which dims the row as the system's drag does. The watch has neither.
struct RowDragSource: ViewModifier {
    private let task: TaskRowModel<TaskList.UserAction>
    private let row: BlockRowID
    private let gestures: RowGestures
    private let delete: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ task: TaskRowModel<TaskList.UserAction>, row: BlockRowID, gestures: RowGestures,
        delete: @escaping (TaskList.UserAction) -> Void
    ) {
        self.task = task
        self.row = row
        self.gestures = gestures
        self.delete = delete
    }

    func body(content: Content) -> some View {
        if task.menu != nil, let lift = task.style.lift {
            let isLifted = gestures.isLifted(row)
            content
                #if os(macOS)
                .contextMenu { task.menu.map { MenuItems($0, send: delete) } }
                #endif
                // The opacity alone: over the whole row, a drop's own end of the lift carried the row to its place on
                // this motion, over the rows that had already moved (the iOS 26.3 simulator, 2026-11-07).
                .animation(reduceMotion ? nil : Animation(lift.dimAnimation)) { row in
                    row.opacity(isLifted ? lift.opacity : 1)
                }
        } else {
            content
        }
    }
}

/// What a lifted copy's words stand on: the lift's background within its corners, under the copy the system's drag
/// carries on iOS (`RowDragCopy`) and the one under the Mac's pointer (`RowPointerDrag`).
struct LiftGround: View {
    private let lift: TaskLiftStyle

    init(_ lift: TaskLiftStyle) {
        self.lift = lift
    }

    var body: some View {
        RoundedRectangle(cornerRadius: lift.cornerRadius, style: .circular)
            .fill(Color(lift.background))
    }
}

// iOS alone: the system's drag carries a picture of the copy, which the Mac's pointer drag draws as a view.
#if os(iOS)
/// The copy of the row the system's drag carries (`RowSystemDrag`), on the lift's ground (`LiftGround`), as wide as the
/// row stands: alone it would stand as wide as its title on one line. A view of its own, so that the width is read when
/// the copy is drawn, by when the row has laid out.
struct RowDragCopy: View {
    let task: TaskRowModel<TaskList.UserAction>
    let lift: TaskLiftStyle
    let row: BlockRowID
    let dragState: RowDragState

    var body: some View {
        TaskRowView(task, send: { _ in })
            .frame(width: dragState.frames.rows[row]?.width)
            .background { LiftGround(lift) }
    }
}
#endif

/// The scroll view of the list or the board as what the Mac's pointer drag reads of it: the space the content's place
/// is read in and how large it is, which say what of the content is in sight, where a drop can land
/// (`RowDragState.viewport`). The drag itself is the pointer's, on the content (`RowPointerDrag`). iOS's drag reads its
/// points in the content through UIKit (`RowSystemDrag`), and the watch has none, so on both it adds nothing.
struct RowDragViewport: ViewModifier {
    private let dragState: RowDragState

    init(dragState: RowDragState) {
        self.dragState = dragState
    }

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .coordinateSpace(.named(RowLift.viewportSpace))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [dragState] size in
                dragState.viewportSize = size
            }
        #else
        content
        #endif
    }
}
