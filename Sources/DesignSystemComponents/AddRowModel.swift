// Sources/DesignSystemComponents/AddRowModel.swift
import DesignSystem

/// A row that adds, "+ Add task" at the end of a block or a column, "Add subtask" in a card and "+ Add list" after the
/// blocks or the columns (`Phone.dc.html`): `height` high and `width` wide, with corners of `cornerRadius`,
/// `leadingPadding` in from its leading edge its glyph, centred in a cell `iconCell` wide, as a row's check is in its
/// tap area, so that the plus stands under the checks, then its title, `trailingPadding` short of its trailing edge;
/// `topMargin` below what stands before it and `leadingMargin` and `trailingMargin` in from the sides, in points.
public struct AddRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let iconCell: Double
    public let title: TextModel
    public let height: Double

    /// How wide the row is, and nil for a row as wide as what it stands in: "+ Add list" stands as a column of its own
    /// on the board.
    public let width: Double?

    public let cornerRadius: Double
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
        iconCell: Double,
        title: TextModel,
        height: Double,
        width: Double?,
        cornerRadius: Double,
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
        self.iconCell = iconCell
        self.title = title
        self.height = height
        self.width = width
        self.cornerRadius = cornerRadius
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.dash = dash
        self.rule = rule
        self.topMargin = topMargin
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
        self.action = action
    }
}
