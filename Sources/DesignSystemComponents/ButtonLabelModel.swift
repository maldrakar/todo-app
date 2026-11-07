// Sources/DesignSystemComponents/ButtonLabelModel.swift

/// The look of a button, which a button and a menu button share: its glyph, its word after the glyph where it has one,
/// the words it reads aloud, and what it stands on (`ControlFillStyle`), which is the `fill` of its `ButtonLabelStyle`.
public struct ButtonLabelModel: Equatable, Sendable {
    public let icon: IconModel

    /// The word after the glyph, and nil for a button that is its glyph alone.
    public let title: TextModel?

    public let accessibilityLabel: String
    public let style: ButtonLabelStyle

    public init(icon: IconModel, title: TextModel?, accessibilityLabel: String, style: ButtonLabelStyle) {
        self.icon = icon
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.style = style
    }
}
