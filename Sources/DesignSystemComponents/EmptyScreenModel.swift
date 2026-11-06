// Sources/DesignSystemComponents/EmptyScreenModel.swift

/// What a screen with nothing in it shows in place of its content (`Phone.dc.html`, the list screen's empty state): a
/// tile, a title `tileToTitle` under the tile and a line that says what to do `titleToText` under the title, centred,
/// `topPadding` below what stands above it and `horizontalPadding` in from either side, the line at most `maxWidth`
/// wide, in points. Its numbers are the fields of its `Style`.
public struct EmptyScreenModel: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
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

    public let tile: TileModel
    public let title: TextModel
    public let text: TextModel
    public let style: Style

    public init(
        tile: TileModel,
        title: TextModel,
        text: TextModel,
        style: Style
    ) {
        self.tile = tile
        self.title = title
        self.text = text
        self.style = style
    }
}
