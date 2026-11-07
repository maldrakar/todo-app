import CoreGraphics
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The system drag of the list screen, `RowLift`, driven stage by stage as the screen's drop delegate drives it, over
// the blocks a real `TaskList` draws from a store in memory and the frames a layout of them would report: in the list,
// each stacked from the top with the mark's gap where the slot stands, as the screen draws them; on the board, side by
// side, each column's cards scrolled as far as a test says. Each drop is then sent to the module, which is the
// end-to-end case: the task lands where the slot was drawn, by the module's own reading of the drop.
//
// The list every test starts from: "Projects" of open tasks, its own block with A, B, C and D, then the lists inside
// it, House (a tag) with H1 and H2, Office (a tag) with O1 and O2, Empty (a tag) with nothing, and Either (a rule of
// alternatives) with E1, which takes no drop.

/// The first stage of a drag holds what `onDrag` said it carries, and offers the task's own place until the finger
/// moves.
@Test func aLiftHoldsTheTaskAndBlockItWasDraggedFrom() throws {
    var list = try LiftedList()
    list.press(.began(task: list.h2, block: .list(list.house), session: "first", at: list.centre(of: list.h2, in: .list(list.house))))
    #expect(list.lift?.task == list.h2)
    #expect(list.lift?.source == .list(list.house))
    #expect(list.lift?.slot == RowLift.Slot(block: .list(list.house), after: list.h1))
}

/// A row no longer drawn, gone by a peer's change between the press and the first point, lifts nothing, nor does an
/// open card, which has no lift, so that nothing dims and nothing drops.
@Test func aRowThatCannotBeLiftedLiftsNothing() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: TaskID(), block: own, session: "first", at: .zero))
    #expect(list.lift == nil)
    list.press(.ended)
    #expect(list.drops.isEmpty)
    list.openCard(on: list.a)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    #expect(list.lift == nil)
    list.press(.ended)
    #expect(list.drops.isEmpty)
}

/// Over a row of its own block the slot goes before it in its upper half and after it in its lower, the lifted row
/// itself keeping its place, above the first row at the top and below the last at the end. The gap the mark opens moves
/// the rows under a still finger and does not move the slot.
@Test func aMoveOverARowPicksTheSlotBeforeOrAfterIt() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.b, block: own, session: "first", at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c), "the gap above D moved D down, not the slot")
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d))
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d), "the gap below D moved D up, not the slot")
    list.press(.changed(list.centre(of: list.b, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.a), "over itself, its own place")
    list.press(.changed(list.upperHalf(of: list.a, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil))
    list.press(.changed(CGPoint(x: 10, y: -500)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil), "above the blocks, the first block's top")
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// In another block the module writes no place, a manual list taking the task last and any other standing it by its
/// sort, so wherever the finger is in that block the slot stands at its end.
@Test func aMoveIntoAnotherBlockPicksItsEnd() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let empty = TaskList.Model.BlockID.list(list.empty)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.upperHalf(of: list.o1, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "over its header")
    list.press(.changed(list.top(of: empty)))
    #expect(list.lift?.slot == RowLift.Slot(block: empty, after: nil), "a block with no rows has only its top")
    list.press(.changed(list.lowerHalf(of: list.o2, in: office)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: list.o2)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(Set(list.rowIDs(of: office)) == [list.o1, list.o2, list.h1])
    #expect(list.rowIDs(of: house) == [list.h2])
}

/// Over a block whose rule reads as no edit there is no slot, and a release there drops nothing; moved on, the slot
/// comes back.
@Test func aBlockThatTakesNoDropOffersNoSlot() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let either = TaskList.Model.BlockID.list(list.either)
    #expect(list.block(either)?.takesDrop == false)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)
    #expect(list.lift != nil, "still lifted")
    list.press(.changed(list.centre(of: list.h2, in: house)))
    #expect(list.lift?.slot?.block == house)
    list.press(.changed(list.centre(of: list.e1, in: either)))
    list.press(.ended)
    #expect(list.lift == nil)
    #expect(list.drops.isEmpty)
}

/// The release is one drop, and what the delegate hands after it moves nothing.
@Test func aReleaseSendsOneDrop() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.lowerHalf(of: list.b, in: own)))
    list.press(.ended)
    #expect(list.lift == nil)
    list.press(.ended)
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    list.press(.cancelled)
    #expect(list.lift == nil)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.b)])
}

