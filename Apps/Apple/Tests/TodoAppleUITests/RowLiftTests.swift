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

/// The first stage of a drag holds what the drag's item said it carries, and offers the task's own place until the
/// finger moves.
@Test func aLiftHoldsTheTaskAndBlockItWasDraggedFrom() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    list.press(.began(task: list.h2, block: house, session: "first", at: list.centre(of: list.h2, in: house)))
    #expect(list.lift?.task == list.h2)
    #expect(list.lift?.source == house)
    #expect(list.lift?.session == "first")
    #expect(list.lift?.slot == .place(house, after: list.h1))
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
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c), "the gap above D moved D down, not the slot")
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.d))
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.d), "the gap below D moved D up, not the slot")
    list.press(.changed(list.centre(of: list.b, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.a), "over itself, its own place")
    list.press(.changed(list.upperHalf(of: list.a, in: own)))
    #expect(list.lift?.slot == .place(own, after: nil))
    list.press(.changed(CGPoint(x: 10, y: -500)))
    #expect(list.lift?.slot == .place(own, after: nil), "above the blocks, the first block's top")
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// In another block the module writes no place, a manual list taking the task last and any other standing it by its
/// order, so wherever the finger is in that block the slot is the block, which its tint marks, and the drop names no
/// row (the owner's review of #177, 2026-11-08).
@Test func aMoveIntoAnotherBlockPicksTheBlock() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let empty = TaskList.Model.BlockID.list(list.empty)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.upperHalf(of: list.o1, in: office)))
    #expect(list.lift?.slot == .into(office))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == .into(office), "over its header")
    list.press(.changed(list.top(of: empty)))
    #expect(list.lift?.slot == .into(empty), "and a block with no rows")
    list.press(.changed(list.lowerHalf(of: list.o2, in: office)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
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
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.c)])
}

/// A list's block is no column, whatever a board left in the frames: back from Columns the slot goes by the rows'
/// middles, above and below the area its column was seen through.
@Test func aListReadsNoAreaABoardLeftInTheFrames() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.leaveColumnArea(of: own, CGRect(x: 0, y: 60, width: 296, height: 20))
    list.press(.began(task: list.b, block: own, session: "first", at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c), "below the area")
    list.press(.changed(list.lowerHalf(of: list.a, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.a), "above the area")
}

/// A block's upper rows a lazy stack never laid out, after a jump and not a finger's scroll, have reported no frame,
/// and the slot is still read by the rows at the point: after the row whose middle is nearest above it, and before
/// the one nearest below it, after the row before that one in the block, laid out or not.
@Test func aBlockWhoseUpperRowsWereNeverLaidOutPlacesByTheRowsAtThePoint() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.leaveNotLaidOut(list.a, in: own)
    list.leaveNotLaidOut(list.b, in: own)
    list.press(.began(task: list.d, block: own, session: "first", at: list.centre(of: list.d, in: own)))
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.press(.changed(list.upperHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.b), "before C, after B though B has no frame")
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.d, from: own, in: own, after: list.b)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: own) == [list.a, list.b, list.d, list.c])
}

/// A later row out of sight keeps the frame it was last laid out at, which a change above it may have left far from
/// where it now stands: far above the point, it does not take the slot from the rows at the point.
@Test func aRowsFrameLeftOutOfSightDoesNotTakeTheSlot() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.leaveFrame(of: list.d, in: own, at: CGRect(x: 0, y: -2_000, width: 400, height: 44))
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.press(.changed(list.upperHalf(of: list.b, in: own)))
    #expect(list.lift?.slot == .place(own, after: nil), "before B, the block's top, A being lifted")
}

