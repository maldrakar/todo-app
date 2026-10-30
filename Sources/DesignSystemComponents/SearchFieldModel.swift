// Sources/DesignSystemComponents/SearchFieldModel.swift

/// A search field as every platform draws it: a capsule, `leadingPadding` in from its start to its leading glyph, then
/// the placeholder, which takes the room left, then its trailing glyph in a cell `trailingCell` wide and high, and
/// `trailingPadding` at its end, `spacing` apart, in points. It holds no action, so a platform draws the field and
/// sends nothing from it.
public struct SearchFieldModel: Equatable, Sendable {
    public let placeholder: TextModel
    public let leadingIcon: IconModel
    public let trailingIcon: IconModel
    public let trailingCell: Double
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double

    public init(
        placeholder: TextModel,
        leadingIcon: IconModel,
        trailingIcon: IconModel,
        trailingCell: Double,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double
    ) {
        self.placeholder = placeholder
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.trailingCell = trailingCell
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
    }
}
