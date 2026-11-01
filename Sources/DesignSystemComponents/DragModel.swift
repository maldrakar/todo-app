// Sources/DesignSystemComponents/DragModel.swift
import DesignSystem

/// How the drag in a tree looks while a row is lifted: what marks the place where the row would land and the card it is
/// carried on, one of two looks (`Look`), both placed by the tree's `indent`, and the motion of the lift, the release
/// and a move of the mark. The drag itself, which row lifts, where the mark stands and at which depth, is the
/// platform's, since only the platform has the finger or the pointer (the owner, 2026-10-30); this is its look.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a screen's model holds it, every comparison of the
/// screen's model compares it, and it is some 540 bytes on wasm32. Its `==` compares every stored property, and a test
/// changes them one at a time.
public final class DragModel: Equatable, Sendable {
    /// What marks the place where the lifted row would land and the card it is carried on: the slot that opens there,
    /// with the card under the finger (`Phone.dc.html`, the drag's slot and card), or the Finder's indicator, a line
    /// and a circle, with its own card beside them (`Mac.dc.html`, the drag's slot row and card). A view switches over
    /// it, every case drawn and no `default` (`docs/style.md`, "Views").
    public enum Look: Equatable, Sendable {
        case slot(Slot, Card)
        case indicator(Indicator)
    }

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

    /// The Finder's mark of the place where the lifted row would land, between the rows or into a parent alike: it
    /// opens a gap `height` high between the rows, in which, centred in its height, run a line of `line`, from
    /// `lineOffset` from the leading edge of the tile of the drop's depth to `trailingGap` short of the right edge of
    /// the tree on screen, its ends rounded by `lineCornerRadius`, and a circle `circleDiameter` across, its leading
    /// edge `circleOffset` from that tile's leading edge, ringed with `circleRing` and filled with `circleFill`; and
    /// beside them its card. An offset is after the tile's leading edge where it is positive and before it where it is
    /// negative, all in points.
    public struct Indicator: Equatable, Sendable {
        /// The lifted row on a card of its own at the mark (`Mac.dc.html`, `.drag-ghost`): `width` by `height`, its
        /// leading edge `offset` from the leading edge of the tile of the drop's depth, centred on the line, its
        /// corners of `cornerRadius`, on `background`, casting `shadow`, turned by `rotation` degrees, clockwise when
        /// positive, at `opacity`, from 0 to 1, in points. A list's card holds the lifted row's tile in its colour
        /// with its icon at the sizes here, `padding` in, and `tileToTitle` after it the row's title in `titleFont`; a
        /// line's card holds the lifted line as the line draws itself.
        public struct Card: Equatable, Sendable {
            public let width: Double
            public let height: Double
            public let offset: Double
            public let cornerRadius: Double
            public let background: DesignSystem.Color
            public let shadow: DesignSystem.Shadow
            public let rotation: Double
            public let opacity: Double
            public let padding: Double
            public let tileToTitle: Double
            public let tileSide: Double
            public let tileCornerRadius: Double
            public let glyphSize: Double
            public let titleFont: DesignSystem.Font

            public init(
                width: Double,
                height: Double,
                offset: Double,
                cornerRadius: Double,
                background: DesignSystem.Color,
                shadow: DesignSystem.Shadow,
                rotation: Double,
                opacity: Double,
                padding: Double,
                tileToTitle: Double,
                tileSide: Double,
                tileCornerRadius: Double,
                glyphSize: Double,
                titleFont: DesignSystem.Font
            ) {
                self.width = width
                self.height = height
                self.offset = offset
                self.cornerRadius = cornerRadius
                self.background = background
                self.shadow = shadow
                self.rotation = rotation
                self.opacity = opacity
                self.padding = padding
                self.tileToTitle = tileToTitle
                self.tileSide = tileSide
                self.tileCornerRadius = tileCornerRadius
                self.glyphSize = glyphSize
                self.titleFont = titleFont
            }
        }

        public let height: Double
        public let line: StrokeModel
        public let lineOffset: Double
        public let lineCornerRadius: Double
        public let trailingGap: Double
        public let circleDiameter: Double
        public let circleOffset: Double
        public let circleRing: StrokeModel
        public let circleFill: DesignSystem.Color
        public let card: Card

        public init(
            height: Double,
            line: StrokeModel,
            lineOffset: Double,
            lineCornerRadius: Double,
            trailingGap: Double,
            circleDiameter: Double,
            circleOffset: Double,
            circleRing: StrokeModel,
            circleFill: DesignSystem.Color,
            card: Card
        ) {
            self.height = height
            self.line = line
            self.lineOffset = lineOffset
            self.lineCornerRadius = lineCornerRadius
            self.trailingGap = trailingGap
            self.circleDiameter = circleDiameter
            self.circleOffset = circleOffset
            self.circleRing = circleRing
            self.circleFill = circleFill
            self.card = card
        }
    }

    /// The tree's indent, which places the mark and the card at a depth, and is how far a finger or the pointer carries
    /// a lifted row sideways to change its depth by one.
    public let indent: IndentModel

    public let animation: DesignSystem.Animation
    public let look: Look

    public init(indent: IndentModel, animation: DesignSystem.Animation, look: Look) {
        self.indent = indent
        self.animation = animation
        self.look = look
    }

    public static func == (lhs: DragModel, rhs: DragModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.indent == rhs.indent
            && lhs.animation == rhs.animation
            && lhs.look == rhs.look
    }
}
