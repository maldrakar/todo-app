// Sources/DesignSystemComponents/TagBarStyle.swift

/// The numbers a `TagBarModel` is drawn with, in points, which a layout holds whole and a builder hands over as one
/// value.
public struct TagBarStyle: Equatable, Sendable {
    public let spacing: Double
    public let padding: Double
    public let fadeIn: Double
    public let fadeOut: Double
    public let leadingMargin: Double
    public let trailingMargin: Double

    public init(
        spacing: Double,
        padding: Double,
        fadeIn: Double,
        fadeOut: Double,
        leadingMargin: Double,
        trailingMargin: Double
    ) {
        self.spacing = spacing
        self.padding = padding
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
    }
}
