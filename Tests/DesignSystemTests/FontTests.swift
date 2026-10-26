import Testing
@testable import DesignSystem

private typealias Font = DesignSystem.Font

/// A row's title is the body at the root and the callout nested, the canvas's 17 and 16 pt at the iPhone's default
/// text size, and semibold when the row has children. A depth below the root, which no row has but a view could send,
/// reads as the root, as a tile's does.
@Test func rowTitleIsHeavierWithChildrenAndSmallerNested() {
    #expect(Font.rowTitle(depth: 0, hasChildren: true) == Font(style: .body, weight: .semibold, rounded: false))
    #expect(Font.rowTitle(depth: 0, hasChildren: false) == Font(style: .body, weight: .regular, rounded: false))
    #expect(Font.rowTitle(depth: 1, hasChildren: false) == Font(style: .callout, weight: .regular, rounded: false))
    #expect(Font.rowTitle(depth: 3, hasChildren: true) == Font(style: .callout, weight: .semibold, rounded: false))
    #expect(Font.rowTitle(depth: -1, hasChildren: false) == Font(style: .body, weight: .regular, rounded: false))
}
