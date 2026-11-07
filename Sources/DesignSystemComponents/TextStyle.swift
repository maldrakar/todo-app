// Sources/DesignSystemComponents/TextStyle.swift
import DesignSystem

/// The font and the colour a `TextModel` is drawn in, each a value of the design system, which a builder hands over as
/// one value.
public struct TextStyle: Equatable, Sendable {
    public let font: DesignSystem.Font
    public let color: DesignSystem.Color

    public init(font: DesignSystem.Font, color: DesignSystem.Color) {
        self.font = font
        self.color = color
    }
}
