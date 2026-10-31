import Testing
import DesignSystem

/// A lifted row casts black at 22 %, blurred over 18 pt and dropped 10 pt, the shadow Task 7 drew under the drag's card.
@Test func aLiftedRowCastsTheLargeSoftShadow() {
    let lifted = DesignSystem.Shadow.lifted
    #expect([lifted.opacity, lifted.radius, lifted.y] == [0.22, 18, 10])
}
