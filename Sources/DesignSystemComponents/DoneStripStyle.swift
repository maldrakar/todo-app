// Sources/DesignSystemComponents/DoneStripStyle.swift

/// The numbers a `DoneStripModel` is drawn with, in points, which a layout holds whole and a builder hands over as one
/// value.
public struct DoneStripStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let topMargin: Double
    public let leadingMargin: Double
    public let trailingMargin: Double

    public init(
        height: Double,
        cornerRadius: Double,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        topMargin: Double,
        leadingMargin: Double,
        trailingMargin: Double
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topMargin = topMargin
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
    }
}
