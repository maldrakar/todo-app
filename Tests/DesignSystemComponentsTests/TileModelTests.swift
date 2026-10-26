import Testing
import DesignSystem
import DesignSystemComponents

/// The tile is plain data: it carries the colour, the icon and the sizes its caller gave it, each where it belongs.
@Test func theTileCarriesTheColourIconAndSizesItWasGiven() {
    let model = TileModel(color: .green, icon: .logbook, side: 26, cornerRadius: 7, glyphSize: 16)
    #expect(model.color == .green)
    #expect(model.glyph.icon == .logbook)
    #expect([model.side, model.cornerRadius, model.glyph.size] == [26, 7, 16])
}

/// The glyph's weight is the tile's own style, medium at any size.
@Test func theGlyphIsMedium() {
    let model = TileModel(color: .blue, icon: .tray, side: 30, cornerRadius: 8, glyphSize: 19)
    #expect(model.glyph.weight == .medium)
}
