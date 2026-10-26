import Testing
import TodoCore
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB

/// Each channel of `got` within one unit in 255 of `want`'s, the precision the canvas writes a hex to.
private func expectClose(_ got: RGB, _ want: RGB, sourceLocation: SourceLocation = #_sourceLocation) {
    for (channel, wanted) in [(got.red, want.red), (got.green, want.green), (got.blue, want.blue)] {
        #expect(abs(channel - wanted) * 255 <= 1, sourceLocation: sourceLocation)
    }
}

/// `Main.dc.html` draws the Inbox's glyph as #385EA3, which is blue's base mixed a fifth toward the ink, so the rule
/// here is the canvas's and not a guess at it.
@Test func theLightGlyphOfBlueIsTheCanvassBlue() {
    let glyph = DesignSystem.color.list(.blue).glyph.light
    expectClose(glyph, RGB(hex: 0x385EA3))
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func theDarkGlyphOfBlueIsLiftedTowardWhite() {
    let glyph = DesignSystem.color.list(.blue).glyph.dark
    expectClose(glyph, RGB(hex: 0x789AD6))
    #expect(glyph.opacity == 1)
}

@Test func theDarkTileIsTheBaseAtTwentyFourPercent() {
    let tile = DesignSystem.color.list(.blue).tile
    #expect(tile.dark == RGB(hex: 0x3E6EC5, opacity: 0.24))
    #expect(tile.light == RGB(hex: 0x3E6EC5, opacity: 0.15))
}

@Test func mixingMovesEachChannelTowardTheOtherAndKeepsTheOpacity() {
    let black = RGB(hex: 0x000000, opacity: 0.5)
    let white = RGB(hex: 0xFFFFFF)
    #expect(black.mixed(toward: white, by: 0) == black)
    let half = black.mixed(toward: white, by: 0.5)
    #expect(half.red == 0.5 && half.green == 0.5 && half.blue == 0.5)
    #expect(half.opacity == 0.5)
}

/// A list with no colour draws stone's shades, and stone's are drawn from the base `Phone.dc.html` spells for stone.
@Test func aListWithNoColourDrawsStonesShades() {
    #expect(DesignSystem.color.list(nil) == DesignSystem.color.list(.stone))
    #expect(DesignSystem.color.list(.stone).tile.dark == RGB(hex: 0x8A847A, opacity: 0.24))
}

/// In the dark the canvas lays the accent at 24 % over the paper; mixed into one opaque colour, that comes to about
/// #212742.
@Test func theDarkAccentSoftIsThePaperMixedTowardTheAccent() {
    let dark = DesignSystem.color.accentSoft.dark
    expectClose(dark, RGB(hex: 0x212742))
    #expect(dark.opacity == 1)
}
