// Sources/DesignSystemComponents/TextFieldModel.swift

/// A text field as a component draws it while a name is typed into it: what it holds and what it shows while empty,
/// the font and colour of its text, its background, its sizes and the ring around it, so that a view draws it and
/// decides nothing (ADR-0007, amendment of 2026-10-30), and the three actions it sends that carry no value: Return,
/// Esc and a lost focus. Its font, its colours, its sizes and its ring are the fields of its `FieldStyle`.
///
/// The action that carries the typed text is not here: it is made from that text, and the function that makes it is
/// no value a model can hold, since a function has no `==`. A field's view takes that function beside the model and
/// sends what it makes on every keystroke (the owner, on #163's thread r4431104202).
public struct TextFieldModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// What the field holds, as the person typed it, down to the spaces at its ends.
    public let text: String

    /// What the field shows while it holds nothing.
    public let placeholder: String

    public let style: FieldStyle

    /// What Return in the field sends.
    public let submitted: Action

    /// What Esc in the field sends.
    public let cancelled: Action

    /// What the field sends when it loses focus, because the person went somewhere else on screen.
    public let focusLost: Action

    public init(
        text: String,
        placeholder: String,
        style: FieldStyle,
        submitted: Action,
        cancelled: Action,
        focusLost: Action
    ) {
        self.text = text
        self.placeholder = placeholder
        self.style = style
        self.submitted = submitted
        self.cancelled = cancelled
        self.focusLost = focusLost
    }
}
