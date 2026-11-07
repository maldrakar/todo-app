// Sources/DesignSystemComponents/FieldStyle.swift
import DesignSystem

/// The font, the colours and the numbers a `TextFieldModel` is drawn with, in points, and its ring, which a builder
/// hands over as one value.
public struct FieldStyle: Equatable, Sendable {
    public let font: DesignSystem.Font

    /// The colour of the text.
    public let color: DesignSystem.Color

    /// The colour of what the field shows while it holds nothing.
    public let placeholder: DesignSystem.Color

    /// The colour under the text, out to the field's rounded edge.
    public let background: DesignSystem.Color

    /// The width, height, room between the edge and the text at either end, and radius of the corners, in points. The
    /// component the field stands in says how it lays the field out by its minimum width.
    public let minimumWidth: Double
    public let height: Double
    public let padding: Double
    public let cornerRadius: Double

    /// The ring around the field, along its rounded edge.
    public let ring: LineStyle

    public init(
        font: DesignSystem.Font,
        color: DesignSystem.Color,
        placeholder: DesignSystem.Color,
        background: DesignSystem.Color,
        minimumWidth: Double,
        height: Double,
        padding: Double,
        cornerRadius: Double,
        ring: LineStyle
    ) {
        self.font = font
        self.color = color
        self.placeholder = placeholder
        self.background = background
        self.minimumWidth = minimumWidth
        self.height = height
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.ring = ring
    }
}
