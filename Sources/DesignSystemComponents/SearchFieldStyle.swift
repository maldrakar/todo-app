// Sources/DesignSystemComponents/SearchFieldStyle.swift

/// The numbers a `SearchFieldModel` is drawn with, in points, and what it stands on, which a builder hands over as one
/// value.
public struct SearchFieldStyle: Equatable, Sendable {
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let fill: ControlFillStyle

    /// The radius of the field's corners, half its height for a capsule.
    public let cornerRadius: Double

    /// The side of the square cell the glyph at the field's end is centred in, wide and high, in points, and nil for a
    /// field with no such glyph.
    public let trailingGlyphCell: Double?

    public init(
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        fill: ControlFillStyle,
        cornerRadius: Double,
        trailingGlyphCell: Double?
    ) {
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.trailingGlyphCell = trailingGlyphCell
    }
}
