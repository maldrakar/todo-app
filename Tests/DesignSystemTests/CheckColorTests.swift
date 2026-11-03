import Testing
@testable import DesignSystem

private typealias RGB = DesignSystem.RGB
private typealias Tile = DesignSystem.Color.Components.Tile

/// A check in one appearance as the canvas resolves it: the ring of an open check, the fill of a checked one and the
/// mark on the fill.
private struct Resolved {
    let ring: UInt32
    let fill: UInt32
    let mark: UInt32
}

/// What the canvas's `paint` (`Phone.dc.html`, the same in `Mac.dc.html`) resolves each tile colour's check to, in the
/// light and in the dark, run over its `COLORS` as the canvas runs it, each channel rounded to a byte.
private let canvas: [Tile: (light: Resolved, dark: Resolved)] = [
    .blue: (
        Resolved(ring: 0x385EA3, fill: 0x3E6EC5, mark: 0xFFFFFF),
        Resolved(ring: 0x6188CF, fill: 0x4D7ACA, mark: 0xFFFFFF)
    ),
    .amber: (
        Resolved(ring: 0xB07C0C, fill: 0xD49408, mark: 0x1F1D1A),
        Resolved(ring: 0xDCA734, fill: 0xD79D1C, mark: 0x1F1D1A)
    ),
    .rose: (
        Resolved(ring: 0xAE3D4D, fill: 0xD2455A, mark: 0xFFFFFF),
        Resolved(ring: 0xDA6678, fill: 0xD65467, mark: 0xFFFFFF)
    ),
    .green: (
        Resolved(ring: 0x317B4F, fill: 0x36925C, mark: 0xFFFFFF),
        Resolved(ring: 0x5AA679, fill: 0x469B69, mark: 0xFFFFFF)
    ),
    .stone: (
        Resolved(ring: 0x756F67, fill: 0x8A847A, mark: 0xFFFFFF),
        Resolved(ring: 0x9F9A92, fill: 0x938E85, mark: 0xFFFFFF)
    ),
    .indigo: (
        Resolved(ring: 0x4F4AB2, fill: 0x5B55D8, mark: 0xFFFFFF),
        Resolved(ring: 0x7974DF, fill: 0x6863DB, mark: 0xFFFFFF)
    ),
    .teal: (
        Resolved(ring: 0x187370, fill: 0x168985, mark: 0xFFFFFF),
        Resolved(ring: 0x409E9B, fill: 0x29928F, mark: 0xFFFFFF)
    ),
    .pink: (
        Resolved(ring: 0xA54372, fill: 0xC64C88, mark: 0xFFFFFF),
        Resolved(ring: 0xD06C9D, fill: 0xCB5A92, mark: 0xFFFFFF)
    ),
    .orange: (
        Resolved(ring: 0xB25728, fill: 0xD7652C, mark: 0xFFFFFF),
        Resolved(ring: 0xDE8152, fill: 0xDA713D, mark: 0xFFFFFF)
    ),
    .violet: (
        Resolved(ring: 0x7047A5, fill: 0x8452C8, mark: 0xFFFFFF),
        Resolved(ring: 0x9A71D2, fill: 0x8E60CC, mark: 0xFFFFFF)
    ),
    .sky: (
        Resolved(ring: 0x287199, fill: 0x2A86B9, mark: 0xFFFFFF),
        Resolved(ring: 0x509CC6, fill: 0x3B90BF, mark: 0xFFFFFF)
    ),
]

/// Every tile colour's check is the canvas's: its ring, fill and mark in both appearances, each opaque, within a
/// channel of the hex the canvas writes, since the canvas rounds each mixed channel to a byte and the look does not.
@Test func everyTilesCheckMatchesTheCanvas() {
    #expect(Set(canvas.keys) == Set(Tile.allCases))
    for (tile, want) in canvas {
        let check = tile.check
        let shades: [(String, RGB, UInt32)] = [
            ("light ring", check.ring.light, want.light.ring), ("light fill", check.fill.light, want.light.fill),
            ("light mark", check.mark.light, want.light.mark), ("dark ring", check.ring.dark, want.dark.ring),
            ("dark fill", check.fill.dark, want.dark.fill), ("dark mark", check.mark.dark, want.dark.mark),
        ]
        for (name, got, hex) in shades {
            #expect(channelGap(got, RGB(hex: hex)) <= 1, "\(tile) \(name)")
            #expect(got.opacity == 1, "\(tile) \(name)")
        }
    }
}

/// White's contrast on amber's fill is 2.61 in the light and 2.41 in the dark, under the canvas's 3, so amber alone
/// draws its mark in the light ink, in both appearances; the next lowest, dark stone and dark orange, come to 3.26 and
/// 3.28 and draw it white.
@Test func amberAloneDrawsItsMarkInInk() {
    for tile in Tile.allCases {
        let want = tile == .amber ? RGB(hex: 0x1F1D1A) : RGB(hex: 0xFFFFFF)
        #expect(tile.check.mark.light == want, "\(tile)")
        #expect(tile.check.mark.dark == want, "\(tile)")
    }
}

/// The glass under the list screen's round buttons, its hairline and a just-landed row's highlight are the canvas's
/// (`Phone.dc.html`, `--glass`, `--glassline`, `--fresh`): white and #322F2B at 72 %, the ink and white at 8 %, and the
/// default accent at 12 % and white at 8 %.
@Test func theGlassTheLineAndTheFreshShadesAreTheCanvass() {
    let glass = DesignSystem.Color.glass
    #expect(glass.light == RGB(hex: 0xFFFFFF, opacity: 0.72))
    #expect(glass.dark == RGB(hex: 0x322F2B, opacity: 0.72))
    let glassLine = DesignSystem.Color.glassLine
    #expect(glassLine.light == RGB(hex: 0x1F1D1A, opacity: 0.08))
    #expect(glassLine.dark == RGB(hex: 0xFFFFFF, opacity: 0.08))
    let fresh = DesignSystem.Color.fresh
    #expect(fresh.light == RGB(hex: 0x3653C9, opacity: 0.12))
    #expect(fresh.dark == RGB(hex: 0xFFFFFF, opacity: 0.08))
}
