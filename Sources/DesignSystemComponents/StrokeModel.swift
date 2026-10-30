// Sources/DesignSystemComponents/StrokeModel.swift
import DesignSystem

/// A line as a component draws it, a rule or an edge: its colour, its width, which for a rule is how thick it is, and
/// its dash, the lengths of a dash and the gap after it in turn, as CSS's `stroke-dasharray` and SwiftUI's `dash` list
/// them, and empty for a solid line, all in points.
public struct StrokeModel: Equatable, Sendable {
    public let color: DesignSystem.Color
    public let width: Double
    public let dash: [Double]

    public init(color: DesignSystem.Color, width: Double, dash: [Double]) {
        self.color = color
        self.width = width
        self.dash = dash
    }
}
