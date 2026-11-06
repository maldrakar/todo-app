// Sources/DesignSystemComponents/TagBarModel.swift

/// The tag bar under the open list's header (`Phone.dc.html`, the tag bar; `Mac.dc.html`, the pane's): its chips in a
/// row that scrolls sideways, `spacing` apart and `padding` in from either end of the row, fading in over `fadeIn` at
/// its leading edge and out over `fadeOut` at its trailing one, the bar standing `leadingMargin` and `trailingMargin`
/// in from the sides of the screen's content, out past them where negative, in points: so the bar can run to the
/// screen's edges while its first chip starts where the content does. Its numbers are the fields of its `Style`.
public struct TagBarModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let spacing: Double
        public let padding: Double
        public let fadeIn: Double
        public let fadeOut: Double
        public let leadingMargin: Double
        public let trailingMargin: Double

        public init(
            spacing: Double,
            padding: Double,
            fadeIn: Double,
            fadeOut: Double,
            leadingMargin: Double,
            trailingMargin: Double
        ) {
            self.spacing = spacing
            self.padding = padding
            self.fadeIn = fadeIn
            self.fadeOut = fadeOut
            self.leadingMargin = leadingMargin
            self.trailingMargin = trailingMargin
        }
    }

    /// The chips, one per tag of the list's tasks, in the order they stand.
    public let chips: [TagChipModel<Action>]

    public let style: Style

    public init(
        chips: [TagChipModel<Action>],
        style: Style
    ) {
        self.chips = chips
        self.style = style
    }
}
