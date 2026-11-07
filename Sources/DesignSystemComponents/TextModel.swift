// Sources/DesignSystemComponents/TextModel.swift

/// A text as a component draws it: its words, finished by its caller, in a font and a colour of the design system, so
/// that a view formats nothing and picks neither (ADR-0007, amendment of 2026-10-30). Its font and its colour are the
/// fields of its `TextStyle`.
public struct TextModel: Equatable, Sendable {
    public let text: String
    public let style: TextStyle

    public init(text: String, style: TextStyle) {
        self.text = text
        self.style = style
    }
}
