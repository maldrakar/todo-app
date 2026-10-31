// Sources/DesignSystemComponents/IconModel.swift
import DesignSystem

/// A glyph as a component draws it outside a tile: its icon, its size in points, which stays as it is at every text
/// size, its weight and its colour, each a value of the design system, so that a platform draws it and decides nothing
/// (ADR-0007, amendment of 2026-10-30).
public struct IconModel: Equatable, Sendable {
    public let icon: DesignSystem.Icon
    public let size: Double
    public let weight: DesignSystem.Font.Weight
    public let color: DesignSystem.Color

    public init(icon: DesignSystem.Icon, size: Double, weight: DesignSystem.Font.Weight, color: DesignSystem.Color) {
        self.icon = icon
        self.size = size
        self.weight = weight
        self.color = color
    }
}
