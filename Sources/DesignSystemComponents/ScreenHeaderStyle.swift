// Sources/DesignSystemComponents/ScreenHeaderStyle.swift

/// The numbers a `ScreenHeaderModel` is drawn with, in points, which a layout holds whole and a builder hands over as
/// one value.
public struct ScreenHeaderStyle: Equatable, Sendable {
    public let spacing: Double
    public let titleToSubtitle: Double
    public let subtitleLeading: Double

    public init(
        spacing: Double,
        titleToSubtitle: Double,
        subtitleLeading: Double
    ) {
        self.spacing = spacing
        self.titleToSubtitle = titleToSubtitle
        self.subtitleLeading = subtitleLeading
    }
}
