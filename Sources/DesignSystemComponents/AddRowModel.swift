// Sources/DesignSystemComponents/AddRowModel.swift
import DesignSystem

/// A row that adds, "+ Add task" at the end of a block or a column, "Add subtask" in a card and "+ Add list" after the
/// blocks or the columns (`Phone.dc.html`): `height` high and `width` wide, with corners of `cornerRadius`,
/// `topPadding` under its top edge and `leadingPadding` in from its leading edge its glyph, centred in a cell
/// `iconCellWidth` wide and as high as the row, as a row's check is in its tap area, so that the plus stands under the
/// checks, then `spacing` after the cell its title, `trailingPadding` short of its trailing edge; `topMargin` below
/// what stands before it and `leadingMargin` and `trailingMargin` in from the sides, in points. Its numbers are the
/// fields of its `Style`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block, a card, a board and the screen's model each hold
/// one, every copy and comparison of the screen's model copies and compares them, and inline it is some 440 bytes on
/// wasm32. Its `==` compares every stored property, and a test changes them one at a time.
public final class AddRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let iconCellWidth: Double
        public let spacing: Double
        public let height: Double

        /// How wide the row is, and nil for a row as wide as what it stands in: "+ Add list" stands as a column of its
        /// own on the board.
        public let width: Double?

        public let cornerRadius: Double
        public let topPadding: Double
        public let leadingPadding: Double
        public let trailingPadding: Double

        /// The dashed edge along the row's rounded corners, and nil for a row with none: "+ Add list" on the board has
        /// one.
        public let dash: StrokeModel?

        /// The rule along the row's top edge, across its width, and nil for a row with none: "+ Add list" under the
        /// blocks has one.
        public let rule: StrokeModel?

        public let topMargin: Double
        public let leadingMargin: Double
        public let trailingMargin: Double

        public init(
            iconCellWidth: Double,
            spacing: Double,
            height: Double,
            width: Double?,
            cornerRadius: Double,
            topPadding: Double,
            leadingPadding: Double,
            trailingPadding: Double,
            dash: StrokeModel?,
            rule: StrokeModel?,
            topMargin: Double,
            leadingMargin: Double,
            trailingMargin: Double
        ) {
            self.iconCellWidth = iconCellWidth
            self.spacing = spacing
            self.height = height
            self.width = width
            self.cornerRadius = cornerRadius
            self.topPadding = topPadding
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
            self.dash = dash
            self.rule = rule
            self.topMargin = topMargin
            self.leadingMargin = leadingMargin
            self.trailingMargin = trailingMargin
        }
    }

    public let icon: IconModel
    public let title: TextModel
    public let style: Style

    /// What a tap on the row sends.
    public let action: Action

    public init(
        icon: IconModel,
        title: TextModel,
        style: Style,
        action: Action
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.action = action
    }

    public static func == (lhs: AddRowModel, rhs: AddRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.style == rhs.style
            && lhs.title == rhs.title
            && lhs.action == rhs.action
    }
}
