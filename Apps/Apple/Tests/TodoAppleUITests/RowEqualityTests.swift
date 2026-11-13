import DesignSystemComponents
import SwiftUI
import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// When a row of the list screen skips its body: `BlockRow` and `TaskRowView` compare what they draw from, and never the
// closures they are handed, which reach the same screen's `send` whichever pass made them and are new every pass
// (#196). The rows are the ones a real `TaskList` draws (`LiftedList`); a lift is one its drag made.

/// A row of the list's own block, by its task.
private func row(_ task: TaskID, of list: LiftedList) throws -> TaskList.Model.Row {
    try #require(list.block(.own(nil))?.rows.first { $0.id == task })
}

/// A task's row's model.
private func model(of row: TaskList.Model.Row) throws -> TaskRowModel<TaskList.UserAction> {
    guard case .task(_, let model) = row else { throw RowEqualityTestError.notATask }
    return model
}

/// The same task's row with another title.
private func renamed(_ row: TaskList.Model.Row) throws -> TaskList.Model.Row {
    let old = try model(of: row)
    let title = TextModel(text: old.title.text + " renamed", style: old.title.style)
    return .task(row.id, TaskRowModel(
        check: old.check, title: title, meta: old.meta, style: old.style, swipe: old.swipe, tap: old.tap, menu: old.menu
    ))
}

private enum RowEqualityTestError: Error {
    case notATask
}

/// What a screen's gestures stand at, with the lift and the row a copy settles onto given and a Delete made anew, as
/// every pass makes it.
@MainActor private func screenGestures(
    lift: RowLift? = nil, settling: BlockRowID? = nil, dragState: RowDragState, swipe: ScreenSwipe
) -> RowGestures {
    RowGestures(lift: lift, settling: settling, dragState: dragState, swipe: swipe, delete: { _ in })
}

/// A row of a block as a pass of its block draws it, with a `send` made anew.
@MainActor private func drawn(
    _ row: TaskList.Model.Row, in block: TaskList.Model.BlockID, column: ColumnStyle? = nil, _ gestures: RowGestures
) -> BlockRow {
    BlockRow(row, in: block, column: column, gestures: gestures, send: { _ in })
}

/// Two rows equal in all they draw from are equal whatever their `send` and their gestures' Delete, each a closure made
/// anew by the pass that drew it.
@Test @MainActor func aRowIsEqualWhateverItsSendAndItsDelete() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let dragState = RowDragState()
    let swipe = ScreenSwipe()
    let first = screenGestures(dragState: dragState, swipe: swipe)
    let second = screenGestures(dragState: dragState, swipe: swipe)
    #expect(drawn(a, in: .own(nil), first) == drawn(a, in: .own(nil), second))
}

/// A row whose model changed, its title here, is another row.
@Test @MainActor func aRowWhoseModelChangedIsAnother() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let gestures = screenGestures(dragState: RowDragState(), swipe: ScreenSwipe())
    #expect(drawn(a, in: .own(nil), gestures) != drawn(try renamed(a), in: .own(nil), gestures))
}

/// The same row in another block, as a task two blocks draw has, is another row.
@Test @MainActor func theSameRowInAnotherBlockIsAnother() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let gestures = screenGestures(dragState: RowDragState(), swipe: ScreenSwipe())
    #expect(drawn(a, in: .own(nil), gestures) != drawn(a, in: .list(list.house), gestures))
}

/// A row drawn on another column's look, or on none, is another row: the phone's column against the pane's, and a
/// column's card against a list's row.
@Test @MainActor func aRowOnAnotherColumnsLookIsAnother() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let phone = try #require(try LiftedList(columns: true).block(.own(nil))?.column?.style)
    let pane = try #require(try LiftedList(columns: true, pane: true).block(.own(nil))?.column?.style)
    #expect(phone != pane)
    let gestures = screenGestures(dragState: RowDragState(), swipe: ScreenSwipe())
    #expect(drawn(a, in: .own(nil), column: phone, gestures) != drawn(a, in: .own(nil), column: pane, gestures))
    #expect(drawn(a, in: .own(nil), column: phone, gestures) != drawn(a, in: .own(nil), gestures))
}

