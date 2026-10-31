// Sources/DesignSystemComponents/DragModel.swift
import DesignSystem

/// How the drag in a tree looks while a row is lifted (`Phone.dc.html`, the drag's slot and card): the slot where the
/// row would land and the card carried under the finger, both placed by the tree's `indent`, and the motion of the
/// lift, the release and a move of the slot. The drag itself, which row lifts, where the slot stands and at which
/// depth, is the platform's, since only the platform has the finger (the owner, 2026-10-30); this is its look.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a screen's model holds it, every comparison of the
/// screen's model compares it, and it is some 540 bytes on wasm32. Its `==` compares every stored property, and a test
/// changes them one at a time.
public final class DragModel: Equatable, Sendable {
    /// The slot where the lifted row would land: `height` high, its frame drawn `verticalInset` in from its top and
    /// from its bottom, from `inset` before the tile of the slot's depth to `trailingGap` short of the right edge of
    /// the tree on screen, its corners of `cornerRadius`, filled with `fill` and edged with `stroke`, in points. Behind
    /// it run the guides of the levels it would stand under, which are the row before it's `childGuides`, as many as
    /// its depth.
    public struct Slot: Equatable, Sendable {
        public let height: Double
        public let inset: Double
        public let trailingGap: Double
        public let verticalInset: Double
        public let cornerRadius: Double
        public let fill: DesignSystem.Color
        public let stroke: StrokeModel

        public init(
            height: Double, inset: Double, trailingGap: Double, verticalInset: Double, cornerRadius: Double,
            fill: DesignSystem.Color, stroke: StrokeModel
        ) {
            self.height = height
            self.inset = inset
            self.trailingGap = trailingGap
            self.verticalInset = verticalInset
            self.cornerRadius = cornerRadius
            self.fill = fill
            self.stroke = stroke
        }
    }

    /// The lifted row under the finger: standing `raise` above the row it lifts, grown to `scale` once lifted and
    /// turned by `rotation` degrees, clockwise when positive, casting `shadow`, on `background`, in points.
    ///
    /// A list's card is `listHeight` high, from `listInset` before the tile of the slot's depth to `listTrailingGap`
    /// short of the right edge of the tree on screen and at least `minimumWidth` wide; on it, `listPadding` in, stand
    /// the lifted row's tile and title, its gap between them, and `grip` in a cell `gripCell` wide at its end; its
    /// corners are of `listCornerRadius`. A line's card is `lineHeight` high, from `lineInset` to `lineTrailingGap`
    /// short of the right edge of the tree on screen and at least `minimumWidth` wide, with the lifted line on it as
    /// the line draws itself; its corners are of `lineCornerRadius`.
    public struct Card: Equatable, Sendable {
        public let raise: Double
        public let scale: Double
        public let rotation: Double
        public let shadow: DesignSystem.Shadow
        public let background: DesignSystem.Color
        public let grip: IconModel
        public let gripCell: Double
        public let minimumWidth: Double
        public let listHeight: Double
        public let listInset: Double
        public let listPadding: Double
        public let listTrailingGap: Double
        public let listCornerRadius: Double
        public let lineHeight: Double
        public let lineInset: Double
        public let lineTrailingGap: Double
        public let lineCornerRadius: Double

        public init(
            raise: Double,
            scale: Double,
            rotation: Double,
            shadow: DesignSystem.Shadow,
            background: DesignSystem.Color,
            grip: IconModel,
            gripCell: Double,
            minimumWidth: Double,
            listHeight: Double,
            listInset: Double,
            listPadding: Double,
            listTrailingGap: Double,
            listCornerRadius: Double,
            lineHeight: Double,
            lineInset: Double,
            lineTrailingGap: Double,
            lineCornerRadius: Double
        ) {
            self.raise = raise
            self.scale = scale
            self.rotation = rotation
            self.shadow = shadow
            self.background = background
            self.grip = grip
            self.gripCell = gripCell
            self.minimumWidth = minimumWidth
            self.listHeight = listHeight
            self.listInset = listInset
            self.listPadding = listPadding
            self.listTrailingGap = listTrailingGap
            self.listCornerRadius = listCornerRadius
            self.lineHeight = lineHeight
            self.lineInset = lineInset
            self.lineTrailingGap = lineTrailingGap
            self.lineCornerRadius = lineCornerRadius
        }
    }

    /// The tree's indent, which places the slot and the card at a depth, and is how far a finger carries a lifted row
    /// sideways to change its depth by one.
    public let indent: IndentModel

    public let animation: DesignSystem.Animation
    public let slot: Slot
    public let card: Card

    public init(indent: IndentModel, animation: DesignSystem.Animation, slot: Slot, card: Card) {
        self.indent = indent
        self.animation = animation
        self.slot = slot
        self.card = card
    }

    public static func == (lhs: DragModel, rhs: DragModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.indent == rhs.indent
            && lhs.animation == rhs.animation
            && lhs.slot == rhs.slot
            && lhs.card == rhs.card
    }
}
