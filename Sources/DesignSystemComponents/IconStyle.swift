// Sources/DesignSystemComponents/IconStyle.swift
import DesignSystem

/// The size in points an `IconModel` is drawn at, which stays as it is at every text size, and its weight and its
/// colour, each a value of the design system, which a builder hands over as one value.
public struct IconStyle: Equatable, Sendable {
    public let size: Double
    public let weight: DesignSystem.Font.Weight
    public let color: DesignSystem.Color

    public init(size: Double, weight: DesignSystem.Font.Weight, color: DesignSystem.Color) {
        self.size = size
        self.weight = weight
        self.color = color
    }
}
