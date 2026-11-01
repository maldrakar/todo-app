// Sources/DesignSystemComponents/ButtonLabelModel.swift

/// The look of a button, which a button and a menu button share: its glyph, its word after the glyph where it has one,
/// the words it reads aloud, and what it stands on (`FillModel`).
public struct ButtonLabelModel: Equatable, Sendable {
    public let icon: IconModel

    /// The word after the glyph, and nil for a button that is its glyph alone.
    public let title: TextModel?

    public let accessibilityLabel: String
    public let fill: FillModel

    public init(icon: IconModel, title: TextModel?, accessibilityLabel: String, fill: FillModel) {
        self.icon = icon
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.fill = fill
    }
}
