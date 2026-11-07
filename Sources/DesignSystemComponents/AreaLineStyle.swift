// Sources/DesignSystemComponents/AreaLineStyle.swift

/// The numbers an `AreaLineModel` is drawn with, in points, and its line, which a builder hands over as one value.
public struct AreaLineStyle: Equatable, Sendable {
    public let height: Double
    public let leading: Double
    public let spacing: Double

    /// The line, its colour and how thick it is.
    public let line: LineStyle

    /// The gap between the end of the line and the accessories, and the end where there are none.
    public let lineToAccessories: Double

    public let cellMinimumWidth: Double
    public let endGap: Double

    public init(
        height: Double,
        leading: Double,
        spacing: Double,
        line: LineStyle,
        lineToAccessories: Double,
        cellMinimumWidth: Double,
        endGap: Double
    ) {
        self.height = height
        self.leading = leading
        self.spacing = spacing
        self.line = line
        self.lineToAccessories = lineToAccessories
        self.cellMinimumWidth = cellMinimumWidth
        self.endGap = endGap
    }
}
