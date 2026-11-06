// Sources/DesignSystemComponents/SubtaskRowStyle.swift

/// The numbers a `SubtaskRowModel` is drawn with, in points, which a layout holds whole and a builder hands over as one
/// value.
public struct SubtaskRowStyle: Equatable, Sendable {
    public let height: Double

    public init(height: Double) {
        self.height = height
    }
}
