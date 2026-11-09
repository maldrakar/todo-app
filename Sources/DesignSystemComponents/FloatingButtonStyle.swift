// Sources/DesignSystemComponents/FloatingButtonStyle.swift
import DesignSystem

/// The numbers a `FloatingButtonModel` is drawn with, in points, its fill and its shadow, which a layout holds whole
/// and a builder hands over as one value: the button stands `trailingMargin` in from the screen's right edge and
/// `bottomMargin` above its bottom edge.
public struct FloatingButtonStyle: Equatable, Sendable {
    public let diameter: Double
    public let fill: DesignSystem.Color
    public let shadow: DesignSystem.Shadow
    public let trailingMargin: Double
    public let bottomMargin: Double

    public init(
        diameter: Double,
        fill: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        trailingMargin: Double,
        bottomMargin: Double
    ) {
        self.diameter = diameter
        self.fill = fill
        self.shadow = shadow
        self.trailingMargin = trailingMargin
        self.bottomMargin = bottomMargin
    }
}
