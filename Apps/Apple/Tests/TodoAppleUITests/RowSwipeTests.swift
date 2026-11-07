import CoreGraphics
import DesignSystemComponents
import Observation
import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The swipe of a row to its Delete, `RowSwipe`, driven stage by stage as the pan drives it, with the phone's numbers:
// past 40 leftward it stays moved 88. The pan itself is UIKit's, and the simulator's to show.

private let style = SwipeStyle(
    threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10, buttonCornerRadius: 12,
    background: .red, animation: .swipe
)
private let first = BlockRowID(block: .own(nil), task: TaskID())
private let second = BlockRowID(block: .own(nil), task: TaskID())

/// The row follows the finger leftward, and not rightward of where it rests, nor further than the threshold past its
/// shift.
@Test func aRowFollowsTheFingerWithinItsBounds() {
    var swipe = RowSwipe.after(.began(first, style), from: nil)
    #expect(swipe?.row == first && swipe?.x == 0)
    swipe = RowSwipe.after(.changed(-30), from: swipe)
    #expect(swipe?.x == -30)
    swipe = RowSwipe.after(.changed(30), from: swipe)
    #expect(swipe?.x == 0)
    swipe = RowSwipe.after(.changed(-500), from: swipe)
    #expect(swipe?.x == -128)
    #expect(swipe?.isFollowingFinger == true)
}

/// Let go past the threshold it stays moved by its shift; short of it, it goes back.
@Test func aReleasePastTheThresholdStaysOpenAndShortOfItCloses() {
    let moved = RowSwipe.after(.began(first, style), from: nil)
    let open = RowSwipe.after(.ended(-41), from: moved)
    #expect(open?.x == -88)
    #expect(open?.isFollowingFinger == false)
    #expect(RowSwipe.after(.ended(-40), from: moved) == nil)
    #expect(RowSwipe.after(.ended(40), from: moved) == nil)
}

/// An open row is taken from where it stands: a little rightward it stays open, and past the threshold's place it
/// closes.
@Test func anOpenRowIsTakenFromItsShift() {
    let open = RowSwipe.after(.ended(-60), from: RowSwipe.after(.began(first, style), from: nil))
    let taken = RowSwipe.after(.began(first, style), from: open)
    #expect(taken?.x == -88)
    #expect(RowSwipe.after(.changed(10), from: taken)?.x == -78)
    #expect(RowSwipe.after(.ended(47), from: taken)?.x == -88)
    #expect(RowSwipe.after(.ended(48), from: taken) == nil)
}

/// Only one row stays open: another row taken starts from rest, and the open one goes back.
@Test func anotherRowTakenClosesTheOpenOne() {
    let open = RowSwipe.after(.ended(-60), from: RowSwipe.after(.began(first, style), from: nil))
    let other = RowSwipe.after(.began(second, style), from: open)
    #expect(other?.row == second && other?.x == 0)
}

/// A pan the system cancelled leaves a row where it rested.
@Test func aCancelPutsTheRowBackWhereItRested() {
    let closed = RowSwipe.after(.changed(-60), from: RowSwipe.after(.began(first, style), from: nil))
    #expect(RowSwipe.after(.cancelled, from: closed) == nil)
    let open = RowSwipe.after(.ended(-60), from: RowSwipe.after(.began(first, style), from: nil))
    let taken = RowSwipe.after(.changed(100), from: RowSwipe.after(.began(first, style), from: open))
    #expect(RowSwipe.after(.cancelled, from: taken)?.x == -88)
}

/// With no row taken, nothing moves.
@Test func aStageWithNoRowTakenMovesNothing() {
    #expect(RowSwipe.after(.changed(-60), from: nil) == nil)
    #expect(RowSwipe.after(.ended(-60), from: nil) == nil)
    #expect(RowSwipe.after(.cancelled, from: nil) == nil)
}

