// Sources/DesignSystemComponents/ColumnModel.swift
import DesignSystem

/// A block as a column of the board (`Phone.dc.html`, `.bcol`; `Mac.dc.html`, the pane's): `width` wide on `fill`,
/// with corners of `cornerRadius`, its header at its top and under it its cards, `cardSpacing` apart and `padding` in
/// from its sides and its bottom, each on `cardBackground` with corners of `cardCornerRadius`, ringed with `cardRing`,
/// in points. Where it takes a dropped card, a card dragged over it tints it `dropTint` and rings it inside with
/// `dropRing`.
///
/// It is the column's look: its cards are the feature module's rows drawn in the card look, and the row that adds to
/// it is the block's, so the model holds neither.
public struct ColumnModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let header: BlockHeaderModel<Action>
    public let width: Double
    public let cornerRadius: Double
    public let cardSpacing: Double
    public let padding: Double
    public let fill: DesignSystem.Color
    public let dropTint: DesignSystem.Color

    /// Whether the column takes a dropped card: one that does not is never tinted or ringed, whatever is dragged over
    /// it. Whether a card is being dragged over it is its view's, which has the finger or the pointer.
    public let isDropTarget: Bool

    /// The ring inside the column's edge while a card is dragged over it, whose width is how thick it is.
    public let dropRing: StrokeModel

    public let cardCornerRadius: Double
    public let cardBackground: DesignSystem.Color

    /// The hairline round each card, along its rounded edge.
    public let cardRing: StrokeModel

    public init(
        header: BlockHeaderModel<Action>,
        width: Double,
        cornerRadius: Double,
        cardSpacing: Double,
        padding: Double,
        fill: DesignSystem.Color,
        dropTint: DesignSystem.Color,
        isDropTarget: Bool,
        dropRing: StrokeModel,
        cardCornerRadius: Double,
        cardBackground: DesignSystem.Color,
        cardRing: StrokeModel
    ) {
        self.header = header
        self.width = width
        self.cornerRadius = cornerRadius
        self.cardSpacing = cardSpacing
        self.padding = padding
        self.fill = fill
        self.dropTint = dropTint
        self.isDropTarget = isDropTarget
        self.dropRing = dropRing
        self.cardCornerRadius = cardCornerRadius
        self.cardBackground = cardBackground
        self.cardRing = cardRing
    }
}
