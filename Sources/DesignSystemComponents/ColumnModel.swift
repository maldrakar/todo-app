// Sources/DesignSystemComponents/ColumnModel.swift
import DesignSystem

/// A block as a column of the board (`Phone.dc.html`, `.bcol`; `Mac.dc.html`, the pane's): `width` wide on `fill`, with
/// corners of `cornerRadius`, its header at its top and under it its cards, `cardSpacing` apart and `padding` in from
/// its sides and its bottom, each on `cardBackground` with corners of `cardCornerRadius`, ringed with `cardRing` and
/// casting `cardShadow`, in points. Where it takes a dropped card, a card dragged over it tints it `dropTint` and rings
/// it inside in `dropRing`, `dropRingWidth` thick, on `dropAnimation`. Its numbers, its `fill`, its `dropTint`, its
/// `dropRing`, its `dropAnimation`, its `cardBackground`, its `cardRing` and its `cardShadow` are the fields of its
/// `ColumnStyle`.
///
/// It is the column's look: its cards are the feature module's rows drawn in the card look, and the row that adds to it
/// is the block's, so the model holds neither.
public struct ColumnModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let header: BlockHeaderModel<Action>
    public let style: ColumnStyle

    /// Whether the column takes a dropped card: one that does not is never tinted or ringed, whatever is dragged over
    /// it. Whether a card is being dragged over it is its view's, which has the finger or the pointer.
    public let isDropTarget: Bool

    public init(
        header: BlockHeaderModel<Action>,
        style: ColumnStyle,
        isDropTarget: Bool
    ) {
        self.header = header
        self.style = style
        self.isDropTarget = isDropTarget
    }
}
