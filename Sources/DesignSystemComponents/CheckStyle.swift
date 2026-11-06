// Sources/DesignSystemComponents/CheckStyle.swift

/// The numbers a `CheckModel` is drawn with, in points, which a layout holds whole and a builder hands over as one
/// value.
public struct CheckStyle: Equatable, Sendable {
    public let diameter: Double
    public let ringWidth: Double
    public let markSize: Double

    /// The canvas strokes the tick 2.8 thick in the 24-unit box it draws it in, which it scales to the mark's size, so
    /// this is that stroke at the mark's size: 1.75 pt for the row's 15 pt mark.
    public let markStrokeWidth: Double

    public let hitWidth: Double
    public let hitHeight: Double

    public init(
        diameter: Double,
        ringWidth: Double,
        markSize: Double,
        markStrokeWidth: Double,
        hitWidth: Double,
        hitHeight: Double
    ) {
        self.diameter = diameter
        self.ringWidth = ringWidth
        self.markSize = markSize
        self.markStrokeWidth = markStrokeWidth
        self.hitWidth = hitWidth
        self.hitHeight = hitHeight
    }
}
