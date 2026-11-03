// Sources/DesignSystemComponents/EmptyStateModel.swift

/// What a list with nothing in it shows in place of its blocks (`Phone.dc.html`, the empty state): its tile, its title
/// `tileToTitle` under the tile and a line that says what to do `titleToText` under the title, centred, `topPadding`
/// below what stands above it and `horizontalPadding` in from either side, the line at most `maxWidth` wide, in
/// points.
public struct EmptyStateModel: Equatable, Sendable {
    public let tile: TileModel
    public let title: TextModel
    public let text: TextModel
    public let tileToTitle: Double
    public let titleToText: Double
    public let topPadding: Double
    public let horizontalPadding: Double
    public let maxWidth: Double

    public init(
        tile: TileModel, title: TextModel, text: TextModel, tileToTitle: Double, titleToText: Double,
        topPadding: Double, horizontalPadding: Double, maxWidth: Double
    ) {
        self.tile = tile
        self.title = title
        self.text = text
        self.tileToTitle = tileToTitle
        self.titleToText = titleToText
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.maxWidth = maxWidth
    }
}
