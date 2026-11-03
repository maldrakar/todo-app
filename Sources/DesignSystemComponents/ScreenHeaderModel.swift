// Sources/DesignSystemComponents/ScreenHeaderModel.swift

/// A screen's header, the open list's tile and title (`Phone.dc.html`, the list screen's header; `Mac.dc.html`, the
/// pane's): its tile, `spacing` before its title, and under them the subtitle where it has one, `titleToSubtitle`
/// below the title and `subtitleLeading` in from the header's leading edge, under the title's start, in points.
public struct ScreenHeaderModel: Equatable, Sendable {
    public let tile: TileModel
    public let title: TextModel

    /// The line under the title, finished, and nil for a header with none.
    public let subtitle: TextModel?

    public let spacing: Double
    public let titleToSubtitle: Double
    public let subtitleLeading: Double

    public init(
        tile: TileModel, title: TextModel, subtitle: TextModel?, spacing: Double, titleToSubtitle: Double,
        subtitleLeading: Double
    ) {
        self.tile = tile
        self.title = title
        self.subtitle = subtitle
        self.spacing = spacing
        self.titleToSubtitle = titleToSubtitle
        self.subtitleLeading = subtitleLeading
    }
}
