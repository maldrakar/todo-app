// Sources/DesignSystemComponents/GlassButtonModel.swift
import DesignSystem

/// A round button on glass over the list screen's content, its way back and its "…" (`Phone.dc.html`, `.glass`):
/// `diameter` across, its glyph centred, casting `shadow`, in points. A platform with glass of its own puts it under
/// the button; one without draws `surface` edged with `line`, the canvas's glass and its hairline.
public struct GlassButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let diameter: Double
    public let surface: DesignSystem.Color

    /// The hairline round the button, whose width is how thick it is.
    public let line: StrokeModel

    public let shadow: DesignSystem.Shadow

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the button sends.
    public let action: Action

    public init(
        icon: IconModel,
        diameter: Double,
        surface: DesignSystem.Color,
        line: StrokeModel,
        shadow: DesignSystem.Shadow,
        accessibilityLabel: String,
        action: Action
    ) {
        self.icon = icon
        self.diameter = diameter
        self.surface = surface
        self.line = line
        self.shadow = shadow
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
