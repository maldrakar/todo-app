// Sources/DesignSystem/Color+Components.swift

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

        /// The base of each tile colour (`Phone.dc.html`, `COLORS`), from which the canvas's `paint` rule draws its
        /// background and its glyph, so that those are the canvas's and not 44 shades worked out by hand. A `switch`
        /// without a `default`, so a colour added here stops this compiling until it has a base.
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
    }
}

extension DesignSystem.RGB {
    /// This colour at `opacity`, its channels kept.
    fileprivate func withOpacity(_ opacity: Double) -> DesignSystem.RGB {
        DesignSystem.RGB(red: red, green: green, blue: blue, opacity: opacity)
    }
}
