import SwiftUI
import Testing
import TodoCore
@testable import TodoAppleUI

@Test func everyListColourHasItsShades() {
    for color in TaskViewColor.allCases {
        #expect(ListColorShades.byName[color] != nil, "\(color) has no shades")
    }
    #expect(ListColorShades.byName.count == TaskViewColor.allCases.count)
}

@Test func aListWithNoColourDrawsStonesShades() throws {
    let stone = try #require(ListColorShades.byName[.stone])
    #expect(ListColorShades.shades(of: nil) == stone)
    #expect(ListColorShades.shades(of: .blue) == ListColorShades.byName[.blue])
}

/// `Main.dc.html` draws the Inbox's glyph as #385EA3, which is blue's base mixed a fifth toward the ink, so the rule
/// here is the canvas's and not a guess at it.
@Test func theLightGlyphOfBlueIsTheCanvassBlue() {
    let glyph = ListColorShades.glyph(RGB(hex: 0x3E6EC5), dark: false)
    let expected = RGB(hex: 0x385EA3)
    for (got, want) in [(glyph.red, expected.red), (glyph.green, expected.green), (glyph.blue, expected.blue)] {
        #expect(abs(got - want) * 255 <= 1)
    }
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func theDarkGlyphOfBlueIsLiftedTowardWhite() {
    let glyph = ListColorShades.glyph(RGB(hex: 0x3E6EC5), dark: true)
    let expected = RGB(hex: 0x789AD6)
    for (got, want) in [(glyph.red, expected.red), (glyph.green, expected.green), (glyph.blue, expected.blue)] {
        #expect(abs(got - want) * 255 <= 1)
    }
}

@Test func theDarkTileIsTheBaseAtTwentyFourPercent() {
    let base = RGB(hex: 0x3E6EC5)
    let dark = ListColorShades.tile(base, dark: true)
    #expect(dark.opacity == 0.24)
    #expect(dark == RGB(hex: 0x3E6EC5, opacity: 0.24))
    #expect(ListColorShades.tile(base, dark: false) == RGB(hex: 0x3E6EC5, opacity: 0.15))
}

@Test func mixingMovesEachChannelTowardTheOtherAndKeepsTheOpacity() {
    let black = RGB(hex: 0x000000, opacity: 0.5)
    let white = RGB(hex: 0xFFFFFF)
    #expect(black.mixed(toward: white, by: 0) == black)
    let half = black.mixed(toward: white, by: 0.5)
    #expect(half.red == 0.5 && half.green == 0.5 && half.blue == 0.5)
    #expect(half.opacity == 0.5)
}

@Test func anUnknownIconNameAndNoNameDrawTheDefaultGlyph() {
    #expect(IconSet.symbol(nil) == "list.bullet")
    #expect(IconSet.symbol("no-such-icon") == "list.bullet")
    #expect(IconSet.symbol("") == "list.bullet")
}

@Test func theFiveBuiltInIconsResolve() {
    #expect(IconSet.symbol("tray") == "tray")
    #expect(IconSet.symbol("sun") == "sun.max")
    #expect(IconSet.symbol("calendar") == "calendar")
    #expect(IconSet.symbol("logbook") == "text.book.closed")
    #expect(IconSet.symbol("trash") == "trash")
}

@Test func rowTitleIsHeavierWithChildrenAndSmallerNested() {
    #expect(Typography.rowTitle(depth: 0, hasChildren: true) == .system(size: 17, weight: .semibold))
    #expect(Typography.rowTitle(depth: 0, hasChildren: false) == .system(size: 17, weight: .regular))
    #expect(Typography.rowTitle(depth: 1, hasChildren: false) == .system(size: 16, weight: .regular))
    #expect(Typography.rowTitle(depth: 3, hasChildren: true) == .system(size: 16, weight: .semibold))
}

/// On the main actor because `Color.resolve(in:)` reaches AppKit's dynamic provider, which answers on the main actor
/// only: a nonisolated version of this test hung `swift test` with no output (2026-10-26).
@Test @MainActor func aDynamicColourResolvesToEachAppearancesShade() {
    let light = RGB(hex: 0xE7EAF9)
    let dark = RGB(hex: 0x1A1917)
    let color = Palette.dynamic(light: light, dark: dark)
    for (scheme, want) in [(ColorScheme.light, light), (ColorScheme.dark, dark)] {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let got = color.resolve(in: environment)
        #expect(abs(Double(got.red) - want.red) < 0.01, "\(scheme)")
        #expect(abs(Double(got.green) - want.green) < 0.01, "\(scheme)")
        #expect(abs(Double(got.blue) - want.blue) < 0.01, "\(scheme)")
    }
}
