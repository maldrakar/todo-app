// Sources/DesignSystemComponents/GlassButtonModel.swift

/// A round button on glass over the list screen's content, its way back and its "…" (`Phone.dc.html`, `.glass`):
/// `diameter` across, its glyph centred and moved `iconOffset` sideways, casting `shadow`, in points. A platform with
/// glass of its own puts it under the button; one without draws `surface` edged with `line`, the canvas's glass and its
/// hairline. Its numbers, its surface, its line and its shadow are the fields of its `GlassControlStyle`.
public struct GlassButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let style: GlassControlStyle

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the button sends.
    public let action: Action

    public init(icon: IconModel, style: GlassControlStyle, accessibilityLabel: String, action: Action) {
        self.icon = icon
        self.style = style
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
