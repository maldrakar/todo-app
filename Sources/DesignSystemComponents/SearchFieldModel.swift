// Sources/DesignSystemComponents/SearchFieldModel.swift

/// A search field as every platform draws it: `leadingPadding` in from its start its leading glyph, then the
/// placeholder, which takes the room left, then its trailing glyph where it has one, centred in a square cell
/// `trailingGlyphCell` wide and high, and `trailingPadding` at its end, `spacing` apart, on what it stands on
/// (`ControlFillStyle`), with corners of `cornerRadius`, in points. It holds no action, so a platform draws the field
/// and sends nothing from it. Its numbers, its fill and its trailing glyph's cell are the fields of its
/// `SearchFieldStyle`.
public struct SearchFieldModel: Equatable, Sendable {
    public let placeholder: TextModel
    public let leadingIcon: IconModel

    /// The glyph at the field's end, and nil for a field with none.
    public let trailingGlyph: IconModel?

    public let style: SearchFieldStyle

    public init(placeholder: TextModel, leadingIcon: IconModel, trailingGlyph: IconModel?, style: SearchFieldStyle) {
        self.placeholder = placeholder
        self.leadingIcon = leadingIcon
        self.trailingGlyph = trailingGlyph
        self.style = style
    }
}
