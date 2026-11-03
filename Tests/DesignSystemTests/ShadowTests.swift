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

/// A card at rest in a column casts black at 6 %, blurred over 1 pt and dropped 1 pt: the canvas's
/// `0 1px 2px rgba(0,0,0,.06)` under a column's card (`Phone.dc.html`, `.card`), its 2 px blur halved into a platform's
/// radius.
@Test func aCardAtRestCastsTheFaintShadow() {
    let resting = DesignSystem.Shadow.resting
    #expect([resting.opacity, resting.radius, resting.y] == [0.06, 1, 1])
}
