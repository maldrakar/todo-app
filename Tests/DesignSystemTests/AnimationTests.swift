import Testing
import DesignSystem

/// A done row leaves 0.7 s after it was checked: the wait is the animation's own delay, so a platform draws it and
/// keeps no timer of its own. Every other motion starts at once.
@Test func aDoneRowLeavesSevenTenthsOfASecondAfterItWasChecked() {
    #expect(DesignSystem.Animation.rowLeaves.delay == 0.7)
}
