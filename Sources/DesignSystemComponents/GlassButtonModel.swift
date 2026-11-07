// Sources/DesignSystemComponents/GlassButtonModel.swift

/// A round button on glass over the list screen's content, its way back and its "…" (`Phone.dc.html`, `.glass`):
/// `diameter` across, its glyph centred and moved `iconOffset` sideways, casting `shadow`, in points. A platform with
/// glass of its own puts it under the button; one without draws `surface` edged with `line`, the canvas's glass and its
/// hairline. Its numbers, its surface, its line and its shadow are the fields of its `GlassControlStyle`.
///
/// It sends nothing: what a tap on it does is its screen's, the way back being the window's stack's and "…" a menu
/// the screen holds (`TaskList.Model.back` and `more`).
public struct GlassButtonModel: Equatable, Sendable {
    public let icon: IconModel
    public let style: GlassControlStyle

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    public init(icon: IconModel, style: GlassControlStyle, accessibilityLabel: String) {
        self.icon = icon
        self.style = style
        self.accessibilityLabel = accessibilityLabel
    }
}
