// Sources/DesignSystemComponents/FloatingButtonModel.swift
import DesignSystem

/// The round "+" that floats over the corner of the list screen on the phone (`Phone.dc.html`, the new task button):
/// `diameter` across on `fill`, its glyph centred, casting `shadow`, in points. Its numbers are the fields of its
/// `FloatingButtonStyle`.
public struct FloatingButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let style: FloatingButtonStyle
    public let fill: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the button sends.
    public let action: Action

    public init(
        icon: IconModel,
        style: FloatingButtonStyle,
        fill: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        accessibilityLabel: String,
        action: Action
    ) {
        self.icon = icon
        self.style = style
        self.fill = fill
        self.shadow = shadow
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
