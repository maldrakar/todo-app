import Testing
import DesignSystemComponents
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
    let glyph = TileModel(color: .blue, icon: .tray, placement: .row(depth: 0)).glyph.color.light
    expectClose(glyph, RGB(hex: 0x385EA3))
    #expect(glyph.opacity == 1)
}

/// 0.7 x #3E6EC5 + 0.3 x white comes to #789AD6.
@Test func theDarkGlyphOfBlueIsLiftedTowardWhite() {
    let glyph = TileModel(color: .blue, icon: .tray, placement: .row(depth: 0)).glyph.color.dark
    expectClose(glyph, RGB(hex: 0x789AD6))
    #expect(glyph.opacity == 1)
}

@Test func theTileIsTheBaseAtFifteenPercentLightAndTwentyFourDark() {
    let tile = TileModel(color: .blue, icon: .tray, placement: .row(depth: 0)).color
    #expect(tile.light == RGB(hex: 0x3E6EC5, opacity: 0.15))
    #expect(tile.dark == RGB(hex: 0x3E6EC5, opacity: 0.24))
}

/// A list with no colour draws stone's tile and glyph, and stone's are drawn from the base `Phone.dc.html` spells for
/// stone.
@Test func aListWithNoColourDrawsStonesShades() {
    let none = TileModel(color: nil, icon: nil, placement: .sidebar)
    #expect(none == TileModel(color: .stone, icon: nil, placement: .sidebar))
    #expect(none.color.dark == RGB(hex: 0x8A847A, opacity: 0.24))
}

/// The canvas's sizes, the side, the corner radius and the glyph: 30, 8 and 19 pt at the root of the phone's tree and
/// 26, 7 and 16 nested (`Phone.dc.html`, `tileSize`), and 20, 6 and 13 in the sidebar's 30 pt row (`Mac.dc.html`). A
/// depth below the root, which no row has but a view could send, reads as the root.
@Test func eachPlacementHasTheCanvassSizes() {
    func sizes(_ placement: TileModel.Placement) -> [Double] {
        let model = TileModel(color: .blue, icon: .tray, placement: placement)
        return [model.side, model.cornerRadius, model.glyph.size]
    }
    #expect(sizes(.row(depth: 0)) == [30, 8, 19])
    #expect(sizes(.row(depth: 1)) == [26, 7, 16])
    #expect(sizes(.row(depth: 4)) == [26, 7, 16])
    #expect(sizes(.row(depth: -1)) == [30, 8, 19])
    #expect(sizes(.sidebar) == [20, 6, 13])
}

/// The glyph is medium wherever the tile sits, and carries the icon it was given; no icon is left to the platform's
/// default glyph.
@Test func theGlyphIsMediumAndCarriesTheIcon() {
    let model = TileModel(color: .green, icon: .logbook, placement: .row(depth: 2))
    #expect(model.glyph.weight == .medium)
    #expect(model.glyph.icon == .logbook)
    #expect(TileModel(color: .green, icon: nil, placement: .sidebar).glyph.icon == nil)
}