/// The lift is drawn by the row it lifts alone: that row is another once it is lifted, and every other row stays
/// equal, the same task's row in another block among them, as the lifted one does while the lift only moves its slot.
@Test @MainActor func aLiftChangesTheRowItLiftsAloneAndASlotNone() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let a = try row(list.a, of: list)
    let b = try row(list.b, of: list)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    let lifted = try #require(list.lift)
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    let moved = try #require(list.lift)
    #expect(lifted.slot != moved.slot)
    let dragState = RowDragState()
    let swipe = ScreenSwipe()
    let none = screenGestures(dragState: dragState, swipe: swipe)
    let atFirst = screenGestures(lift: lifted, dragState: dragState, swipe: swipe)
    let atNext = screenGestures(lift: moved, dragState: dragState, swipe: swipe)

    #expect(drawn(a, in: own, none) != drawn(a, in: own, atFirst))
    #expect(drawn(a, in: own, atFirst) == drawn(a, in: own, atNext), "its slot moved")
    #expect(drawn(b, in: own, none) == drawn(b, in: own, atFirst), "another row lifted")
    #expect(drawn(b, in: own, atFirst) == drawn(b, in: own, atNext), "another row's slot moved")
    #expect(drawn(a, in: house, none) == drawn(a, in: house, atFirst), "the task lifted from another block")
}

/// The row a dropped copy settles onto is drawn by that row alone, hidden under the copy: it is another row while the
/// copy settles, and every other row stays equal, the same task's row in another block among them (#211).
@Test @MainActor func aCopySettlingChangesTheRowItSettlesOntoAlone() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let a = try row(list.a, of: list)
    let b = try row(list.b, of: list)
    let dragState = RowDragState()
    let swipe = ScreenSwipe()
    let none = screenGestures(dragState: dragState, swipe: swipe)
    let settling = screenGestures(settling: BlockRowID(block: own, task: list.a), dragState: dragState, swipe: swipe)
    #expect(drawn(a, in: own, none) != drawn(a, in: own, settling))
    #expect(drawn(b, in: own, none) == drawn(b, in: own, settling), "another row settles")
    #expect(drawn(a, in: house, none) == drawn(a, in: house, settling), "the task settles in another block")
}

/// A row is drawn with its screen's drag and swipe, one instance of each for the screen's life: another instance is
/// another screen's, and another row.
@Test @MainActor func aRowWithAnotherDragOrSwipeIsAnother() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let dragState = RowDragState()
    let swipe = ScreenSwipe()
    let gestures = screenGestures(dragState: dragState, swipe: swipe)
    let anotherDrag = screenGestures(dragState: RowDragState(), swipe: swipe)
    let anotherSwipe = screenGestures(dragState: dragState, swipe: ScreenSwipe())
    #expect(drawn(a, in: .own(nil), gestures) != drawn(a, in: .own(nil), anotherDrag))
    #expect(drawn(a, in: .own(nil), gestures) != drawn(a, in: .own(nil), anotherSwipe))
}

/// A row of the strip, which has no block and no gestures and is never lifted, is equal by its row whatever its
/// `send`, and is never a block's row.
@Test @MainActor func aRowOfTheStripIsEqualByItsRow() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let b = try row(list.b, of: list)
    #expect(BlockRow(a, send: { _ in }) == BlockRow(a, send: { _ in }))
    #expect(BlockRow(a, send: { _ in }) != BlockRow(b, send: { _ in }))
    let gestures = screenGestures(dragState: RowDragState(), swipe: ScreenSwipe())
    #expect(BlockRow(a, send: { _ in }) != drawn(a, in: .own(nil), gestures))
}

/// A task's row is drawn from its model alone, and is equal by it whatever its `send`.
@Test @MainActor func aTaskRowIsEqualByItsModel() throws {
    let list = try LiftedList()
    let a = try row(list.a, of: list)
    let face = try model(of: a)
    let other = try model(of: renamed(a))
    #expect(TaskRowView(face, send: { _ in }) == TaskRowView(face, send: { _ in }))
    #expect(TaskRowView(face, send: { _ in }) != TaskRowView(other, send: { _ in }))
}
