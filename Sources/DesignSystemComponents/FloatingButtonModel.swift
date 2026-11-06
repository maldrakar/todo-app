// Sources/DesignSystemComponents/FloatingButtonModel.swift
import DesignSystem

/// The round "+" that floats over the corner of the list screen on the phone (`Phone.dc.html`, the new task button):
/// `diameter` across on `fill`, its glyph centred, casting `shadow`, in points. Its numbers, its `fill` and its
/// `shadow` are the fields of its `FloatingButtonStyle`.
public struct FloatingButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let style: FloatingButtonStyle

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the button sends.
    public let action: Action

    public init(
        icon: IconModel,
        style: FloatingButtonStyle,
        accessibilityLabel: String,
        action: Action
    ) {
        self.icon = icon
        self.style = style
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
