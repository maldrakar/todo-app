// Sources/DesignSystemComponents/GlassButtonLabelModel.swift

/// The look of a round button on glass over the list screen's content, which its way back and its "…" share
/// (`Phone.dc.html`, `.glass`): `diameter` across, its glyph centred and moved `iconOffset` sideways, casting `shadow`,
/// in points. A platform with glass of its own puts it under the button; one without draws `surface` edged with `line`,
/// the canvas's glass and its hairline. Its numbers, its surface, its line and its shadow are the fields of its
/// `GlassControlStyle`. A button that sends an action is a `GlassButtonModel`; "…" is this look as the label of the
/// menu its screen holds, as `ButtonLabelModel` is a button's and a menu button's.
///
/// `GlassButtonLabelModel` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation
/// and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-08).
public struct GlassButtonLabelModel: Equatable, Sendable {
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
