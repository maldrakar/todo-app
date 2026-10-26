// Sources/DesignSystem/Palette.swift
import TodoCore

extension DesignSystem {
    /// A colour as the canvas writes it, in sRGB with channels from 0 to 1: numbers and not a platform's colour, so
    /// that the rules that mix and fade colours are tested on numbers, on the host and on wasm32.
    public struct RGB: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let opacity: Double

        /// This colour moved `amount` of the way toward `other`, channel by channel, keeping its own opacity.
        func mixed(toward other: RGB, by amount: Double) -> RGB {
            RGB(
                red: red + (other.red - red) * amount,
                green: green + (other.green - green) * amount,
                blue: blue + (other.blue - blue) * amount,
                opacity: opacity)
        }
    }

    /// One colour of the look: its shade in the light appearance and its shade in the dark, between which a platform
    /// switches as the appearance changes.
    public struct Color: Equatable, Sendable {
        public let light: RGB
        public let dark: RGB
    }

    /// A list colour's two colours: the tile behind the glyph, and the glyph.
    public struct TileColors: Equatable, Sendable {
        public let tile: Color
        public let glyph: Color
    }

    /// The canvas's colours (`Phone.dc.html`, `Main.dc.html`), and the list colours' tiles and glyphs derived from
    /// their bases. A view takes a colour from here and never spells one, so it holds no condition on the appearance.
    public struct Palette: Sendable {
        public let paper = Color(light: RGB(hex: 0xFAF7F2), dark: Self.darkPaper)
        public let surface = Color(light: Self.white, dark: RGB(hex: 0x24221F))
        public let sidebar = Color(light: RGB(hex: 0xF2EDE5), dark: RGB(hex: 0x1F1E1B))
        public let fill = Color(light: RGB(hex: 0xF0EBE3), dark: RGB(hex: 0x2E2B27))
        public let line = Color(light: RGB(hex: 0xE8E2D8), dark: RGB(hex: 0x35322D))
        public let ink = Color(light: Self.lightInk, dark: RGB(hex: 0xEEEAE3))
        public let ink2 = Color(light: RGB(hex: 0x625C53), dark: RGB(hex: 0xABA498))
        public let ink3 = Color(light: RGB(hex: 0xA39C90), dark: RGB(hex: 0x6F6A62))
        public let red = Color(light: RGB(hex: 0xC2362B), dark: RGB(hex: 0xF07468))

        /// The same blue in both appearances.
        public let accent = Color(light: Self.accentRGB, dark: Self.accentRGB)

        /// In the dark the canvas lays the accent at 24 % over the paper; the opaque colour that comes to is mixed
        /// here, so that nothing behind the view shows through it.
        public let accentSoft = Color(light: RGB(hex: 0xE7EAF9), dark: Self.darkPaper.mixed(toward: Self.accentRGB, by: 0.24))

        /// The shades that the colours above share and that the glyph rule below mixes toward, each spelled once.
        private static let darkPaper = RGB(hex: 0x1A1917)
        private static let lightInk = RGB(hex: 0x1F1D1A)
        private static let white = RGB(hex: 0xFFFFFF)
        private static let accentRGB = RGB(hex: 0x3653C9)

        /// A list colour's tile and glyph, both derived from its base by the canvas's `paint` rule (`Phone.dc.html`);
        /// a list with no colour draws stone's.
        public func list(_ color: TaskViewColor?) -> TileColors {
            let base = Self.base(color ?? .stone)
            return TileColors(
                tile: Color(light: Self.tile(base, dark: false), dark: Self.tile(base, dark: true)),
                glyph: Color(light: Self.glyph(base, dark: false), dark: Self.glyph(base, dark: true)))
        }

        /// The tile is the base at 15 % opacity in the light and 24 % in the dark.
        private static func tile(_ base: RGB, dark: Bool) -> RGB {
            RGB(red: base.red, green: base.green, blue: base.blue, opacity: dark ? 0.24 : 0.15)
        }

        /// The glyph is the base mixed 20 % toward the ink in the light and 30 % toward white in the dark.
        private static func glyph(_ base: RGB, dark: Bool) -> RGB {
            dark ? base.mixed(toward: white, by: 0.3) : base.mixed(toward: lightInk, by: 0.2)
        }

        /// The base of each list colour (`Phone.dc.html`, `COLORS`). A `switch` without a `default`, so a colour added
        /// to the core stops this compiling until it has a base.
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
}

extension DesignSystem.RGB {
    /// `0xRRGGBB`, as the canvas's files spell a colour. Internal, because only the palette spells colours.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}
