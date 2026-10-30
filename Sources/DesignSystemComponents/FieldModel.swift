// Sources/DesignSystemComponents/FieldModel.swift
import DesignSystem

/// A text field as a component draws it while a name is typed into it: what it holds and what it shows while empty,
/// the font and colour of its text, its background, its sizes and the ring around it, so that a view draws it and
/// decides nothing (ADR-0007, amendment of 2026-10-30).
///
/// It holds no action. What a field sends is its view's to send, as it has always been: the text on every keystroke,
/// Return, Esc and a lost focus, since the action that carries the typed text is made from that text, and a closure
/// that makes it is no value a model can hold (Lists screen plan, Task 8).
public struct FieldModel: Equatable, Sendable {
    /// What the field holds, as the person typed it, down to the spaces at its ends.
    public let text: String

    /// What the field shows while it holds nothing.
    public let placeholder: String

    public let font: DesignSystem.Font

    /// The colour of the text.
    public let color: DesignSystem.Color

    /// The colour under the text, out to the field's rounded edge.
    public let background: DesignSystem.Color

    /// The width, height, room between the edge and the text at either end, and radius of the corners, in points. The
    /// component the field stands in says how it lays the field out by its minimum width.
    public let minimumWidth: Double
    public let height: Double
    public let padding: Double
    public let cornerRadius: Double

    /// The ring around the field, along its rounded edge.
    public let ring: StrokeModel

    public init(
        text: String,
        placeholder: String,
        font: DesignSystem.Font,
        color: DesignSystem.Color,
        background: DesignSystem.Color,
        minimumWidth: Double,
        height: Double,
        padding: Double,
        cornerRadius: Double,
        ring: StrokeModel
    ) {
        self.text = text
        self.placeholder = placeholder
        self.font = font
        self.color = color
        self.background = background
        self.minimumWidth = minimumWidth
        self.height = height
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.ring = ring
    }
}
