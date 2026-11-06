// Sources/DesignSystemComponents/AddRowStyle.swift

/// The numbers an `AddRowModel` is drawn with, in points, and the row's dashed edge and rule, which the layout knows
/// whole and a builder hands over as one value.
public struct AddRowStyle: Equatable, Sendable {
    public let iconCellWidth: Double
    public let spacing: Double
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
