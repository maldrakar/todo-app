// Sources/DesignSystemComponents/AccessoryModel.swift
import DesignSystem

/// What may stand at the right of a list's row or of an area's line, each as high as what it stands on: the count; the
/// chevron, which folds and unfolds the rows inside; the grip, which says the row drags; the check, which marks a
/// choice; and a space, a cell of its width kept empty, so that a column holds on a row with nothing to put in it.
/// A component lists the accessories its row needs in the order they stand, and lays them out by its own sizes
/// (`ListRowModel`, `AreaLineModel`), so that one row serves every screen with the accessories that screen gives it
/// (the owner's 👍 on #163's thread r4431052930). A view switches over it, every case drawn and no `default`
/// (`docs/style.md`, "Views").
public enum AccessoryModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The chevron of a row with rows inside it, which folds and unfolds them: its glyph, turned by `rotation` degrees,
    /// clockwise when positive, as CSS and SwiftUI turn, moving to a new turn on `animation`, the words it reads aloud,
    /// which say what a tap on it will do, and the action the tap sends.
    public struct Chevron: Equatable, Sendable {
        public let icon: IconModel
        public let rotation: Double
        public let animation: DesignSystem.Animation
        public let accessibilityLabel: String
        public let action: Action

        public init(
            icon: IconModel, rotation: Double, animation: DesignSystem.Animation, accessibilityLabel: String,
            action: Action
        ) {
            self.icon = icon
            self.rotation = rotation
            self.animation = animation
            self.accessibilityLabel = accessibilityLabel
            self.action = action
        }
    }

    /// The count, finished.
    case count(TextModel)
    case chevron(Chevron)

    /// The grip, which says the row drags.
    case grip(IconModel)

    /// The check, which marks the row chosen. What VoiceOver reads of the choice is said apart, where a view needs it,
    /// as an option of a picker says whether it is checked.
    case check(IconModel)

    /// A cell kept empty, as wide as it says, in points.
    case space(Double)
}
