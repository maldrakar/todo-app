// Sources/DesignSystemComponents/FloatingButtonModel.swift
import DesignSystem

/// The round "+" that floats over the corner of the list screen on the phone (`Phone.dc.html`, the new task button):
/// `diameter` across on `fill`, its glyph centred, casting `shadow`, in points. Its numbers are the fields of its
/// `Style`.
public struct FloatingButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let diameter: Double

        public init(diameter: Double) {
            self.diameter = diameter
        }
    }

    public let icon: IconModel
    public let style: Style
    public let fill: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the button sends.
    public let action: Action

    public init(
        icon: IconModel,
        style: Style,
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
