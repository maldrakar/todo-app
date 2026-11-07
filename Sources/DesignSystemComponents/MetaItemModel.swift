// Sources/DesignSystemComponents/MetaItemModel.swift

/// One item of a task's meta line (`Phone.dc.html`, `.meta`; `Mac.dc.html`, the row's trailing group): its glyph where
/// it has one, then, `spacing` after it, its text where it has one, finished, such as "Due Tue", "2/4" or "#home", in
/// points, and the capsule it stands on where it has one: an item is its text alone, its glyph alone, as the notes'
/// is, or both, and the gap stands only between the two. Which items a task has and in what order is the feature
/// module's, which lays them in its row's meta. Its `spacing` and its `capsule` are the fields of its `MetaItemStyle`.
public struct MetaItemModel: Equatable, Sendable {
    /// The glyph before the text, and nil for an item that is its text alone.
    public let icon: IconModel?

    /// The text, and nil for an item that is its glyph alone.
    public let text: TextModel?
    public let style: MetaItemStyle

    public init(icon: IconModel?, text: TextModel?, style: MetaItemStyle) {
        self.icon = icon
        self.text = text
        self.style = style
    }
}
