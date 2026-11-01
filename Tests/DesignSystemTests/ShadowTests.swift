import Testing
import DesignSystem

/// A lifted row casts black at 22 %, blurred over 18 pt and dropped 10 pt, the shadow Task 7 drew under the drag's card.
@Test func aLiftedRowCastsTheLargeSoftShadow() {
    let lifted = DesignSystem.Shadow.lifted
    #expect([lifted.opacity, lifted.radius, lifted.y] == [0.22, 18, 10])
}

/// A control raised off what it stands on casts black at 12 %, blurred over 12 pt and dropped 5 pt, the canvas's small
/// shadow as Task 7 drew it under the bar's controls.
@Test func aRaisedControlCastsTheSmallShadow() {
    let raised = DesignSystem.Shadow.raised
    #expect([raised.opacity, raised.radius, raised.y] == [0.12, 12, 5])
}