/// A cancel, the drag leaving the screen's scroll view, drops nothing and clears the lift, which is all a drag
/// cancelled outside it ever says; come back, the drag lifts again and can still drop.
@Test func aCancelDropsNothing() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.lowerHalf(of: list.b, in: own)))
    list.press(.cancelled)
    #expect(list.lift == nil)
    #expect(list.drops.isEmpty)
    list.press(.began(task: list.a, block: own, session: "first", at: list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.c)])
}

/// On the board the point picks the column under it, the nearest in a gap or a margin, whatever its height, a column
/// that takes no drop offering none; in another column at its end, and in its own among the cards in sight: a card
/// scrolled out of its column keeps a frame, under the column's header, and is never the one under the finger.
@Test func aMoveOverAColumnPicksTheColumn() throws {
    var list = try LiftedList(columns: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let either = TaskList.Model.BlockID.list(list.either)
    list.press(.began(task: list.b, block: own, session: "first", at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.centre(of: list.h1, in: house)))
    #expect(list.lift?.slot == RowLift.Slot(block: house, after: list.h2))
    list.press(.changed(CGPoint(x: list.columnFrame(of: house).maxX + 1, y: 5_000)))
    #expect(list.lift?.slot == RowLift.Slot(block: house, after: list.h2), "in the gap after it and below its end")
    list.press(.changed(list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)

    list.scrollColumn(own, by: 200)
    let hidden = list.centre(of: list.c, in: own)
    let area = list.visibleArea(of: own)
    #expect(hidden.y < area.minY, "C's frame lies under the header")
    list.press(.changed(hidden))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil), "over the header, the top")
    list.press(.changed(CGPoint(x: area.midX, y: area.maxY + 1)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d), "under the cards in sight, the end")
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// A task two blocks draw has a row in each, and each has its own frame: lifted from one, it reorders by that one's
/// frames, and dropped in a third it leaves only the block it was dragged from.
@Test func aTaskTwoBlocksDrawLeavesOnlyTheOneItWasDraggedFrom() throws {
    var list = try LiftedList(taskInHouseAndOffice: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let empty = TaskList.Model.BlockID.list(list.empty)
    let both = try #require(list.both)
    #expect(list.rowIDs(of: house).contains(both) && list.rowIDs(of: office).contains(both))
    let rows = list.frames.rows
    #expect(rows[BlockRowID(block: house, task: both)] != rows[BlockRowID(block: office, task: both)])

    list.press(.began(task: both, block: office, session: "first", at: list.centre(of: both, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "its place in the block it was lifted from")
    list.press(.changed(list.upperHalf(of: list.o2, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o1))
    list.press(.cancelled)

    list.press(.began(task: both, block: house, session: "first", at: list.centre(of: both, in: house)))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "not after its own row there")
    list.press(.changed(list.top(of: empty)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(both, from: house, in: empty, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(!list.rowIDs(of: house).contains(both))
    #expect(list.rowIDs(of: office).contains(both))
    #expect(list.rowIDs(of: empty) == [both])
}

/// A folded block has no rows and still takes a drop: its only place is its top, the mark standing under its header, and
/// the fold stays.
@Test func aFoldedBlockTakesADropAtItsTop() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.toggleFold(of: office)
    #expect(list.rowIDs(of: office).isEmpty)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: nil))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: house) == [list.h2])
    #expect(list.rowIDs(of: office).isEmpty, "the fold stays")
    list.toggleFold(of: office)
    #expect(list.rowIDs(of: office).contains(list.h1))
}

/// A block that takes no drop takes none of its own rows either, so a row lifted from it has nowhere to go in it: no slot
/// over itself, and a release drops nothing.
@Test func aRowLiftedFromABlockThatTakesNoDropHasNoSlotInIt() throws {
    var list = try LiftedList()
    let either = TaskList.Model.BlockID.list(list.either)
    let house = TaskList.Model.BlockID.list(list.house)
    list.press(.began(task: list.e1, block: either, session: "first", at: list.centre(of: list.e1, in: either)))
    #expect(list.lift?.task == list.e1)
    #expect(list.lift?.slot == nil)
    list.press(.changed(list.upperHalf(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)
    list.press(.changed(list.top(of: house)))
    #expect(list.lift?.slot?.block == house, "another block takes it")
    list.press(.changed(list.upperHalf(of: list.e1, in: either)))
    list.press(.ended)
    #expect(list.drops.isEmpty)
}

// MARK: - The drag's session

/// A second finger pressing another row during a drag asks `onDrag` again, which begins a session of its own: the first
/// finger's drag goes on with its own task, the second's calls move nothing, and the release drops the task it lifted.
@Test func aSecondPressDuringADragLeavesItsTask() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    var sessions = RowDragSessions()
    let first = sessions.begin(BlockRowID(block: own, task: list.a))
    list.hear(.moved(list.centre(of: list.a, in: own)), session: first, in: sessions)
    #expect(list.lift?.task == list.a)
    let second = sessions.begin(BlockRowID(block: own, task: list.d))
    list.hear(.moved(list.lowerHalf(of: list.b, in: own)), session: first, in: sessions)
    #expect(list.lift?.task == list.a)
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.b))
    list.hear(.moved(list.upperHalf(of: list.c, in: own)), session: second, in: sessions)
    #expect(list.lift?.task == list.a, "the other session's call moves nothing")
    list.hear(.released, session: second, in: sessions)
    #expect(list.lift?.task == list.a, "nor does its release")
    list.hear(.left, session: second, in: sessions)
    #expect(list.lift?.task == list.a, "nor its leaving")
    #expect(list.drops.isEmpty)
    list.hear(.released, session: first, in: sessions)
    #expect(list.lift == nil)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.b)])
}

/// A session this screen did not begin, another window's drag of the private type, or no session, lifts nothing and
/// drops nothing: what a press left behind in this screen's sessions is not what it carries.
@Test func aSessionThisScreenDidNotBeginLiftsNothing() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    var sessions = RowDragSessions()
    _ = sessions.begin(BlockRowID(block: own, task: list.a))
    list.hear(.moved(list.centre(of: list.b, in: own)), session: "another window's", in: sessions)
    #expect(list.lift == nil)
    list.hear(.moved(list.centre(of: list.b, in: own)), session: nil, in: sessions)
    #expect(list.lift == nil)
    list.hear(.released, session: "another window's", in: sessions)
    #expect(list.drops.isEmpty)
}

/// Its session outlives a lift that ended with no release: a drag that left the scroll view, or went quiet, lifts again
/// at its next call and can still drop, since its session is what rescues the drop.
@Test func aSessionOutlivesALiftThatEndedWithNoRelease() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    var sessions = RowDragSessions()
    let session = sessions.begin(BlockRowID(block: own, task: list.a))
    list.hear(.moved(list.centre(of: list.a, in: own)), session: session, in: sessions)
    list.hear(.left, session: session, in: sessions)
    #expect(list.lift == nil)
    list.hear(.moved(list.lowerHalf(of: list.c, in: own)), session: session, in: sessions)
    #expect(list.lift?.task == list.a)
    list.press(.cancelled)
    #expect(list.lift == nil, "gone quiet")
    list.hear(.moved(list.lowerHalf(of: list.b, in: own)), session: session, in: sessions)
    list.hear(.released, session: session, in: sessions)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.b)])
}

/// A session is forgotten once its drop is made, and so are those of presses that opened a menu and never dragged.
@Test func aDropForgetsTheSessions() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    var sessions = RowDragSessions()
    let press = sessions.begin(BlockRowID(block: own, task: list.d))
    let session = sessions.begin(BlockRowID(block: own, task: list.a))
    list.hear(.moved(list.centre(of: list.a, in: own)), session: session, in: sessions)
    list.hear(.released, session: session, in: sessions)
    sessions.forget()
    list.hear(.moved(list.centre(of: list.b, in: own)), session: session, in: sessions)
    list.hear(.moved(list.centre(of: list.b, in: own)), session: press, in: sessions)
    #expect(list.lift == nil)
}
