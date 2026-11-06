// Sources/DesignSystemComponents/BlockHeaderStyle.swift

/// The numbers a `BlockHeaderModel` is drawn with, in points, and the header's rule, which the layout knows whole and a
/// builder hands over as one value.
public struct BlockHeaderStyle: Equatable, Sendable {
    public let titleToSubtitle: Double

    /// The rule under the header, across its width, whose width is how thick it is, and nil for a header with none, as
    /// a column's is.
    public let rule: LineStyle?

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
        rule: LineStyle?,
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
