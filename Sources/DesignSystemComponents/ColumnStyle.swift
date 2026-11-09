// Sources/DesignSystemComponents/ColumnStyle.swift
import DesignSystem

/// The numbers a `ColumnModel` is drawn with, in points, its fill, the background, hairline and shadow of its cards and
/// its drop tint and ring, which a builder hands over as one value. The tint and the ring's colour are the block's, so
/// a column in another list's colour is another instance.
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

    /// What a card casts while the pointer is over it, and nil where there is no pointer to be: the phone's.
    public let cardHover: CardHoverStyle?

    /// How thick the ring is inside the column's edge while a card is dragged over it.
    public let dropRingWidth: Double

    /// The tint of the column while a card is dragged over it.
    public let dropTint: DesignSystem.Color

    /// The colour of the ring inside the column's edge while a card is dragged over it.
    public let dropRing: DesignSystem.Color

    /// The motion the tint and the ring come and go on.
    public let dropAnimation: DesignSystem.Animation

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
        cardHover: CardHoverStyle?,
        dropRingWidth: Double,
        dropTint: DesignSystem.Color,
        dropRing: DesignSystem.Color,
        dropAnimation: DesignSystem.Animation
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
        self.cardHover = cardHover
        self.dropRingWidth = dropRingWidth
        self.dropTint = dropTint
        self.dropRing = dropRing
        self.dropAnimation = dropAnimation
    }
}
