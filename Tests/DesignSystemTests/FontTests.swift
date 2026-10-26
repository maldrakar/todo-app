import Testing
@testable import DesignSystem

private typealias Font = DesignSystem.Font

/// A row's title is the body and a nested row's the callout, the canvas's 17 and 16 pt at the iPhone's default text
/// size, each regular and, emphasized, semibold; none is rounded.
@Test func theRowTitlesAreTheBodyAndTheCalloutRegularOrSemibold() {
    #expect(Font.rowTitle == Font(style: .body, weight: .regular, rounded: false))
    #expect(Font.rowTitleEmphasized == Font(style: .body, weight: .semibold, rounded: false))
    #expect(Font.nestedRowTitle == Font(style: .callout, weight: .regular, rounded: false))
    #expect(Font.nestedRowTitleEmphasized == Font(style: .callout, weight: .semibold, rounded: false))
}
