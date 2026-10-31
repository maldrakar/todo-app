// Sources/DesignSystem/Color.swift

extension DesignSystem {
    /// A colour as the canvas writes it, in sRGB with channels from 0 to 1: numbers and not a platform's colour, so
    /// that the rules that mix and fade colours are tested on numbers, on the host and on wasm32. Only this module
    /// spells a colour or derives one, so a platform reads the channels and makes none.
    public struct RGB: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let opacity: Double

        /// White, the surface's light shade and what a tile's glyph is lifted toward in the dark.
        static let white = RGB(hex: 0xFFFFFF)

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
    ///
    /// The look's colours are its static members, the canvas's (`Phone.dc.html`, `Main.dc.html`), and the colours of
    /// its components are members of `Components`, each component's under its own name, as a list's tile's are. A view
    /// takes a colour from here and never spells one, so it holds no condition on the appearance.
    public struct Color: Equatable, Sendable {
        public let light: RGB
        public let dark: RGB

        public static let paper = Color(light: RGB(hex: 0xFAF7F2), dark: RGB(hex: 0x1A1917))
        public static let surface = Color(light: .white, dark: RGB(hex: 0x24221F))
        public static let sidebar = Color(light: RGB(hex: 0xF2EDE5), dark: RGB(hex: 0x1F1E1B))
        public static let fill = Color(light: RGB(hex: 0xF0EBE3), dark: RGB(hex: 0x2E2B27))
        public static let line = Color(light: RGB(hex: 0xE8E2D8), dark: RGB(hex: 0x35322D))
        public static let ink = Color(light: RGB(hex: 0x1F1D1A), dark: RGB(hex: 0xEEEAE3))
        public static let ink2 = Color(light: RGB(hex: 0x625C53), dark: RGB(hex: 0xABA498))
        public static let ink3 = Color(light: RGB(hex: 0xA39C90), dark: RGB(hex: 0x6F6A62))
        public static let red = Color(light: RGB(hex: 0xC2362B), dark: RGB(hex: 0xF07468))

        /// The same blue in both appearances.
        public static let accent = Color(light: accentShade, dark: accentShade)

        /// What stands on the accent, the glyphs of the bar's "+" and Done: white in both appearances, as the accent is
        /// one blue in both.
        public static let onAccent = Color(light: .white, dark: .white)

        /// In the dark the canvas lays the accent at 24 % over the paper; the opaque colour that comes to is mixed
        /// here, so that nothing behind the view shows through it.
        public static let accentSoft = Color(
            light: RGB(hex: 0xE7EAF9), dark: paper.dark.mixed(toward: accentShade, by: 0.24))

        /// The accent's one shade, which both its appearances share and the dark accent soft mixes toward, spelled
        /// once.
        private static let accentShade = RGB(hex: 0x3653C9)
    }
}

extension DesignSystem.RGB {
    /// `0xRRGGBB`, as the canvas's files spell a colour. Internal, because only this module spells colours.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}
