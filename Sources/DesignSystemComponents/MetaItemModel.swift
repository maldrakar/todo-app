// Sources/DesignSystemComponents/MetaItemModel.swift
import DesignSystem

/// One item of a task's meta line (`Phone.dc.html`, `.meta`; `Mac.dc.html`, the row's trailing group): its glyph where
/// it has one, then, `spacing` after it, its text, finished, such as "Due Tue", "2/4" or "#home", in points, and the
/// capsule it stands on where it has one. Which items a task has and in what order is the feature module's, which lays
/// them in its row's meta.
public struct MetaItemModel: Equatable, Sendable {
    /// The capsule under an item, `height` high on `background`, the item `padding` in from either end, in points:
    /// the Mac draws a tag on one (`Mac.dc.html`, the row's tag), where the phone writes it out as "#home".
    public struct Capsule: Equatable, Sendable {
        public let background: DesignSystem.Color
        public let height: Double
        public let padding: Double

        public init(background: DesignSystem.Color, height: Double, padding: Double) {
            self.background = background
            self.height = height
            self.padding = padding
        }
    }

    /// The glyph before the text, and nil for an item that is its text alone.
    public let icon: IconModel?

    public let text: TextModel
    public let spacing: Double

    /// The capsule the item stands on, and nil for an item that stands on the row.
    public let capsule: Capsule?

    public init(icon: IconModel?, text: TextModel, spacing: Double, capsule: Capsule?) {
        self.icon = icon
        self.text = text
        self.spacing = spacing
        self.capsule = capsule
    }
}
