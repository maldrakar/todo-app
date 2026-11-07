// Sources/DesignSystemComponents/AccessoryModel.swift

/// What may stand at the right of a list's row or of an area's line, each as high as what it stands on: a text, such
/// as a count; the chevron, which folds and unfolds the rows inside; the grip, which says the row drags; the check,
/// which marks a choice; a space, a cell of its width kept empty, so that a column holds on a row with nothing to put
/// in it; and an accessory hidden, whose room is kept and drawn empty, as the room for a check on a choice not marked.
/// A component lists the accessories its row needs in the order they stand, and lays them out by its own sizes
/// (`ListRowModel`, `AreaLineModel`), so that one row serves every screen with the accessories that screen gives it
/// (the owner, on #163's threads r4431052930 and r4431875752). A glyph's own width is its platform's, so a component
/// gives its glyphs a cell they are at least as wide as, never a width a glyph has on one platform. A view switches
/// over it, every case drawn and no `default` (`docs/style.md`, "Views").
public enum AccessoryModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The chevron of a row with rows inside it, which folds and unfolds them: its glyph, turned by `rotation` degrees,
    /// clockwise when positive, as CSS and SwiftUI turn, moving to a new turn on `animation`, the words it reads aloud,
    /// which say what a tap on it will do, and the action the tap sends. Its turn and its motion are the fields of its
    /// `ChevronStyle`.
    public struct Chevron: Equatable, Sendable {
        public let icon: IconModel
        public let accessibilityLabel: String
        public let action: Action
        public let style: ChevronStyle

        public init(icon: IconModel, accessibilityLabel: String, action: Action, style: ChevronStyle) {
            self.icon = icon
            self.accessibilityLabel = accessibilityLabel
            self.action = action
            self.style = style
        }
    }

    /// A text, finished, such as a screen's count: the row draws it and knows nothing of what it says.
    case text(TextModel)
    case chevron(Chevron)

    /// The grip, which says the row drags.
    case grip(IconModel)

    /// The check, which marks the row chosen. What VoiceOver reads of the choice is said apart, where a view needs it,
    /// as an option of a picker says whether it is checked.
    case check(IconModel)

    /// A cell kept empty, as wide as it says, in points.
    case space(Double)

    /// An accessory's room, kept as its platform draws it and left empty, so that a column holds by the accessory's
    /// own width, which only the platform knows: the check's room on a choice not marked. It takes no touch.
    indirect case hidden(AccessoryModel)
}
