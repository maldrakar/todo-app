// Sources/DesignSystemComponents/TagBarModel.swift

/// The tag bar under the open list's header (`Phone.dc.html`, the tag bar; `Mac.dc.html`, the pane's): its chips in a
/// row that scrolls sideways, `spacing` apart and `padding` in from either end of the row, fading in over `fadeIn` at
/// its leading edge and out over `fadeOut` at its trailing one, the bar standing `leadingMargin` and `trailingMargin`
/// in from the sides of the screen's content, out past them where negative, in points: so the bar can run to the
/// screen's edges while its first chip starts where the content does.
public struct TagBarModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The chips, one per tag of the list's tasks, in the order they stand.
    public let chips: [TagChipModel<Action>]

    public let spacing: Double
    public let padding: Double
    public let fadeIn: Double
    public let fadeOut: Double
    public let leadingMargin: Double
    public let trailingMargin: Double

    public init(
        chips: [TagChipModel<Action>],
        spacing: Double,
        padding: Double,
        fadeIn: Double,
        fadeOut: Double,
        leadingMargin: Double,
        trailingMargin: Double
    ) {
        self.chips = chips
        self.spacing = spacing
        self.padding = padding
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
    }
}
