// Sources/DesignSystemComponents/SearchFieldModel.swift

/// A search field as every platform draws it: `leadingPadding` in from its start its leading glyph, then the
/// placeholder, which takes the room left, then its trailing glyph where it has one, and `trailingPadding` at its end,
/// `spacing` apart, on what it stands on (`FillModel`), with corners of `cornerRadius`, in points. It holds no action,
/// so a platform draws the field and sends nothing from it.
public struct SearchFieldModel: Equatable, Sendable {
    /// A glyph at the field's end, centred in a square cell `cell` wide and high, in points.
    public struct TrailingGlyph: Equatable, Sendable {
        public let icon: IconModel
        public let cell: Double

        public init(icon: IconModel, cell: Double) {
            self.icon = icon
            self.cell = cell
        }
    }

    public let placeholder: TextModel
    public let leadingIcon: IconModel

    /// The glyph at the field's end, and nil for a field with none.
    public let trailingGlyph: TrailingGlyph?

    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let fill: FillModel

    /// The radius of the field's corners, half its height for a capsule.
    public let cornerRadius: Double

    public init(
        placeholder: TextModel,
        leadingIcon: IconModel,
        trailingGlyph: TrailingGlyph?,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        fill: FillModel,
        cornerRadius: Double
    ) {
        self.placeholder = placeholder
        self.leadingIcon = leadingIcon
        self.trailingGlyph = trailingGlyph
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.fill = fill
        self.cornerRadius = cornerRadius
    }
}