/// A layout that is gone leaves no frame behind: a card of the board and a row of the list are one row to the frames,
/// so back from Columns a row the list's lazy stack has not laid out kept its card's frame, and one near the point took
/// the slot from the rows under the finger. The frames forget everything as the layout's shape changes, the parts of
/// an earlier list and the tint's frame among it, and the slot is read by the rows the list has laid out alone.
@MainActor @Test func aLayoutThatIsGoneLeavesNoFrameForTheNextToRead() throws {
    var list = try LiftedList(columns: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    list.scrollColumn(own, by: 210)
    let dragState = RowDragState()
    dragState.report(.add, of: own, CGRect(x: 0, y: 900, width: 400, height: 40))
    let board = list.frames
    dragState.frames.rows = board.rows
    dragState.frames.blocks = board.blocks
    dragState.frames.columns = board.columns
    dragState.watch(.into(house))
    #expect(dragState.frames.rows[BlockRowID(block: own, task: list.d)]?.midY == 68, "D's card, under the finger")
    #expect(dragState.tint.frame(of: house) == board.blocks[house])

    list.showAs(.list)
    dragState.forgetLayout()
    #expect(dragState.frames.rows.isEmpty)
    #expect(dragState.frames.blocks.isEmpty)
    #expect(dragState.frames.columns.isEmpty)
    #expect(dragState.tint.frame(of: house) == nil)

    list.leaveNotLaidOut(list.c, in: own)
    list.leaveNotLaidOut(list.d, in: own)
    for (row, frame) in list.frames.rows where row.block == own {
        dragState.frames.rows[row] = frame
        dragState.report(.row(row.task), of: own, frame)
    }
    #expect(dragState.frames.blocks[own] == CGRect(x: 0, y: 0, width: 400, height: 88), "A and B, the rows laid out")
    let blocks = list.blocks
    let lifted = RowLift.after(
        .began(task: list.a, block: own, session: "first", at: CGPoint(x: 200, y: 22)), from: nil, among: blocks,
        frames: dragState.frames
    ).lift
    let moved = RowLift.after(.changed(CGPoint(x: 200, y: 77)), from: lifted, among: blocks, frames: dragState.frames)
    #expect(moved.lift?.slot == .place(own, after: list.b), "B's lower half, and not after D by its card's frame")
}

/// On the board the point picks the column under it, the nearest in a gap or a margin, whatever its height, a column
/// that takes no drop offering none; another column itself, and in its own a place among the cards in sight: a card
/// scrolled out of its column keeps a frame, under the column's header, and is never the one under the finger.
@Test func aMoveOverAColumnPicksTheColumn() throws {
    var list = try LiftedList(columns: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let either = TaskList.Model.BlockID.list(list.either)
    list.press(.began(task: list.b, block: own, session: "first", at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.centre(of: list.h1, in: house)))
    #expect(list.lift?.slot == .into(house))
    list.press(.changed(CGPoint(x: list.columnFrame(of: house).maxX + 1, y: 5_000)))
    #expect(list.lift?.slot == .into(house), "in the gap after it and below its end")
    list.press(.changed(list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)

    list.scrollColumn(own, by: 200)
    let hidden = list.centre(of: list.c, in: own)
    let area = list.visibleArea(of: own)
    #expect(hidden.y < area.minY, "C's frame lies under the header")
    list.press(.changed(hidden))
    #expect(list.lift?.slot == .place(own, after: nil), "over the header, the top")
    list.press(.changed(CGPoint(x: area.midX, y: area.maxY + 1)))
    #expect(list.lift?.slot == .place(own, after: list.d), "under the cards in sight, the end")
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
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
    #expect(list.lift?.slot == .place(office, after: list.o2), "its place in the block it was lifted from")
    list.press(.changed(list.upperHalf(of: list.o2, in: office)))
    #expect(list.lift?.slot == .place(office, after: list.o1))
    list.press(.cancelled)

    list.press(.began(task: both, block: house, session: "first", at: list.centre(of: both, in: house)))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == .into(office), "another block, though it draws the task too")
    list.press(.changed(list.top(of: empty)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(both, from: house, in: empty, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(!list.rowIDs(of: house).contains(both))
    #expect(list.rowIDs(of: office).contains(both))
    #expect(list.rowIDs(of: empty) == [both])
}

/// A folded block has no rows and still takes a drop, as another block does, and the fold stays.
@Test func aFoldedBlockTakesADrop() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.toggleFold(of: office)
    #expect(list.rowIDs(of: office).isEmpty)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == .into(office))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: house) == [list.h2])
    #expect(list.rowIDs(of: office).isEmpty, "the fold stays")
    list.toggleFold(of: office)
    #expect(list.rowIDs(of: office).contains(list.h1))
}

/// A block that keeps no dropped place, a list inside whose tasks are in groups, offers no place to a task dragged
/// within it, since the task would keep to its own group wherever it was let go: no slot there, and a release drops
/// nothing. Another block still takes it, and a block with one group of rows keeps the place (the owner's review of
/// #177, 2026-11-08).
@Test func aBlockThatKeepsNoDroppedPlaceOffersNoPlaceInIt() throws {
    var list = try LiftedList(officeByDay: true)
    let office = TaskList.Model.BlockID.list(list.office)
    let house = TaskList.Model.BlockID.list(list.house)
    #expect(list.block(office)?.keepsDroppedPlace == false)
    #expect(list.block(house)?.keepsDroppedPlace == true)
    list.press(.began(task: list.o1, block: office, session: "first", at: list.centre(of: list.o1, in: office)))
    #expect(list.lift?.task == list.o1)
    #expect(list.lift?.slot == nil)
    list.press(.changed(list.lowerHalf(of: list.o2, in: office)))
    #expect(list.lift?.slot == nil)
    list.press(.changed(list.top(of: house)))
    #expect(list.lift?.slot == .into(house), "another block takes it")
    list.press(.changed(list.lowerHalf(of: list.o2, in: office)))
    list.press(.ended)
    #expect(list.drops.isEmpty)
    list.press(.began(task: list.h1, block: house, session: "first", at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.lowerHalf(of: list.h2, in: house)))
    #expect(list.lift?.slot == .place(house, after: list.h2))
    list.press(.changed(list.centre(of: list.o1, in: office)))
    #expect(list.lift?.slot == .into(office), "and it takes a task from elsewhere")
}

/// A block that takes no drop takes none of its own rows either, so a row lifted from it has nowhere to go in it: no
/// slot over itself, and a release drops nothing.
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

/// A second finger pressing another row during a drag begins a drag and a session of its own: the first finger's drag
/// goes on with its own task, the second's calls move nothing, and the release drops the task it lifted.
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
    #expect(list.lift?.slot == .place(own, after: list.b))
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

/// Its session outlives a lift that ended with no release: a drag that left the scroll view, or whose lift was put down
/// otherwise, lifts again at its next call and can still drop, since its session is what rescues the drop.
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

// MARK: - A list's block's frame

/// A list's block stands in a lazy stack as its parts, its header, each row and its "+ Add task", each of which reports
/// its frame: the block's frame is the union of its parts' last frames, a part reported again replacing its old one.
@Test func aBlocksFrameIsTheUnionOfItsParts() {
    var frames = RowLift.Frames()
    let own = TaskList.Model.BlockID.own(nil)
    let task = TaskID()
    frames.report(.header, of: own, CGRect(x: 0, y: 100, width: 400, height: 44))
    frames.report(.row(task), of: own, CGRect(x: 0, y: 1_000, width: 400, height: 44))
    #expect(frames.blocks[own] == CGRect(x: 0, y: 100, width: 400, height: 944))
    frames.report(.row(task), of: own, CGRect(x: 0, y: 144, width: 400, height: 44))
    #expect(frames.blocks[own] == CGRect(x: 0, y: 100, width: 400, height: 88), "the row's old frame replaced")
    frames.report(.add, of: own, CGRect(x: 0, y: 188, width: 400, height: 40))
    #expect(frames.blocks[own] == CGRect(x: 0, y: 100, width: 400, height: 128))
    frames.report(.header, of: .list(ViewID()), CGRect(x: 0, y: 228, width: 400, height: 44))
    #expect(frames.blocks[own] == CGRect(x: 0, y: 100, width: 400, height: 128), "another block's parts its own")
}

/// The parts a block no longer draws are forgotten, its frame being the union of those it draws: folded, its rows and
/// its "+ Add task" go, which stood over the blocks under it and would have taken their drops; a row dropped into
/// another block goes from the one it left. A block that reported no part has no frame, whatever a board left, and a
/// block no longer drawn has neither parts nor frame.
@Test func aBlocksFrameForgetsThePartsItNoLongerDraws() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let header = CGRect(x: 0, y: 100, width: 400, height: 44)
    var frames = RowLift.Frames()
    frames.report(.header, of: house, header)
    frames.report(.row(list.h1), of: house, CGRect(x: 0, y: 144, width: 400, height: 44))
    frames.report(.row(list.h2), of: house, CGRect(x: 0, y: 188, width: 400, height: 44))
    frames.report(.add, of: house, CGRect(x: 0, y: 232, width: 400, height: 40))
    frames.report(.row(list.o1), of: office, CGRect(x: 0, y: 316, width: 400, height: 44))
    let empty = TaskList.Model.BlockID.list(list.empty)
    frames.blocks[empty] = CGRect(x: 918, y: 0, width: 296, height: 344)
    frames.forgetParts(notDrawnBy: list.blocks)
    #expect(frames.blocks[house] == CGRect(x: 0, y: 100, width: 400, height: 172), "all of them drawn")
    #expect(frames.blocks[empty] == nil, "its column's frame")

    list.press(.began(task: list.h2, block: house, session: "first", at: list.centre(of: list.h2, in: house)))
    list.press(.changed(list.top(of: office)))
    list.press(.ended)
    list.sendDrops()
    #expect(list.problem == nil)
    frames.forgetParts(notDrawnBy: list.blocks)
    frames.report(.add, of: house, CGRect(x: 0, y: 188, width: 400, height: 40))
    #expect(frames.blocks[house] == CGRect(x: 0, y: 100, width: 400, height: 128), "H2's frame gone with it")

    list.toggleFold(of: house)
    frames.forgetParts(notDrawnBy: list.blocks)
    #expect(frames.blocks[house] == header)
    #expect(frames.blocks[office] == CGRect(x: 0, y: 316, width: 400, height: 44))

    let gone = TaskList.Model.BlockID.list(ViewID())
    frames.report(.header, of: gone, header)
    frames.forgetParts(notDrawnBy: list.blocks)
    #expect(frames.blocks[gone] == nil)
    frames.report(.row(list.e1), of: gone, CGRect(x: 0, y: 400, width: 400, height: 44))
    #expect(frames.blocks[gone] == CGRect(x: 0, y: 400, width: 400, height: 44), "its header forgotten")
}

/// A drag finds a list's block by the parts the lazy stack has laid out, its frame being their union: House's header
/// and first row laid out and nothing below them, a point over them or under them, nearer House than Office, is House,
/// and so are a point nearer Office than House's header alone and a point nearer the own block than House's row alone.
@Test func aDragFindsABlockByThePartsLaidOut() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    var frames = RowLift.Frames()
    frames.report(.add, of: own, CGRect(x: 0, y: -230, width: 400, height: 80))
    frames.report(.header, of: house, CGRect(x: 0, y: 0, width: 400, height: 44))
    frames.report(.row(list.h1), of: house, CGRect(x: 0, y: 44, width: 400, height: 44))
    let o1 = CGRect(x: 0, y: 444, width: 400, height: 44)
    frames.report(.header, of: office, CGRect(x: 0, y: 400, width: 400, height: 44))
    frames.report(.row(list.o1), of: office, o1)
    frames.rows[BlockRowID(block: office, task: list.o1)] = o1
    var step = RowLift.after(
        .began(task: list.o1, block: office, session: "first", at: CGPoint(x: o1.midX, y: o1.midY)), from: nil,
        among: list.blocks, frames: frames
    )
    step = RowLift.after(.changed(CGPoint(x: 200, y: 60)), from: step.lift, among: list.blocks, frames: frames)
    #expect(step.lift?.slot == .into(house), "over its row")
    step = RowLift.after(.changed(CGPoint(x: 200, y: 150)), from: step.lift, among: list.blocks, frames: frames)
    #expect(step.lift?.slot == .into(house), "under its parts laid out")
    step = RowLift.after(.changed(CGPoint(x: 200, y: 230)), from: step.lift, among: list.blocks, frames: frames)
    #expect(step.lift?.slot == .into(house), "142 from its union, 170 from Office, 186 from its header alone")
    step = RowLift.after(.changed(CGPoint(x: 200, y: -60)), from: step.lift, among: list.blocks, frames: frames)
    #expect(step.lift?.slot == .into(house), "60 from its union, 90 from the own block, 104 from its row alone")
    step = RowLift.after(.changed(CGPoint(x: 200, y: 380)), from: step.lift, among: list.blocks, frames: frames)
    #expect(step.lift?.slot?.block == office, "nearer Office")
    step = RowLift.after(.changed(CGPoint(x: 200, y: 150)), from: step.lift, among: list.blocks, frames: frames)
    step = RowLift.after(.ended, from: step.lift, among: list.blocks, frames: frames)
    #expect(step.drop == .rowDropped(list.o1, from: office, in: house, after: nil))
}

/// The mark's line ends at the right of the block it stands in, measured from the block's own leading edge, where the
/// mark is drawn: the frames are the content's, and a block of the pane stands in from the content's side by the
/// pane's padding and the room either side of its widest, which the line's end must not count again (the Mac,
/// 2026-11-09: a line as long as the block's right edge in the content widened the block by that inset while a row
/// was carried).
@Test func theMarksLineEndsAtTheBlocksOwnRightEdge() {
    var frames = RowLift.Frames()
    let own = TaskList.Model.BlockID.own(nil)
    frames.blocks[own] = CGRect(x: 56, y: 120, width: 684, height: 200)
    #expect(frames.lineEnd(in: own) == 684)
}

/// A block that has reported no frame yet draws no line rather than one of a guessed length.
@Test func aBlockWithNoFrameEndsItsLineAtItsStart() {
    #expect(RowLift.Frames().lineEnd(in: .own(nil)) == 0)
}
