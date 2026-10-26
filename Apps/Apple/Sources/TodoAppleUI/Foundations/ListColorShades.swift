// Apps/Apple/Sources/TodoAppleUI/Foundations/ListColorShades.swift
import SwiftUI
import TodoCore

/// The two shades a list colour draws in, the tile behind a glyph and the glyph on it, each following the appearance.
struct ListColorShades: Equatable {
    let tile: Color
    let glyph: Color

    /// One entry for every colour a list can have.
    static let byName: [TaskViewColor: ListColorShades] =
        Dictionary(uniqueKeysWithValues: TaskViewColor.allCases.map { ($0, $0 == .stone ? noColor : painted(base($0))) })

    /// What a list with no colour draws: stone's shades, the very ones `byName` holds for stone, since a dynamic
    /// `Color` is equal only to itself and a second copy would not compare equal. Private, because a name `none` would
    /// read as `Optional.none` next to `byName`'s optionals.
    private static let noColor = painted(base(.stone))

    static func shades(of color: TaskViewColor?) -> ListColorShades {
        color.flatMap { byName[$0] } ?? noColor
    }

    /// The tile is the base at 15 % opacity in the light and 24 % in the dark, the canvas's `paint` rule
    /// (`Phone.dc.html`).
    static func tile(_ base: RGB, dark: Bool) -> RGB {
        RGB(red: base.red, green: base.green, blue: base.blue, opacity: dark ? 0.24 : 0.15)
    }

    /// The glyph is the base mixed 20 % toward the ink in the light and 30 % toward white in the dark, the same rule.
    static func glyph(_ base: RGB, dark: Bool) -> RGB {
        dark ? base.mixed(toward: RGB(hex: 0xFFFFFF), by: 0.3) : base.mixed(toward: Palette.lightInk, by: 0.2)
    }

    private static func painted(_ base: RGB) -> ListColorShades {
        ListColorShades(
            tile: Palette.dynamic(light: tile(base, dark: false), dark: tile(base, dark: true)),
            glyph: Palette.dynamic(light: glyph(base, dark: false), dark: glyph(base, dark: true)))
    }

    /// The base of each colour (`Phone.dc.html`, `COLORS`). A `switch` without a `default`, so a colour added to the
    /// core stops this compiling until it has one.
    private static func base(_ color: TaskViewColor) -> RGB {
        switch color {
        case .blue: RGB(hex: 0x3E6EC5)
        case .amber: RGB(hex: 0xD49408)
        case .rose: RGB(hex: 0xD2455A)
        case .green: RGB(hex: 0x36925C)
        case .stone: RGB(hex: 0x8A847A)
        case .indigo: RGB(hex: 0x5B55D8)
        case .teal: RGB(hex: 0x168985)
        case .pink: RGB(hex: 0xC64C88)
        case .orange: RGB(hex: 0xD7652C)
        case .violet: RGB(hex: 0x8452C8)
        case .sky: RGB(hex: 0x2A86B9)
        }
    }
}
