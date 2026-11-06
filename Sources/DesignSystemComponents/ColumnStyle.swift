// Sources/DesignSystemComponents/ColumnStyle.swift
import DesignSystem

/// The numbers a `ColumnModel` is drawn with, in points, its fill, the background, hairline and shadow of its cards and
/// the thickness of its drop ring, which the layout knows whole and a builder hands over as one value.
public struct ColumnStyle: Equatable, Sendable {
    public let width: Double
    public let cornerRadius: Double
    public let cardSpacing: Double
    public let padding: Double
    public let cardCornerRadius: Double

    /// The hairline round each card, along its rounded edge.
    public let cardRing: LineStyle
    public let fill: DesignSystem.Color
    public let cardBackground: DesignSystem.Color
    public let cardShadow: DesignSystem.Shadow

    /// How thick the ring is inside the column's edge while a card is dragged over it.
    public let dropRingWidth: Double

    public init(
        width: Double,
        cornerRadius: Double,
        cardSpacing: Double,
        padding: Double,
        cardCornerRadius: Double,
        cardRing: LineStyle,
        fill: DesignSystem.Color,
        cardBackground: DesignSystem.Color,
        cardShadow: DesignSystem.Shadow,
        dropRingWidth: Double
    ) {
        self.width = width
        self.cornerRadius = cornerRadius
        self.cardSpacing = cardSpacing
        self.padding = padding
        self.cardCornerRadius = cardCornerRadius
        self.cardRing = cardRing
        self.fill = fill
        self.cardBackground = cardBackground
        self.cardShadow = cardShadow
        self.dropRingWidth = dropRingWidth
    }
}
