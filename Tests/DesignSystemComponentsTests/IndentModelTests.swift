import Testing
import DesignSystemComponents

/// A level of the tree starts where its indent says: the start at depth 0, and a step further for each level below it,
/// however deep, the phone's 20 and 22 pt here.
@Test func theLeadingIsTheStartAndAStepForEachLevel() {
    let indent = IndentModel(start: 20, step: 22)
    #expect([0, 1, 13].map(indent.leading(atDepth:)) == [20, 42, 306])
}
