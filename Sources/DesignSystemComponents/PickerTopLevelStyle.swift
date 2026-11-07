// Sources/DesignSystemComponents/PickerTopLevelStyle.swift
import DesignSystem

/// The numbers a picker's top level is drawn with, in points, and the colour of its tile, which a builder hands over as
/// one value.
public struct PickerTopLevelStyle: Equatable, Sendable {
    public let tileSide: Double
    public let tileCornerRadius: Double
    public let tileColor: DesignSystem.Color
    public let tileToTitle: Double
    public let leading: Double
    public let height: Double
    public let cellMinimumWidth: Double
    public let endGap: Double

    public init(
        tileSide: Double,
        tileCornerRadius: Double,
        tileColor: DesignSystem.Color,
        tileToTitle: Double,
        leading: Double,
        height: Double,
        cellMinimumWidth: Double,
        endGap: Double
    ) {
        self.tileSide = tileSide
        self.tileCornerRadius = tileCornerRadius
        self.tileColor = tileColor
        self.tileToTitle = tileToTitle
        self.leading = leading
        self.height = height
        self.cellMinimumWidth = cellMinimumWidth
        self.endGap = endGap
    }
}
