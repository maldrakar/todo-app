import Testing
import DesignSystemTestSupport
import DesignSystemComponents
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB

/// A tile of the colour and icon at one set of sizes: the sizes are the caller's, and the tile's style holds at any.
private func tile(_ color: DesignSystem.ListColor?, _ icon: DesignSystem.Icon?) -> TileModel {
    TileModel(color: color, icon: icon, side: 30, cornerRadius: 8, glyphSize: 19)
}

/// `Main.dc.html` draws the Inbox's glyph as #385EA3, which is blue's base mixed a fifth toward the ink, so the rule
/// here is the canvas's and not a guess at it.
@Test func theLightGlyphOfBlueIsTheCanvassBlue() {
    let glyph = tile(.blue, .tray).glyph.color.light
    #expect(channelGap(glyph, RGB(hex: 0x385EA3)) <= 1)
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func theDarkGlyphOfBlueIsLiftedTowardWhite() {
    let glyph = tile(.blue, .tray).glyph.color.dark
    #expect(channelGap(glyph, RGB(hex: 0x789AD6)) <= 1)
    #expect(glyph.opacity == 1)
}

@Test func theTileIsTheBaseAtFifteenPercentLightAndTwentyFourDark() {
    let color = tile(.blue, .tray).color
    #expect(color.light == RGB(hex: 0x3E6EC5, opacity: 0.15))
    #expect(color.dark == RGB(hex: 0x3E6EC5, opacity: 0.24))
}

/// A list with no colour draws stone's tile and glyph, and stone's are drawn from the base `Phone.dc.html` spells for
/// stone.
@Test func aListWithNoColourDrawsStonesShades() {
    let none = tile(nil, nil)
    #expect(none == tile(.stone, nil))
    #expect(none.color.dark == RGB(hex: 0x8A847A, opacity: 0.24))
}

/// The sizes are the caller's, the feature module that builds its screen's model, and the tile carries them as they
/// came, each where it belongs.
@Test func theTileCarriesTheSizesItWasGiven() {
    let model = TileModel(color: .blue, icon: .tray, side: 26, cornerRadius: 7, glyphSize: 16)
    #expect([model.side, model.cornerRadius, model.glyph.size] == [26, 7, 16])
}

/// The glyph is medium at any size, and carries the icon it was given; no icon is left to the platform's default
/// glyph.
@Test func theGlyphIsMediumAndCarriesTheIcon() {
    let model = tile(.green, .logbook)
    #expect(model.glyph.weight == .medium)
    #expect(model.glyph.icon == .logbook)
    #expect(tile(.green, nil).glyph.icon == nil)
}
