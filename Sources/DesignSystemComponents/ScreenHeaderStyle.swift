// Sources/DesignSystemComponents/ScreenHeaderStyle.swift

/// The numbers a `ScreenHeaderModel` is drawn with, in points, which a layout holds whole and a builder hands over as
/// one value.
public struct ScreenHeaderStyle: Equatable, Sendable {
    /// How far the header stands in from either side of the screen.
    public let horizontalPadding: Double

    /// How far what follows the header and its tag bar, the first block or the board, stands below them.
    public let bottomMargin: Double
    public let spacing: Double
    public let titleToSubtitle: Double
    public let subtitleLeading: Double

    public init(
        horizontalPadding: Double,
        bottomMargin: Double,
        spacing: Double,
        titleToSubtitle: Double,
        subtitleLeading: Double
    ) {
        self.horizontalPadding = horizontalPadding
        self.bottomMargin = bottomMargin
        self.spacing = spacing
        self.titleToSubtitle = titleToSubtitle
        self.subtitleLeading = subtitleLeading
    }
}
