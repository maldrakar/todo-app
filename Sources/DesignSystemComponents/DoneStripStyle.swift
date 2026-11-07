// Sources/DesignSystemComponents/DoneStripStyle.swift
import DesignSystem

/// The numbers a `DoneStripModel` is drawn with, in points, and its background, which a layout holds whole and a
/// builder hands over as one value.
public struct DoneStripStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let topMargin: Double
    public let leadingMargin: Double
    public let trailingMargin: Double
    public let background: DesignSystem.Color

    /// How far the rows under the capsule stand below it while the strip is open.
    public let capsuleToRows: Double

    /// How the rows under the capsule come in as the strip opens.
    public let rowsEntrance: EntranceStyle

    public init(
        height: Double,
        cornerRadius: Double,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        topMargin: Double,
        leadingMargin: Double,
        trailingMargin: Double,
        background: DesignSystem.Color,
        capsuleToRows: Double,
        rowsEntrance: EntranceStyle
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topMargin = topMargin
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
        self.background = background
        self.capsuleToRows = capsuleToRows
        self.rowsEntrance = rowsEntrance
    }
}
