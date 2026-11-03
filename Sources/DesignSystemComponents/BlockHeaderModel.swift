// Sources/DesignSystemComponents/BlockHeaderModel.swift
import DesignSystem

/// A block's header in the open list, a list's inside it or a group's, as every platform draws it (`Phone.dc.html`, the
/// group header; `Mac.dc.html`, the pane's), and a column's at the column's top: `height` high, `topMargin`,
/// `trailingMargin`, `bottomMargin` and `leadingMargin` from what stands round it; its title, or the field in its place
/// while the list is being named, and after it the date where it has one, `topPadding` below its top,
/// `horizontalPadding` in from either side and `bottomPadding` above its bottom; the chevron that folds and opens the
/// block, centred in a cell `chevronHit` across; its rule along its bottom; and what it draws under itself, the
/// pointer's tint, rounded by `cornerRadius`, in points.
public struct BlockHeaderModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The title, in the colour of the list the block is: the open list's glyph colour for a group, its own for a list.
    public let title: TextModel

    /// The date beside the title, finished, and nil for a block with none.
    public let date: TextModel?

    /// The field the title is typed into while the list is being named, in the title's place, and nil while it is not.
    public let field: TextFieldModel<Action>?

    public let chevron: AccessoryModel<Action>.Chevron
    public let chevronHit: Double

    /// The rule under the header, across its width, whose width is how thick it is.
    public let rule: StrokeModel

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
        date: TextModel?,
        field: TextFieldModel<Action>?,
        chevron: AccessoryModel<Action>.Chevron,
        chevronHit: Double,
        rule: StrokeModel,
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
        self.date = date
        self.field = field
        self.chevron = chevron
        self.chevronHit = chevronHit
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
}
