import Testing
import DesignSystem
import DesignSystemComponents

/// The tile is plain data: it carries the colour, the icon and the sizes its caller gave it, each where it belongs.
@Test func theTileCarriesTheColourIconAndSizesItWasGiven() {
    let model = TileModel(
        icon: .logbook,
        style: TileStyle(color: .green, side: 26, cornerRadius: 7, glyphSize: 16, glyphWeight: .medium)
    )
    #expect(model.style.color == .green)
    #expect(model.icon == .logbook)
    #expect([model.style.side, model.style.cornerRadius, model.style.glyphSize] == [26, 7, 16])
}

/// The glyph's weight is the caller's, as its size is: what draws the tile picks none.
@Test func theTileCarriesTheGlyphWeightItWasGiven() {
    let model = TileModel(
        icon: .tray,
        style: TileStyle(color: .blue, side: 30, cornerRadius: 8, glyphSize: 19, glyphWeight: .semibold)
    )
    #expect(model.style.glyphWeight == .semibold)
}
