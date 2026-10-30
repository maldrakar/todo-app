// Sources/DesignSystemComponents/TileModel.swift
import DesignSystem

/// A list's tile as every platform draws it: a rounded square in its colour's background, with the icon's glyph on it
/// in its colour's glyph colour (`docs/specs/lists-screen.md`, section 9). The model holds every visual parameter of
/// the tile, so a platform's view draws it and decides nothing; the corners are circular, as the canvas's
/// `border-radius` draws them (ADR-0007, amendment of 2026-10-26). It is plain data: the colour, the icon and the sizes
/// are its caller's, the feature module that builds its screen's model and knows the layout the tile stands in, and
/// the glyph's weight is the tile's own style.
///
/// `TileModel` was the module's first top-level name, probed free as `DesignSystem` was: unresolved in a file importing
/// SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-26). The fourteen
/// beside it were probed the same way on 2026-10-30.
public struct TileModel: Equatable, Sendable {
    /// The glyph on the tile: its icon, size and weight.
    public struct Glyph: Equatable, Sendable {
        public let icon: DesignSystem.Icon
        public let size: Double
        public let weight: DesignSystem.Font.Weight
    }

    /// The tile's colour: a platform fills the tile with its background and draws the glyph in its glyph colour.
    public let color: DesignSystem.Color.Components.Tile
    public let glyph: Glyph

    /// The length of the tile's side and the radius of its corners, in points.
    public let side: Double
    public let cornerRadius: Double

    /// A list's tile of the colour and icon its caller read from the store's names, at the sizes its layout calls for:
    /// the tile's side and corner radius and the glyph's size, in points.
    public init(
        color: DesignSystem.Color.Components.Tile,
        icon: DesignSystem.Icon,
        side: Double,
        cornerRadius: Double,
        glyphSize: Double
    ) {
        self.color = color
        glyph = Glyph(icon: icon, size: glyphSize, weight: .medium)
        self.side = side
        self.cornerRadius = cornerRadius
    }
}
