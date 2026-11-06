// Sources/DesignSystemComponents/ColumnStyle.swift

/// The numbers a `ColumnModel` is drawn with, in points, and the hairline round its cards, which the layout knows whole
/// and a builder hands over as one value.
public struct ColumnStyle: Equatable, Sendable {
    public let width: Double
    public let cornerRadius: Double
    public let cardSpacing: Double
    public let padding: Double
    public let cardCornerRadius: Double

    /// The hairline round each card, along its rounded edge.
    public let cardRing: StrokeModel

    public init(
        width: Double,
        cornerRadius: Double,
        cardSpacing: Double,
        padding: Double,
        cardCornerRadius: Double,
        cardRing: StrokeModel
    ) {
        self.width = width
        self.cornerRadius = cornerRadius
        self.cardSpacing = cardSpacing
        self.padding = padding
        self.cardCornerRadius = cardCornerRadius
        self.cardRing = cardRing
    }
}
