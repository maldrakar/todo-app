// Sources/DesignSystemComponents/AddRowModel.swift
import DesignSystem

/// A row that adds, "+ Add task" at the end of a block or a column, "Add subtask" in a card and "+ Add list" after the
/// blocks or the columns (`Phone.dc.html`): `height` high and `width` wide, with corners of `cornerRadius`,
/// `topPadding` under its top edge and `leadingPadding` in from its leading edge its glyph, centred in a cell
/// `iconCellWidth` wide and as high as the row, as a row's check is in its tap area, so that the plus stands under the
/// checks, then `spacing` after the cell its title, `trailingPadding` short of its trailing edge; `topMargin` below
/// what stands before it and `leadingMargin` and `trailingMargin` in from the sides, in points.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block, a card, a board and the screen's model each hold
/// one, every copy and comparison of the screen's model copies and compares them, and inline it is some 440 bytes on
/// wasm32. Its `==` compares every stored property, and a test changes them one at a time.
public final class AddRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let iconCellWidth: Double
    public let spacing: Double
    public let title: TextModel
    public let height: Double

    /// How wide the row is, and nil for a row as wide as what it stands in: "+ Add list" stands as a column of its own
    /// on the board.
    public let width: Double?

    public let cornerRadius: Double
    public let topPadding: Double
    public let leadingPadding: Double
    public let trailingPadding: Double

    /// The dashed edge along the row's rounded corners, and nil for a row with none: "+ Add list" on the board has one.
    public let dash: StrokeModel?

    /// The rule along the row's top edge, across its width, and nil for a row with none: "+ Add list" under the blocks
    /// has one.
    public let rule: StrokeModel?

    public let topMargin: Double
    public let leadingMargin: Double
    public let trailingMargin: Double

    /// What a tap on the row sends.
    public let action: Action

    public init(
        icon: IconModel,
        iconCellWidth: Double,
        spacing: Double,
        title: TextModel,
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
        trailingMargin: Double,
        action: Action
    ) {
        self.icon = icon
        self.iconCellWidth = iconCellWidth
        self.spacing = spacing
        self.title = title
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
        self.action = action
    }

    public static func == (lhs: AddRowModel, rhs: AddRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.iconCellWidth == rhs.iconCellWidth
            && lhs.spacing == rhs.spacing
            && lhs.title == rhs.title
            && lhs.height == rhs.height
            && lhs.width == rhs.width
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.topPadding == rhs.topPadding
            && lhs.leadingPadding == rhs.leadingPadding
            && lhs.trailingPadding == rhs.trailingPadding
            && lhs.dash == rhs.dash
            && lhs.rule == rhs.rule
            && lhs.topMargin == rhs.topMargin
            && lhs.leadingMargin == rhs.leadingMargin
            && lhs.trailingMargin == rhs.trailingMargin
            && lhs.action == rhs.action
    }
}
