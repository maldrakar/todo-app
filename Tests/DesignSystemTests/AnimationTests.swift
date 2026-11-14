import Testing
import DesignSystem

private typealias Animation = DesignSystem.Animation

/// A done row leaves 0.7 s after it was checked: the wait is the animation's own delay, so a platform draws it and
/// keeps no timer of its own. Every other motion starts at once.
@Test func aDoneRowLeavesSevenTenthsOfASecondAfterItWasChecked() {
    #expect(DesignSystem.Animation.rowLeaves.delay == 0.7)
}

/// A deleted row leaves on a done row's curve and in its time, at once: the wait is for a check to be read, and a delete
/// has none.
@Test func aDeletedRowLeavesAsADoneRowDoesWithNoWait() {
    let motion = DesignSystem.Animation.rowDeleted
    #expect(motion.curve == DesignSystem.Animation.rowLeaves.curve)
    #expect(motion.duration == DesignSystem.Animation.rowLeaves.duration)
    #expect(motion.delay == 0)
}

/// A check's mark draws itself over 0.26 s on `ease`, starting 0.08 s after its colours do (`Phone.dc.html`, `.cb path`).
@Test func aChecksMarkDrawsItselfAfterItsColoursHaveStarted() {
    let motion = DesignSystem.Animation.checkMarkDraws
    #expect(motion.curve == .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1))
    #expect(motion.duration == 0.26)
    #expect(motion.delay == 0.08)
}

/// The list screen's motions are the canvas's (`Phone.dc.html`): a card opening in place over 0.26 s and a row sliding
/// for its Delete over 0.25 s on (.2, .8, .2, 1); a card landing on a 0.32 s spring; and a chevron turning over 0.22 s
/// and a dropped row's highlight fading over 1.6 s on CSS's `ease`, (.25, .1, .25, 1), as the small fades under them
/// run on it: a check's colours over 0.22 s, a title's over 0.25 s, a chip's over 0.18 s, a card dimming or a column
/// tinting under a drag over 0.15 s, and on the Mac's pane (`Mac.dc.html`) a control's tint under the pointer over
/// 0.12 s and a column's card's deeper shadow over 0.15 s. Each starts at once.
@Test func theListScreensMotionsAreTheCanvass() {
    let motions: [(String, Animation, Animation.Curve, Double)] = [
        ("cardOpens", .cardOpens, .bezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1), 0.26),
        ("swipe", .swipe, .bezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1), 0.25),
        ("drop", .drop, .spring, 0.32),
        ("fold", .fold, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.22),
        ("fresh", .fresh, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 1.6),
        ("checkFills", .checkFills, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.22),
        ("titleFades", .titleFades, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.25),
        ("chipToggles", .chipToggles, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.18),
        ("dropHighlights", .dropHighlights, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.15),
        ("hoverTints", .hoverTints, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.12),
        ("hoverShadows", .hoverShadows, .bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.15),
    ]
    for (name, motion, curve, duration) in motions {
        #expect(motion.curve == curve, "\(name)")
        #expect(motion.duration == duration, "\(name)")
        #expect(motion.delay == 0, "\(name)")
    }
}

/// A dragged task's slot moves on a 0.3 s spring, the mark and the rows that open and close its gap, and the copy
/// settles into it on the same motion where the platform's drag does not move it itself, as the owner's reference
/// moves them (#211). It starts at once.
@Test func aDraggedTasksSlotMovesOnAQuickSpring() {
    let motion = DesignSystem.Animation.slotMoves
    #expect(motion.curve == .spring)
    #expect(motion.duration == 0.3)
    #expect(motion.delay == 0)
}

/// Where a person asked for less motion a done row still waits for its check to be read, and then goes with nothing to
/// see: on a motion of no length SwiftUI took the task away at the tap, the wait and all (the iOS 26.3 simulator,
/// 2026-11-07), so this one has a length too short to see.
@Test func aDoneRowWithNoMotionWaitsAsLongAndRunsTooShortToSee() {
    let motion = DesignSystem.Animation.rowLeavesWithNoMotion
    #expect(motion.delay == DesignSystem.Animation.rowLeaves.delay)
    #expect(motion.duration > 0)
    #expect(motion.duration < 0.01)
}
