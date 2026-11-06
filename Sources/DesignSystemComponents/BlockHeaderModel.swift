// Sources/DesignSystemComponents/BlockHeaderModel.swift
import DesignSystem

/// A block's header in the open list, a list's inside it or a group's, as every platform draws it (`Phone.dc.html`, the
/// group header; `Mac.dc.html`, the pane's), and a column's at the column's top: `height` high, `topMargin`,
/// `trailingMargin`, `bottomMargin` and `leadingMargin` from what stands round it; its title, or the field in its place
/// while the list is being named, and `titleToSubtitle` after the title its subtitle where it has one, `topPadding`
/// below its top, `horizontalPadding` in from either side and `bottomPadding` above its bottom; the chevron that folds
/// and opens the block where it has one (`Fold`); its rule along its bottom where it has one; and what it draws under
/// itself, the pointer's tint, rounded by `cornerRadius`, in points. Its numbers and its `rule` are the fields of its
/// `Style`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block and a column each hold one, every comparison
/// of the screen's model compares it, and inline, its field and chevron with it, it is some 770 bytes on wasm32. Its
/// `==` compares every stored property, and a test changes them one at a time.
public final class BlockHeaderModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The control that folds and opens the block: its chevron, centred in a square cell `hitSide` on a side, in
    /// points. Held whole where a header has it and absent where it has none, as `SearchFieldModel.TrailingGlyph` holds
    /// a glyph and its cell, so that a header with no chevron carries no size for one.
    public struct Fold: Equatable, Sendable {
        public let chevron: AccessoryModel<Action>.Chevron
        public let hitSide: Double

        public init(chevron: AccessoryModel<Action>.Chevron, hitSide: Double) {
            self.chevron = chevron
            self.hitSide = hitSide
        }
    }

    /// The numbers the component is drawn with, in points, and the header's rule, which the layout knows whole and a
    /// builder hands over as one value.
    public struct Style: Equatable, Sendable {
        public let titleToSubtitle: Double

        /// The rule under the header, across its width, whose width is how thick it is, and nil for a header with none,
        /// as a column's is.
        public let rule: StrokeModel?

        public let height: Double
        public let topMargin: Double
        public let trailingMargin: Double
        public let bottomMargin: Double
        public let leadingMargin: Double
        public let topPadding: Double
        public let horizontalPadding: Double
        public let bottomPadding: Double
        public let cornerRadius: Double

        public init(
            titleToSubtitle: Double,
            rule: StrokeModel?,
            height: Double,
            topMargin: Double,
            trailingMargin: Double,
            bottomMargin: Double,
            leadingMargin: Double,
            topPadding: Double,
            horizontalPadding: Double,
            bottomPadding: Double,
            cornerRadius: Double
        ) {
            self.titleToSubtitle = titleToSubtitle
            self.rule = rule
            self.height = height
            self.topMargin = topMargin
            self.trailingMargin = trailingMargin
            self.bottomMargin = bottomMargin
            self.leadingMargin = leadingMargin
            self.topPadding = topPadding
            self.horizontalPadding = horizontalPadding
            self.bottomPadding = bottomPadding
            self.cornerRadius = cornerRadius
        }
    }

    /// The title, in the colour of the list the block is: the open list's glyph colour for a group, its own for a list.
    public let title: TextModel

    /// The subtitle on the title's line after it, finished, and nil for a header with none.
    public let subtitle: TextModel?

    /// The field the title is typed into while the list is being named, in the title's place, and nil while it is not.
    public let field: TextFieldModel<Action>?

    /// The control that folds and opens the block, and nil for a header with none, as a column's is, since columns do
    /// not fold (list screen spec, section 5).
    public let fold: Fold?

    public let style: Style

    /// What a tap on the title sends.
    public let titleTapped: Action

    public init(
        title: TextModel,
        subtitle: TextModel?,
        field: TextFieldModel<Action>?,
        fold: Fold?,
        style: Style,
        titleTapped: Action
    ) {
        self.title = title
        self.subtitle = subtitle
        self.field = field
        self.fold = fold
        self.style = style
        self.titleTapped = titleTapped
    }

    public static func == (lhs: BlockHeaderModel, rhs: BlockHeaderModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.style == rhs.style
            && lhs.field == rhs.field
            && lhs.fold == rhs.fold
            && lhs.titleTapped == rhs.titleTapped
    }
}
