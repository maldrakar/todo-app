// Sources/DesignSystemComponents/BlockHeaderModel.swift
import DesignSystem

/// A block's header in the open list, a list's inside it or a group's, as every platform draws it (`Phone.dc.html`, the
/// group header; `Mac.dc.html`, the pane's), and a column's at the column's top: `height` high, `topMargin`,
/// `trailingMargin`, `bottomMargin` and `leadingMargin` from what stands round it; its title, or the field in its place
/// while the list is being named, and `titleToSubtitle` after the title its subtitle where it has one, `topPadding`
/// below its top, `horizontalPadding` in from either side and `bottomPadding` above its bottom; the chevron that folds
/// and opens the block, centred in a square cell `chevronHitSide` on a side; its rule along its bottom where it has
/// one; and what it draws under itself, the pointer's tint, rounded by `cornerRadius`, in points.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block and a column each hold one, every comparison
/// of the screen's model compares it, and inline, its field and chevron with it, it is some 770 bytes on wasm32. Its
/// `==` compares every stored property, and a test changes them one at a time.
public final class BlockHeaderModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The title, in the colour of the list the block is: the open list's glyph colour for a group, its own for a list.
    public let title: TextModel

    /// The subtitle on the title's line after it, finished, and nil for a header with none.
    public let subtitle: TextModel?

    public let titleToSubtitle: Double

    /// The field the title is typed into while the list is being named, in the title's place, and nil while it is not.
    public let field: TextFieldModel<Action>?

    public let chevron: AccessoryModel<Action>.Chevron
    public let chevronHitSide: Double

    /// The rule under the header, across its width, whose width is how thick it is, and nil for a header with none, as
    /// a column's is.
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

    /// What a tap on the title sends.
    public let titleTapped: Action

    public init(
        title: TextModel,
        subtitle: TextModel?,
        titleToSubtitle: Double,
        field: TextFieldModel<Action>?,
        chevron: AccessoryModel<Action>.Chevron,
        chevronHitSide: Double,
        rule: StrokeModel?,
        height: Double,
        topMargin: Double,
        trailingMargin: Double,
        bottomMargin: Double,
        leadingMargin: Double,
        topPadding: Double,
        horizontalPadding: Double,
        bottomPadding: Double,
        cornerRadius: Double,
        titleTapped: Action
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleToSubtitle = titleToSubtitle
        self.field = field
        self.chevron = chevron
        self.chevronHitSide = chevronHitSide
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
        self.titleTapped = titleTapped
    }

    public static func == (lhs: BlockHeaderModel, rhs: BlockHeaderModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.titleToSubtitle == rhs.titleToSubtitle
            && lhs.field == rhs.field
            && lhs.chevron == rhs.chevron
            && lhs.chevronHitSide == rhs.chevronHitSide
            && lhs.rule == rhs.rule
            && lhs.height == rhs.height
            && lhs.topMargin == rhs.topMargin
            && lhs.trailingMargin == rhs.trailingMargin
            && lhs.bottomMargin == rhs.bottomMargin
            && lhs.leadingMargin == rhs.leadingMargin
            && lhs.topPadding == rhs.topPadding
            && lhs.horizontalPadding == rhs.horizontalPadding
            && lhs.bottomPadding == rhs.bottomPadding
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.titleTapped == rhs.titleTapped
    }
}
