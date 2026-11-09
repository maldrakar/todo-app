// Sources/DesignSystemComponents/SwipeModel.swift
import DesignSystem

/// A row's swipe to its Delete, on a platform with touch (`Phone.dc.html`, the row's swipe): dragged leftward past
/// `threshold`, the row stays moved by `shift`, negative for leftward, sliding there and back on `animation`, and
/// uncovers its button, `buttonWidth` wide, `buttonVerticalInset` in from the row's top and bottom and
/// `buttonTrailingInset` from its trailing edge, with corners of `buttonCornerRadius`, its words on `background`, in
/// points. The drag itself is the platform's, since only the platform has the finger; this is its look and what the
/// button sends and reads aloud. Its numbers, its `background` and its `animation` are the fields of its `SwipeStyle`.
public struct SwipeModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let style: SwipeStyle

    /// The button's words, such as "Delete", in their font and colour.
    public let button: TextModel

    /// The words the button reads aloud, which name what it deletes, such as "Delete Buy milk": a text, since the
    /// platform finds in the button's own words only "Delete".
    public let accessibilityLabel: String

    /// What a tap on the uncovered button sends.
    public let action: Action

    public init(
        style: SwipeStyle,
        button: TextModel,
        accessibilityLabel: String,
        action: Action
    ) {
        self.style = style
        self.button = button
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
