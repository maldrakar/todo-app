// Sources/DesignSystemComponents/TileStyle.swift
import DesignSystem

/// The numbers a `TileModel` is drawn with, in points, and its colour and the weight of its glyph, which a builder
/// hands over as one value.
public struct TileStyle: Equatable, Sendable {
    /// The tile's colour: a platform fills the tile with its background and draws the glyph in its glyph colour.
    public let color: DesignSystem.Color.Components.Tile

    /// The length of the tile's side and the radius of its corners, in points.
    public let side: Double
    public let cornerRadius: Double

    /// The glyph's size, in points, and its weight.
    public let glyphSize: Double
    public let glyphWeight: DesignSystem.Font.Weight

    public init(
        color: DesignSystem.Color.Components.Tile,
        side: Double,
        cornerRadius: Double,
        glyphSize: Double,
        glyphWeight: DesignSystem.Font.Weight
    ) {
        self.color = color
        self.side = side
        self.cornerRadius = cornerRadius
        self.glyphSize = glyphSize
        self.glyphWeight = glyphWeight
    }
}
