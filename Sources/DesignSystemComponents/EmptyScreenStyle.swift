// Sources/DesignSystemComponents/EmptyScreenStyle.swift

/// The numbers an `EmptyScreenModel` is drawn with, in points, which a layout holds whole and a builder hands over as
/// one value.
public struct EmptyScreenStyle: Equatable, Sendable {
    public let tileToTitle: Double
    public let titleToText: Double
    public let topPadding: Double
    public let horizontalPadding: Double
    public let maxWidth: Double

    public init(
        tileToTitle: Double,
        titleToText: Double,
        topPadding: Double,
        horizontalPadding: Double,
        maxWidth: Double
    ) {
        self.tileToTitle = tileToTitle
        self.titleToText = titleToText
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.maxWidth = maxWidth
    }
}
