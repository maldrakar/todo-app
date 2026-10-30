// Sources/DesignSystemComponents/ButtonModel.swift
import DesignSystem

/// A button as every platform draws it: its glyph, its word after the glyph where it has one, the words it reads aloud,
/// what it stands on and what a press does. A view switches over `Press` and `Fill`, every case drawn and no `default`
/// (`docs/style.md`, "Views").
public struct ButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// What a press does: send an action, or put a menu up.
    public enum Press: Equatable, Sendable {
        case action(Action)
        case menu(MenuModel<Action>)
    }

    /// What the button stands on: the container its platform puts it on, which is the platform's choice, the glass
    /// under a bar's controls on iOS or a toolbar, with no fill of its own; or a fill of its own in a colour of the
    /// look, on which its glyph stands.
    public enum Fill: Equatable, Sendable {
        case container
        case color(DesignSystem.Color)
    }

    public let icon: IconModel

    /// The word after the glyph, and nil for a button that is its glyph alone.
    public let title: TextModel?

    public let accessibilityLabel: String
    public let fill: Fill
    public let press: Press

    public init(icon: IconModel, title: TextModel?, accessibilityLabel: String, fill: Fill, press: Press) {
        self.icon = icon
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.fill = fill
        self.press = press
    }
}
