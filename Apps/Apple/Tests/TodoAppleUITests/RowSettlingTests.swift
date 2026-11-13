import CoreGraphics
import Testing
@testable import TodoAppleUI
import TaskListFeature
import TodoCore

// Where the copy of a dragged task goes once it is let go (`RowLift.Settling`, #211), read from the lift as the release
// found it and the frames the layout reports once the drop has been sent to the module, over the list of `LiftedList`.
// What is in sight is the part of the content a test leaves in sight, the whole of it unless the test scrolls.

/// Let go on a place in its own block, the copy settles onto the row where the drop has stood it: under the row the
/// mark stood after.
@Test func aCopyLetGoOnAPlaceSettlesOntoTheRowWhereTheDropStoodIt() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.b, block: own, session: "first", at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    let released = try #require(list.lift)
    list.press(.ended)
    list.sendDrops()
    let row = BlockRowID(block: own, task: list.b)
    let frame = try #require(list.frames.rows[row])
    #expect(frame.minY == list.frames.rows[BlockRowID(block: own, task: list.c)]?.maxY)
    #expect(released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport) == .onto(row, frame))
}

/// Let go in another block, the copy settles onto the row the task appears as there, which the block it was dragged
/// from no longer draws.
@Test func aCopyLetGoInAnotherBlockSettlesOntoTheRowItAppearsAs() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.press(.began(task: list.h2, block: house, session: "first", at: list.centre(of: list.h2, in: house)))
    list.press(.changed(list.centre(of: list.o1, in: office)))
    let released = try #require(list.lift)
    list.press(.ended)
    list.sendDrops()
    let row = BlockRowID(block: office, task: list.h2)
    let frame = try #require(list.frames.rows[row])
    #expect(released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport) == .onto(row, frame))
}

/// Let go where nothing lands, over a block that takes no drop, the copy settles back onto its own row, where it was
/// dragged from.
@Test func aCopyLetGoWhereNothingLandsSettlesBackOntoItsOwnRow() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let either = TaskList.Model.BlockID.list(list.either)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.centre(of: list.e1, in: either)))
    let released = try #require(list.lift)
    #expect(released.slot == nil)
    list.press(.ended)
    #expect(list.drops.isEmpty)
    let row = BlockRowID(block: own, task: list.a)
    let frame = try #require(list.frames.rows[row])
    #expect(released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport) == .onto(row, frame))
}

/// A row whose middle is out of sight, the content scrolled past it, takes the copy toward the edge of what is in sight
/// nearest it, where the copy fades: a copy settled onto it would go where nothing shows it.
@Test func aRowOutOfSightTakesTheCopyTowardTheEdgeOfWhatIsInSight() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.press(.began(task: list.h2, block: house, session: "first", at: list.centre(of: list.h2, in: house)))
    list.press(.changed(list.centre(of: list.o1, in: office)))
    let released = try #require(list.lift)
    list.press(.ended)
    list.sendDrops()
    let frame = try #require(list.frames.rows[BlockRowID(block: office, task: list.h2)])
    list.scroll(to: frame.maxY + 100)
    #expect(
        released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport)
            == .toward(CGPoint(x: frame.midX, y: list.viewport.minY))
    )
}

/// A row the lazy stack has not laid out has no frame to settle onto, and the copy goes toward the middle of what of
/// its block is in sight, the block's tinted area.
@Test func aRowNotLaidOutTakesTheCopyTowardWhatOfItsBlockIsInSight() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.press(.began(task: list.h2, block: house, session: "first", at: list.centre(of: list.h2, in: house)))
    list.press(.changed(list.centre(of: list.o1, in: office)))
    let released = try #require(list.lift)
    list.press(.ended)
    list.sendDrops()
    list.leaveNotLaidOut(list.h2, in: office)
    let block = try #require(list.frames.blocks[office])
    list.scroll(to: block.midY)
    let seen = block.intersection(list.viewport)
    #expect(
        released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport)
            == .toward(CGPoint(x: seen.midX, y: seen.midY))
    )
}

/// A card whose place is scrolled out of its column's cards in sight takes the copy toward the edge of those in sight,
/// a column's own scroll hiding what the board's does not.
@Test func aCardScrolledOutOfItsColumnTakesTheCopyTowardTheCardsInSight() throws {
    var list = try LiftedList(columns: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    list.press(.began(task: list.o1, block: office, session: "first", at: list.centre(of: list.o1, in: office)))
    list.press(.changed(list.centre(of: list.h1, in: house)))
    let released = try #require(list.lift)
    list.press(.ended)
    list.sendDrops()
    list.scrollColumn(house, by: 1_000)
    let card = try #require(list.frames.rows[BlockRowID(block: house, task: list.o1)])
    let area = list.visibleArea(of: house)
    #expect(card.maxY < area.minY)
    #expect(
        released.settling(among: list.blocks, frames: list.frames, inSight: list.viewport)
            == .toward(CGPoint(x: card.midX, y: area.minY))
    )
}

/// With nothing of the row or its block laid out, the copy has nowhere to go, and the platform lets it go as it would.
@Test func aCopyWithNothingLaidOutHasNowhereToSettle() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.a, block: own, session: "first", at: list.centre(of: list.a, in: own)))
    let released = try #require(list.lift)
    #expect(released.settling(among: list.blocks, frames: RowLift.Frames(), inSight: list.viewport) == nil)
}

/// A column scrolled out of the board's sight has no cards in sight, and a copy going back to its card goes toward the
/// edge of what of the board is in sight nearest it.
@Test func aCardInAColumnOutOfSightTakesTheCopyTowardTheEdgeOfTheBoardInSight() throws {
    var list = try LiftedList(columns: true)
    let office = TaskList.Model.BlockID.list(list.office)
    let either = TaskList.Model.BlockID.list(list.either)
    list.press(.began(task: list.o1, block: office, session: "first", at: list.centre(of: list.o1, in: office)))
    list.press(.changed(list.centre(of: list.e1, in: either)))
    let released = try #require(list.lift)
    #expect(released.slot == nil)
    list.press(.ended)
    let card = try #require(list.frames.rows[BlockRowID(block: office, task: list.o1)])
    let sight = CGRect(x: 0, y: 0, width: list.columnFrame(of: office).minX - 100, height: list.viewport.height)
    #expect(
        released.settling(among: list.blocks, frames: list.frames, inSight: sight)
            == .toward(CGPoint(x: sight.maxX, y: card.midY))
    )
}
