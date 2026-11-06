// Sources/DesignSystemComponents/PillStyle.swift
import DesignSystem

/// The numbers a `PillModel` is drawn with, in points, and its background, which a layout holds whole and a builder
/// hands over as one value.
public struct PillStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let spacing: Double
    public let background: DesignSystem.Color

    public init(
        height: Double,
        cornerRadius: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        spacing: Double,
        background: DesignSystem.Color
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.spacing = spacing
        self.background = background
    }
}
