// Sources/DesignSystemComponents/FloatingButtonStyle.swift

/// The numbers a `FloatingButtonModel` is drawn with, in points, which a layout holds whole and a builder hands over as
/// one value.
public struct FloatingButtonStyle: Equatable, Sendable {
    public let diameter: Double

    public init(diameter: Double) {
        self.diameter = diameter
    }
}
