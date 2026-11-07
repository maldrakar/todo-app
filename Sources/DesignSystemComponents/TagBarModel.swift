// Sources/DesignSystemComponents/TagBarModel.swift

/// The tag bar under the open list's header (`Phone.dc.html`, the tag bar; `Mac.dc.html`, the pane's): its chips in a
/// row that scrolls sideways, `spacing` apart and `padding` in from either end of the row, with `endRoom` more after
/// the last, fading in over `fadeIn` at its leading edge and out over `fadeOut` at its trailing one, the bar standing
/// `leadingMargin` and `trailingMargin` in from the sides of the screen's content, out past them where negative, in
/// points: so the bar can run to the screen's edges while its first chip starts where the content does. Its numbers are
/// the fields of its `TagBarStyle`.
public struct TagBarModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The chips, one per tag of the list's tasks, in the order they stand.
    public let chips: [TagChipModel<Action>]

    public let style: TagBarStyle

    public init(
        chips: [TagChipModel<Action>],
        style: TagBarStyle
    ) {
        self.chips = chips
        self.style = style
    }
}