/// A pan takes the row under where it started, by that block's frame, where it has a swipe: leftward, or either way
/// where that row stands open. Over no row, on a board, whose cards have no swipe, it takes nothing, and the scroll has
/// it.
@Test func aPanTakesTheRowUnderItsStartWhereItHasASwipe() throws {
    let list = try LiftedList(taskInHouseAndOffice: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let both = try #require(list.both)
    func taken(_ point: CGPoint, moved: CGFloat, from swipe: RowSwipe? = nil) -> BlockRowID? {
        RowSwipe.row(at: point, moved: moved, from: swipe, among: list.blocks, frames: list.frames)?.row
    }
    let inOffice = BlockRowID(block: office, task: both)
    #expect(taken(list.centre(of: both, in: office), moved: -10) == inOffice)
    #expect(taken(list.centre(of: both, in: house), moved: -10) == BlockRowID(block: house, task: both))
    #expect(taken(list.centre(of: both, in: office), moved: 10) == nil, "rightward, a row at rest has nothing to close")
    #expect(taken(CGPoint(x: 10, y: -500), moved: -10) == nil)

    let style = try #require(RowSwipe.row(
        at: list.centre(of: both, in: office), moved: -10, from: nil, among: list.blocks, frames: list.frames
    )?.style)
    let open = RowSwipe.after(.ended(-60), from: RowSwipe.after(.began(inOffice, style), from: nil))
    #expect(taken(list.centre(of: both, in: office), moved: 10, from: open) == inOffice)
    #expect(taken(list.centre(of: both, in: house), moved: 10, from: open) == nil, "the task's other row is another")

    let board = try LiftedList(columns: true)
    let own = TaskList.Model.BlockID.own(nil)
    let card = board.centre(of: board.a, in: own)
    #expect(RowSwipe.row(at: card, moved: -10, from: nil, among: board.blocks, frames: board.frames) == nil)
}

/// Frames are kept as they are reported and a row that left keeps its frame, a peer's change among the ways: a pan takes
/// the row drawn under its start, and no frame of a row no longer drawn stands in its way.
@Test func aPanIsNotStoppedByTheFrameOfARowNoLongerDrawn() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let point = list.centre(of: list.a, in: own)
    var frames = list.frames
    for _ in 0..<50 {
        frames.rows[BlockRowID(block: own, task: TaskID())] = CGRect(x: 0, y: point.y - 10, width: 400, height: 20)
    }
    let taken = RowSwipe.row(at: point, moved: -10, from: nil, among: list.blocks, frames: frames)
    #expect(taken?.row == BlockRowID(block: own, task: list.a))
}

// MARK: - The screen's one swipe

/// Whether an observation fired, which its closure, sendable, sets.
private final class Flag: @unchecked Sendable {
    var isSet = false
}

/// A row's swipe is held so that what every row reads, which row is taken, changes only when another is taken, and what
/// the finger moves is read by the taken row alone: a move draws one row, not every row that can be swiped.
@MainActor
@Test func aMoveOfTheFingerTouchesOnlyWhatTheTakenRowReads() {
    let swipe = ScreenSwipe()
    swipe.step(.began(first, style))
    let rowChanged = Flag()
    withObservationTracking { _ = swipe.row } onChange: { rowChanged.isSet = true }
    let xChanged = Flag()
    withObservationTracking { _ = swipe.x } onChange: { xChanged.isSet = true }
    swipe.step(.changed(-30))
    #expect(!rowChanged.isSet, "every row reads this")
    #expect(xChanged.isSet, "the taken row reads this")
    #expect(swipe.x == -30)
    swipe.step(.ended(-60))
    #expect(!rowChanged.isSet, "the same row, open")
    #expect(swipe.isOpen)
    swipe.step(.began(second, style))
    #expect(rowChanged.isSet, "another row taken")
    #expect(swipe.row == second)
}

/// The row a swipe holds is let go of when it leaves the screen, a peer's change among the ways, so that the next tap
/// on a row is not taken for closing it; another row's leaving changes nothing.
@MainActor
@Test func aRowThatLeavesTheScreenIsNoLongerOpen() {
    let swipe = ScreenSwipe()
    swipe.step(.began(first, style))
    swipe.step(.ended(-60))
    swipe.rowLeft(second)
    #expect(swipe.isOpen)
    swipe.rowLeft(first)
    #expect(!swipe.isOpen)
    #expect(swipe.row == nil)
}

/// Closing leaves no row taken, and answers nothing for a swipe already at rest.
@MainActor
@Test func closingLeavesNoRowTaken() {
    let swipe = ScreenSwipe()
    swipe.step(.began(first, style))
    swipe.step(.ended(-60))
    swipe.close()
    #expect(!swipe.isOpen)
    #expect(swipe.x == 0)
    swipe.step(.changed(-60))
    #expect(!swipe.isOpen, "with no row taken a stage moves nothing")
}
