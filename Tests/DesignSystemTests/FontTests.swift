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

/// The bar's words are the subheadline in semibold, the canvas's 15 pt; the picker's hint the footnote, 13 pt; and the
/// search capsule's placeholder the body, 17 pt, each at the iPhone's default text size and none rounded.
@Test func theBarsLabelTheHintAndTheSearchAreTheSubheadlineTheFootnoteAndTheBody() {
    #expect(Font.barLabel == Font(style: .subheadline, weight: .semibold, rounded: false))
    #expect(Font.hint == Font(style: .footnote, weight: .regular, rounded: false))
    #expect(Font.search == Font(style: .body, weight: .regular, rounded: false))
}

/// Bold is a weight of its own, between semibold and heavy, which the bar's Done glyph is drawn in (Lists screen plan,
/// Task 8): a font in bold is no font in any other weight.
@Test func boldIsAWeightOfItsOwn() {
    let weights: [Font.Weight] = [.regular, .medium, .semibold, .bold, .heavy]
    #expect(Set(weights).count == weights.count)
    #expect(Font(style: .body, weight: .bold, rounded: false) != Font(style: .body, weight: .semibold, rounded: false))
}

/// An area's name in the sidebar is the caption in heavy and the rounded face, the canvas's 10.5 pt 800 in `ui-rounded`
/// (`Mac.dc.html`, `.an`), at the Mac's caption size, 10 pt.
@Test func anAreasCaptionIsTheCaptionHeavyAndRounded() {
    #expect(Font.areaCaption == Font(style: .caption, weight: .heavy, rounded: true))
}
