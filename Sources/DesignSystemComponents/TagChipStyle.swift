// Sources/DesignSystemComponents/TagChipStyle.swift

/// The numbers a `TagChipModel` is drawn with, in points, which a layout holds whole and a builder hands over as one
/// value.
public struct TagChipStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let spacing: Double
    public let hitHeight: Double

    public init(
        height: Double,
        cornerRadius: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        spacing: Double,
        hitHeight: Double
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.spacing = spacing
        self.hitHeight = hitHeight
    }
}
