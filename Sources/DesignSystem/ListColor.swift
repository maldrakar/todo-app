// Sources/DesignSystem/ListColor.swift

extension DesignSystem {
    /// The colours a list's tile can have, by the names the store keeps for them, each with its base, from which a
    /// tile derives its shades. The design system names them itself, so that the look knows nothing of the domain: the
    /// feature module that builds a tile reads a view's colour as one of these by its name with `init(rawValue:)`, and
    /// a root test holds the two lists of names together (ADR-0007, amendment of 2026-10-26).
    public enum ListColor: String, Sendable, CaseIterable {
        case blue, amber, rose, green, stone, indigo, teal, pink, orange, violet, sky

        /// The base of each list colour (`Phone.dc.html`, `COLORS`). A `switch` without a `default`, so a colour
        /// added here stops this compiling until it has a base.
        public var base: RGB {
            switch self {
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
