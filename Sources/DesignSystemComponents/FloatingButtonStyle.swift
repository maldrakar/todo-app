// Sources/DesignSystemComponents/FloatingButtonStyle.swift
import DesignSystem

/// The numbers a `FloatingButtonModel` is drawn with, in points, its fill and its shadow, which a layout holds whole
/// and a builder hands over as one value.
public struct FloatingButtonStyle: Equatable, Sendable {
    public let diameter: Double
    public let fill: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    public init(diameter: Double, fill: DesignSystem.Color, shadow: DesignSystem.Shadow) {
        self.diameter = diameter
        self.fill = fill
        self.shadow = shadow
    }
}
