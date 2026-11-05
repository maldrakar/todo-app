// Sources/DesignSystemComponents/MetaItemModel.swift
import DesignSystem

/// One item of a task's meta line (`Phone.dc.html`, `.meta`; `Mac.dc.html`, the row's trailing group): its glyph where
/// it has one, then, `spacing` after it, its text where it has one, finished, such as "Due Tue", "2/4" or "#home", in
/// points, and the capsule it stands on where it has one: an item is its text alone, its glyph alone, as the notes'
/// is, or both, and the gap stands only between the two. Which items a task has and in what order is the feature module's, which lays
/// them in its row's meta.
public struct MetaItemModel: Equatable, Sendable {
    /// The capsule under an item, `height` high on `background`, with corners of `cornerRadius`, half its height for a
    /// capsule, the item `leadingPadding` in from its leading edge and `trailingPadding` short of its trailing one, in
    /// points, as a pill is: the Mac draws a tag on one (`Mac.dc.html`, the row's tag), where the phone writes it out
    /// as "#home".
    public struct Capsule: Equatable, Sendable {
        public let background: DesignSystem.Color
        public let height: Double
        public let cornerRadius: Double
        public let leadingPadding: Double
        public let trailingPadding: Double

        public init(
            background: DesignSystem.Color, height: Double, cornerRadius: Double, leadingPadding: Double,
            trailingPadding: Double
        ) {
            self.background = background
            self.height = height
            self.cornerRadius = cornerRadius
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
        }
    }

    /// The glyph before the text, and nil for an item that is its text alone.
    public let icon: IconModel?

    /// The text, and nil for an item that is its glyph alone.
    public let text: TextModel?
    public let spacing: Double

    /// The capsule the item stands on, and nil for an item that stands on the row.
    public let capsule: Capsule?

    public init(icon: IconModel?, text: TextModel?, spacing: Double, capsule: Capsule?) {
        self.icon = icon
        self.text = text
        self.spacing = spacing
        self.capsule = capsule
    }
}
