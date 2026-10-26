import Testing
@testable import DesignSystem

/// A row's title is the body at the root and the callout nested, the canvas's 17 and 16 pt at the iPhone's default
/// text size, and semibold when the row has children.
@Test func rowTitleIsHeavierWithChildrenAndSmallerNested() {
    let font = DesignSystem.font
    #expect(font.rowTitle(depth: 0, hasChildren: true) == DesignSystem.Font(style: .body, weight: .semibold, rounded: false))
    #expect(font.rowTitle(depth: 0, hasChildren: false) == DesignSystem.Font(style: .body, weight: .regular, rounded: false))
    #expect(font.rowTitle(depth: 1, hasChildren: false) == DesignSystem.Font(style: .callout, weight: .regular, rounded: false))
    #expect(font.rowTitle(depth: 3, hasChildren: true) == DesignSystem.Font(style: .callout, weight: .semibold, rounded: false))
}
