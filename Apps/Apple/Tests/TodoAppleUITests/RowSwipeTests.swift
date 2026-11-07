import CoreGraphics
import DesignSystemComponents
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
