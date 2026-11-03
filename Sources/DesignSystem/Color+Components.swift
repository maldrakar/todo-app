// Sources/DesignSystem/Color+Components.swift

// The C library for `pow`, which a check's mark needs for WCAG's luminance and the standard library does not have; the
// platform's own, on each platform the look is built for.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

extension DesignSystem.Color {
    /// The colours of the components every platform draws, each component's under its own name, so that a component's
    /// model takes only the colours its component may use (ADR-0007, amendment of 2026-10-26).
    public enum Components {}
}

extension DesignSystem.Color.Components {
    /// The colours a list's tile can take, by the names the store keeps for them, each the tile's background and the
    /// colour of the glyph on it. The design system names them itself, so that the look knows nothing of the domain:
    /// the feature module that builds a tile reads a view's colour as one of these by its name with `init(rawValue:)`,
    /// and a root test holds the two lists of names together (ADR-0007, amendment of 2026-10-26).
    public enum Tile: String, Sendable, CaseIterable {
        case blue, amber, rose, green, stone, indigo, teal, pink, orange, violet, sky

        /// The tile, its base at 15 % opacity in the light and 24 % in the dark (`Phone.dc.html`, `paint`).
        public var background: DesignSystem.Color {
            DesignSystem.Color(light: base.withOpacity(0.15), dark: base.withOpacity(0.24))
        }

        /// The glyph on the tile, its base mixed 20 % toward the ink in the light and 30 % toward white in the dark
        /// (`Phone.dc.html`, `paint`).
        public var glyph: DesignSystem.Color {
            DesignSystem.Color(
                light: base.mixed(toward: DesignSystem.Color.ink.light, by: 0.2),
                dark: base.mixed(toward: .white, by: 0.3))
        }

        /// The check of a task in this colour (`Phone.dc.html`, `paint`): its ring the base mixed 20 % toward the ink
        /// in the light and 18 % toward white in the dark, its fill the base in the light and the base mixed 8 % toward
        /// white in the dark, and its mark on the fill of the same appearance.
        public var check: DesignSystem.Color.Components.Check {
            let fill = DesignSystem.Color(light: base, dark: base.mixed(toward: .white, by: 0.08))
            return DesignSystem.Color.Components.Check(
                ring: DesignSystem.Color(
                    light: base.mixed(toward: DesignSystem.Color.ink.light, by: 0.2),
                    dark: base.mixed(toward: .white, by: 0.18)),
                fill: fill,
                mark: DesignSystem.Color(light: Self.mark(on: fill.light), dark: Self.mark(on: fill.dark)))
        }

        /// The base of each tile colour (`Phone.dc.html`, `COLORS`), from which the canvas's `paint` rule draws its
        /// background, its glyph and its check, so that those are the canvas's and not 110 shades worked out by hand.
        /// A `switch` without a `default`, so a colour added here stops this compiling until it has a base.
        private var base: DesignSystem.RGB {
            switch self {
            case .blue: DesignSystem.RGB(hex: 0x3E6EC5)
            case .amber: DesignSystem.RGB(hex: 0xD49408)
            case .rose: DesignSystem.RGB(hex: 0xD2455A)
            case .green: DesignSystem.RGB(hex: 0x36925C)
            case .stone: DesignSystem.RGB(hex: 0x8A847A)
            case .indigo: DesignSystem.RGB(hex: 0x5B55D8)
            case .teal: DesignSystem.RGB(hex: 0x168985)
            case .pink: DesignSystem.RGB(hex: 0xC64C88)
            case .orange: DesignSystem.RGB(hex: 0xD7652C)
            case .violet: DesignSystem.RGB(hex: 0x8452C8)
            case .sky: DesignSystem.RGB(hex: 0x2A86B9)
            }
        }

        /// The mark on a check's fill, by the canvas's rule: white, unless white's contrast on the fill is under 3,
        /// when it is the light ink in either appearance, since the dark ink is nearly white. Amber alone is under 3.
        private static func mark(on fill: DesignSystem.RGB) -> DesignSystem.RGB {
            DesignSystem.RGB.white.contrast(with: fill) >= 3 ? .white : DesignSystem.Color.ink.light
        }
    }

    /// A task's check in a list's colour (`Tile.check`): the ring of an open check, whose inside stays clear; the fill
    /// of a checked one, which it draws as its ring too, so that a checked check is a disc; and the mark drawn on the
    /// fill. Which of them a check draws is its view's to read from whether it is checked.
    public struct Check: Equatable, Sendable {
        public let ring: DesignSystem.Color
        public let fill: DesignSystem.Color
        public let mark: DesignSystem.Color
    }
}

extension DesignSystem.RGB {
    /// The contrast between this colour and `other` as WCAG 2 defines it and the canvas works it out (`contrast`),
    /// from 1, none, to 21, black on white. Opacity plays no part.
    fileprivate func contrast(with other: DesignSystem.RGB) -> Double {
        let (lighter, darker) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// WCAG 2's relative luminance, each channel turned linear with the canvas's threshold of 0.03928 (`lum`).
    private var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
