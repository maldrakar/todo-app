// Sources/DesignSystemComponents/TextModel.swift
import DesignSystem

/// A text as a component draws it: its words, finished by its caller, in a font and a colour of the design system, so
/// that a view formats nothing and picks neither (ADR-0007, amendment of 2026-10-30).
public struct TextModel: Equatable, Sendable {
    public let text: String
    public let font: DesignSystem.Font
    public let color: DesignSystem.Color

    public init(text: String, font: DesignSystem.Font, color: DesignSystem.Color) {
        self.text = text
        self.font = font
        self.color = color
    }
}
