import Testing
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB

/// Each channel of `got` within one unit in 255 of `want`'s, the precision the canvas writes a hex to.
private func expectClose(_ got: RGB, _ want: RGB, sourceLocation: SourceLocation = #_sourceLocation) {
    for (channel, wanted) in [(got.red, want.red), (got.green, want.green), (got.blue, want.blue)] {
        #expect(abs(channel - wanted) * 255 <= 1, sourceLocation: sourceLocation)
    }
}

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
    expectClose(dark, RGB(hex: 0x212742))
    #expect(dark.opacity == 1)
}
