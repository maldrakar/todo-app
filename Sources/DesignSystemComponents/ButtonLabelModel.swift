// Sources/DesignSystemComponents/ButtonLabelModel.swift
import DesignSystem

/// The look of a button, which a button and a menu button share: its glyph, its word after the glyph where it has one,
/// the words it reads aloud, and what it stands on. A view switches over `Fill`, every case drawn and no `default`
/// (`docs/style.md`, "Views").
public struct ButtonLabelModel: Equatable, Sendable {
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

    public init(icon: IconModel, title: TextModel?, accessibilityLabel: String, fill: Fill) {
        self.icon = icon
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.fill = fill
    }
}
