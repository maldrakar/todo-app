import CoreGraphics
import Testing
@testable import TodoAppleUI
import TaskListFeature

// The Mac's drag by the pointer, `RowPointerPress`, driven event by event as the pane's gesture hands them on
// (`RowPointerDrag`), over the blocks a real `TaskList` draws at a wide window's width and the frames of the pane's
// layout (`LiftedList`'s pane: rows 36 high in blocks 684 wide, 48 in, columns 288 wide 12 apart, their cards 6 in),
// with the pane's part of the content in sight: all of it unless a test scrolls it. Each drop is then sent to the
// module, which is the end-to-end case.

/// A press of the pointer that begins on a row lifts that row at its first move, the one past SwiftUI's distance, in a
/// session of the press's own, its own place being the slot until the pointer leaves it.
@Test func aPointerPressOnARowLiftsIt() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let start = list.centre(of: list.h2, in: house)
    list.pointer(.moved(from: start, to: CGPoint(x: start.x + 10, y: start.y)))
    #expect(list.lift?.task == list.h2)
    #expect(list.lift?.source == house)
    #expect(list.lift?.session == list.pointerPress?.session)
    #expect(list.lift?.slot == .place(house, after: list.h1))
    #expect(list.drops.isEmpty)
}

/// Within its own block the pointer moves the line by the rows' middles, as the system's drag does: before a row over
/// its upper half and after it over its lower, at the top over the first row's upper half; the release drops the task
/// there and the module stands it there.
@Test func aPointerMoveWithinItsBlockMovesTheLineByTheRowsMiddles() throws {
    var list = try LiftedList(pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    let start = list.centre(of: list.b, in: own)
    list.pointer(.moved(from: start, to: list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.pointer(.moved(from: start, to: list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.d))
    list.pointer(.moved(from: start, to: list.upperHalf(of: list.a, in: own)))
    #expect(list.lift?.slot == .place(own, after: nil))
    list.pointer(.moved(from: start, to: list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.pointer(.released)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// Over another block the slot is that block, which its tint marks, over its rows and its header alike, and over a
/// block that takes no drop there is none.
@Test func aPointerMoveIntoAnotherBlockMarksIt() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let either = TaskList.Model.BlockID.list(list.either)
    let start = list.centre(of: list.h1, in: house)
    list.pointer(.moved(from: start, to: list.upperHalf(of: list.o2, in: office)))
    #expect(list.lift?.slot == .into(office))
    list.pointer(.moved(from: start, to: list.top(of: office)))
    #expect(list.lift?.slot == .into(office), "over its header")
    list.pointer(.moved(from: start, to: list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)
    #expect(list.lift?.task == list.h1, "still lifted")
}

/// The release reports the drop once, and what the gesture hands after it moves nothing.
@Test func aPointerReleaseReportsOneDrop() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let start = list.centre(of: list.h1, in: house)
    list.pointer(.moved(from: start, to: list.centre(of: list.o1, in: office)))
    list.pointer(.released)
    #expect(list.lift == nil)
    #expect(list.pointerPress == nil)
    list.pointer(.cancelled)
    list.pointer(.released)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(Set(list.rowIDs(of: office)) == [list.o1, list.o2, list.h1])
}

/// A drag SwiftUI cancels puts the row down and drops nothing.
@Test func aPointerCancelReportsNoDrop() throws {
    var list = try LiftedList(pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    let start = list.centre(of: list.a, in: own)
    list.pointer(.moved(from: start, to: list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == .place(own, after: list.c))
    list.pointer(.cancelled)
    #expect(list.lift == nil)
    #expect(list.pointerPress == nil)
    list.pointer(.released)
    #expect(list.drops.isEmpty)
    #expect(list.rowIDs(of: own) == [list.a, list.b, list.c, list.d])
}

/// Each press is a drag of its own: the next one, on another row, lifts that row in a session of its own.
@Test func aSecondPointerPressHasItsOwnSession() throws {
    var list = try LiftedList(pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    let first = list.centre(of: list.a, in: own)
    list.pointer(.moved(from: first, to: list.lowerHalf(of: list.b, in: own)))
    let session = try #require(list.lift?.session)
    list.pointer(.released)
    let second = list.centre(of: list.d, in: own)
    list.pointer(.moved(from: second, to: list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.task == list.d)
    #expect(list.lift?.session != session)
    #expect(list.lift?.session == list.pointerPress?.session)
}

/// A lift no press of the gesture holds, which a drag whose state SwiftUI dropped would leave drawn, is no next press's
/// to move or to drop: that press's moves leave it, and its release puts it down with no drop.
@Test func aPointerReleaseDropsOnlyItsOwnLift() throws {
    var list = try LiftedList(pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    list.pointer(.moved(from: list.centre(of: list.a, in: own), to: list.lowerHalf(of: list.b, in: own)))
    #expect(list.lift?.task == list.a)
    list.losePointerPress()
    let start = list.centre(of: list.d, in: own)
    list.pointer(.moved(from: start, to: list.upperHalf(of: list.c, in: own)))
    #expect(list.lift?.task == list.a, "another press's lift, which this one does not move")
    list.pointer(.released)
    #expect(list.lift == nil)
    #expect(list.drops.isEmpty)
}

/// A press that begins on no row lifts nothing at any move, though it passes over rows: on a block's header, beside
/// the blocks, and on an open card, which has no lift; and its release drops nothing.
@Test func aPointerPressOnNoRowLiftsNothing() throws {
    var list = try LiftedList(pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    let office = TaskList.Model.BlockID.list(list.office)
    let row = list.centre(of: list.b, in: own)
    for start in [list.top(of: office), CGPoint(x: 20, y: row.y), CGPoint(x: 740, y: row.y)] {
        list.pointer(.moved(from: start, to: list.centre(of: list.o1, in: office)))
        list.pointer(.moved(from: start, to: list.centre(of: list.b, in: own)))
        #expect(list.lift == nil)
        #expect(list.pointerPress?.row == nil)
        list.pointer(.released)
    }
    list.openCard(on: list.a)
    let card = list.centre(of: list.a, in: own)
    list.pointer(.moved(from: card, to: list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift == nil, "an open card does not lift")
    list.pointer(.released)
    #expect(list.drops.isEmpty)
}

/// Let go outside the part of the content in sight, over the sidebar at another block's height, or above the pane's
/// top with the list scrolled down where the nearest block is out of sight, the drag lets go of nothing: the lift goes,
/// and with it the mark and the tint, as soon as the pointer leaves, and the release drops nothing.
@Test func aPointerReleasedOutsideThePaneDropsNothing() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let start = list.centre(of: list.h1, in: house)
    let overTheSidebar = CGPoint(x: list.viewport.minX - 40, y: list.centre(of: list.o1, in: office).y)
    list.pointer(.moved(from: start, to: overTheSidebar))
    #expect(list.lift == nil)
    list.pointer(.released)
    #expect(list.drops.isEmpty)
    #expect(list.rowIDs(of: house) == [list.h1, list.h2])

    list.scroll(to: list.top(of: office).y - 1)
    let o1 = list.centre(of: list.o1, in: office)
    list.pointer(.moved(from: o1, to: CGPoint(x: o1.x, y: o1.y + 4)))
    #expect(list.lift?.task == list.o1)
    let aboveTheTop = CGPoint(x: o1.x, y: list.viewport.minY - 30)
    #expect(list.frames.blocks[house]?.contains(aboveTheTop) == true, "the fixture's House under that point, unseen")
    list.pointer(.moved(from: o1, to: aboveTheTop))
    #expect(list.lift == nil)
    list.pointer(.released)
    #expect(list.drops.isEmpty)
    #expect(list.rowIDs(of: office) == [list.o1, list.o2])
}

/// A drag that leaves the content in sight and comes back lifts its row again, in the same press's session, and its
/// release drops it once where it is let go.
@Test func aPointerThatComesBackLiftsAgain() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let start = list.centre(of: list.h1, in: house)
    list.pointer(.moved(from: start, to: list.centre(of: list.o1, in: office)))
    let session = try #require(list.lift?.session)
    list.pointer(.moved(from: start, to: CGPoint(x: list.viewport.maxX + 20, y: start.y)))
    #expect(list.lift == nil)
    list.pointer(.moved(from: start, to: list.centre(of: list.o1, in: office)))
    #expect(list.lift?.task == list.h1)
    #expect(list.lift?.session == session)
    #expect(list.lift?.slot == .into(office))
    list.pointer(.released)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
}

/// On the board the pointer carries a card from its column into another, and the release drops it there; a press in
/// the gap between two columns, or on a column's header over a card its scroll has taken out of sight, which keeps a
/// frame there, begins on no card.
@Test func aPointerCarriesACardBetweenColumns() throws {
    var list = try LiftedList(columns: true, pane: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let start = list.centre(of: list.h1, in: house)
    list.pointer(.moved(from: start, to: list.centre(of: list.o1, in: office)))
    #expect(list.lift?.slot == .into(office))
    let gap = CGPoint(x: list.columnFrame(of: office).minX - 3, y: 200)
    list.pointer(.moved(from: start, to: gap))
    #expect(list.lift?.slot == .into(office), "in the gap, the nearer column")
    list.pointer(.moved(from: start, to: list.lowerHalf(of: list.h2, in: house)))
    #expect(list.lift?.slot == .place(house, after: list.h2))
    list.pointer(.moved(from: start, to: list.centre(of: list.o2, in: office)))
    list.pointer(.released)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: nil)])
    list.sendDrops()
    #expect(list.problem == nil)
    #expect(list.rowIDs(of: house) == [list.h2])
    #expect(Set(list.rowIDs(of: office)) == [list.o1, list.o2, list.h1])

    let middleOfTheGap = CGPoint(x: list.columnFrame(of: office).minX - 6, y: 60)
    list.pointer(.moved(from: middleOfTheGap, to: list.centre(of: list.h2, in: house)))
    #expect(list.lift == nil, "the gap between columns")
    list.pointer(.released)
    list.scrollColumn(own, by: 30)
    let hidden = list.centre(of: list.a, in: own)
    #expect(hidden.y > 0 && hidden.y < list.visibleArea(of: own).minY, "the fixture's A under the header")
    list.pointer(.moved(from: hidden, to: list.centre(of: list.h2, in: house)))
    #expect(list.lift == nil, "a card out of sight")
    list.pointer(.released)
    #expect(list.drops.count == 1)
}

/// The lifted row's copy keeps what was grabbed under the pointer, though it grows to its lift's scale and though the
/// mark has moved the row itself since: its corner as far from the pointer as the row's was from the press, and it
/// grows about the grabbed point.
@Test func aPointersCopyKeepsWhatWasGrabbedUnderThePointer() throws {
    var list = try LiftedList(pane: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let row = try #require(list.frames.rows[BlockRowID(block: house, task: list.h2)])
    let grab = CGVector(dx: 100, dy: 12)
    let start = CGPoint(x: row.minX + grab.dx, y: row.minY + grab.dy)
    list.pointer(.moved(from: start, to: CGPoint(x: start.x + 10, y: start.y + 3)))
    let moved = list.frames.rows[BlockRowID(block: house, task: list.h2)]
    #expect(moved?.minY == row.minY + 10, "the fixture's mark above the row, which moves it down")
    let lift = try #require(list.block(house)?.rows.first { $0.id == list.h2 }?.lift)
    let press = try #require(list.pointerPress)
    for pointer in [start, CGPoint(x: 300, y: 50)] {
        let origin = press.copyOrigin(at: pointer)
        let anchor = CGPoint(
            x: origin.x + press.copyAnchor.x * row.width, y: origin.y + press.copyAnchor.y * row.height
        )
        let grabbed = CGPoint(x: origin.x + grab.dx, y: origin.y + grab.dy)
        let scaled = CGPoint(
            x: anchor.x + (grabbed.x - anchor.x) * lift.scale, y: anchor.y + (grabbed.y - anchor.y) * lift.scale
        )
        #expect(abs(scaled.x - pointer.x) < 0.001 && abs(scaled.y - pointer.y) < 0.001)
    }
}
