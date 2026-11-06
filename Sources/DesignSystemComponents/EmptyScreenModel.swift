// Sources/DesignSystemComponents/EmptyScreenModel.swift

/// What a screen with nothing in it shows in place of its content (`Phone.dc.html`, the list screen's empty state): a
/// tile, a title `tileToTitle` under the tile and a line that says what to do `titleToText` under the title, centred,
/// `topPadding` below what stands above it and `horizontalPadding` in from either side, the line at most `maxWidth`
/// wide, in points. Its numbers are the fields of its `EmptyScreenStyle`.
public struct EmptyScreenModel: Equatable, Sendable {
    public let tile: TileModel
    public let title: TextModel
    public let text: TextModel
    public let style: EmptyScreenStyle

    public init(
        tile: TileModel,
        title: TextModel,
        text: TextModel,
        style: EmptyScreenStyle
    ) {
        self.tile = tile
        self.title = title
        self.text = text
        self.style = style
    }
}
