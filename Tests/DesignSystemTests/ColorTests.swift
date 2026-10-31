import Testing
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB

@Test func mixingMovesEachChannelTowardTheOtherAndKeepsTheOpacity() {
    let black = RGB(hex: 0x000000, opacity: 0.5)
    #expect(black.mixed(toward: .white, by: 0) == black)
    let half = black.mixed(toward: .white, by: 0.5)
    #expect(half.red == 0.5 && half.green == 0.5 && half.blue == 0.5)
    #expect(half.opacity == 0.5)
}

/// In the dark the canvas lays the accent at 24 % over the paper; mixed into one opaque colour, that comes to about
/// #212742.
@Test func theDarkAccentSoftIsThePaperMixedTowardTheAccent() {
    let dark = DesignSystem.Color.accentSoft.dark
    #expect(channelGap(dark, RGB(hex: 0x212742)) <= 1)
    #expect(dark.opacity == 1)
}

/// What stands on the accent, the glyphs of "+" and Done, is white in both appearances, as the accent is one blue in
/// both.
@Test func whatStandsOnTheAccentIsWhiteInBothAppearances() {
    #expect(DesignSystem.Color.onAccent.light == RGB(hex: 0xFFFFFF))
    #expect(DesignSystem.Color.onAccent.dark == RGB(hex: 0xFFFFFF))
}
