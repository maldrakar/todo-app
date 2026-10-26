import Testing
import TodoCore
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB
private typealias Palette = DesignSystem.Palette

/// Each channel of `got` within one unit in 255 of `want`'s, the precision the canvas writes a hex to.
private func expectClose(_ got: RGB, _ want: RGB, sourceLocation: SourceLocation = #_sourceLocation) {
    for (channel, wanted) in [(got.red, want.red), (got.green, want.green), (got.blue, want.blue)] {
        #expect(abs(channel - wanted) * 255 <= 1, sourceLocation: sourceLocation)
    }
}

/// The tile and the glyph the rule gives a base, in both appearances.
private func shades(of base: RGB) -> DesignSystem.TileColors {
    DesignSystem.TileColors(
        tile: DesignSystem.Color(light: Palette.tile(base, dark: false), dark: Palette.tile(base, dark: true)),
        glyph: DesignSystem.Color(light: Palette.glyph(base, dark: false), dark: Palette.glyph(base, dark: true)))
}

/// `Main.dc.html` draws the Inbox's glyph as #385EA3, which is blue's base mixed a fifth toward the ink, so the rule
/// here is the canvas's and not a guess at it.
@Test func theLightGlyphOfBlueIsTheCanvassBlue() {
    let glyph = Palette.glyph(RGB(hex: 0x3E6EC5), dark: false)
    expectClose(glyph, RGB(hex: 0x385EA3))
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func theDarkGlyphOfBlueIsLiftedTowardWhite() {
    let glyph = Palette.glyph(RGB(hex: 0x3E6EC5), dark: true)
    expectClose(glyph, RGB(hex: 0x789AD6))
    #expect(glyph.opacity == 1)
}

@Test func theDarkTileIsTheBaseAtTwentyFourPercent() {
    let base = RGB(hex: 0x3E6EC5)
    #expect(Palette.tile(base, dark: true) == RGB(hex: 0x3E6EC5, opacity: 0.24))
    #expect(Palette.tile(base, dark: false) == RGB(hex: 0x3E6EC5, opacity: 0.15))
}

@Test func mixingMovesEachChannelTowardTheOtherAndKeepsTheOpacity() {
    let black = RGB(hex: 0x000000, opacity: 0.5)
    let white = RGB(hex: 0xFFFFFF)
    #expect(black.mixed(toward: white, by: 0) == black)
    let half = black.mixed(toward: white, by: 0.5)
    #expect(half.red == 0.5 && half.green == 0.5 && half.blue == 0.5)
    #expect(half.opacity == 0.5)
}

/// A list with no colour draws stone's shades, and a colour draws its own: each entry is the rule applied to the base
/// `Phone.dc.html` spells, so a typo in the palette's table of bases shows for stone and blue at least.
@Test func aListWithNoColourDrawsStonesShades() {
    #expect(DesignSystem.color.list(nil) == DesignSystem.color.list(.stone))
    #expect(DesignSystem.color.list(.stone) == shades(of: RGB(hex: 0x8A847A)))
    #expect(DesignSystem.color.list(.blue) == shades(of: RGB(hex: 0x3E6EC5)))
}

/// In the dark the canvas lays the accent at 24 % over the paper; mixed into one opaque colour, that comes to about
/// #212742.
@Test func theDarkAccentSoftIsThePaperMixedTowardTheAccent() {
    let dark = DesignSystem.color.accentSoft.dark
    expectClose(dark, RGB(hex: 0x212742))
    #expect(dark.opacity == 1)
}
