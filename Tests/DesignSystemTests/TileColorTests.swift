import Testing
import TodoCore
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB
private typealias Tile = DesignSystem.Color.Components.Tile

/// `Main.dc.html` draws the Inbox's glyph as #385EA3, which is blue's base mixed a fifth toward the ink, so the rule
/// here is the canvas's and not a guess at it.
@Test func blueTilesLightGlyphIsTheCanvassBlue() {
    let glyph = Tile.blue.glyph.light
    #expect(channelGap(glyph, RGB(hex: 0x385EA3)) <= 1)
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func blueTilesDarkGlyphIsLiftedTowardWhite() {
    let glyph = Tile.blue.glyph.dark
    #expect(channelGap(glyph, RGB(hex: 0x789AD6)) <= 1)
    #expect(glyph.opacity == 1)
}

@Test func blueTilesBackgroundIsItsBaseAtFifteenPercentLightAndTwentyFourDark() {
    let background = Tile.blue.background
    #expect(background.light == RGB(hex: 0x3E6EC5, opacity: 0.15))
    #expect(background.dark == RGB(hex: 0x3E6EC5, opacity: 0.24))
}

/// Stone's tile, which the feature module that builds a tile picks for a list with no colour, is drawn from the base
/// `Phone.dc.html` spells for stone.
@Test func stoneTilesBackgroundIsDrawnFromStonesBase() {
    #expect(Tile.stone.background.dark == RGB(hex: 0x8A847A, opacity: 0.24))
}

/// The design system names the tile's colours itself, so that the look knows nothing of the domain, and the feature
/// module that builds a tile reads a view's colour as a tile colour by its name with `init(rawValue:)`. The two lists
/// agree because this test holds them together: every colour the store can keep is a tile colour, and every tile
/// colour is one it can keep.
@Test func theStoreAndTheDesignSystemNameTheSameTileColours() {
    for color in TaskViewColor.allCases {
        #expect(Tile(rawValue: color.rawValue) != nil, "\(color)")
    }
    for color in Tile.allCases {
        #expect(TaskViewColor(rawValue: color.rawValue) != nil, "\(color)")
    }
}
