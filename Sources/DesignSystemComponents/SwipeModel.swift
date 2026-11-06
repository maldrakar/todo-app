// Sources/DesignSystemComponents/SwipeModel.swift
import DesignSystem

/// A row's swipe to its Delete, on a platform with touch (`Phone.dc.html`, the row's swipe): dragged leftward past
/// `threshold`, the row stays moved by `shift`, negative for leftward, sliding there and back on `animation`, and
/// uncovers its button, `buttonWidth` wide, `buttonVerticalInset` in from the row's top and bottom and
/// `buttonTrailingInset` from its trailing edge, with corners of `buttonCornerRadius`, its words on `background`, in
/// points. The drag itself is the platform's, since only the platform has the finger; this is its look and what the
/// button sends. Its numbers are the fields of its `Style`.
public struct SwipeModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let threshold: Double
        public let shift: Double
        public let buttonWidth: Double
        public let buttonVerticalInset: Double
        public let buttonTrailingInset: Double
        public let buttonCornerRadius: Double

        public init(
            threshold: Double,
            shift: Double,
            buttonWidth: Double,
            buttonVerticalInset: Double,
            buttonTrailingInset: Double,
            buttonCornerRadius: Double
        ) {
            self.threshold = threshold
            self.shift = shift
            self.buttonWidth = buttonWidth
            self.buttonVerticalInset = buttonVerticalInset
            self.buttonTrailingInset = buttonTrailingInset
            self.buttonCornerRadius = buttonCornerRadius
        }
    }

    public let style: Style

    /// The button's words, such as "Delete", in their font and colour.
    public let button: TextModel

    public let background: DesignSystem.Color
    public let animation: DesignSystem.Animation

    /// What a tap on the uncovered button sends.
    public let action: Action

    public init(
        style: Style,
        button: TextModel,
        background: DesignSystem.Color,
        animation: DesignSystem.Animation,
        action: Action
    ) {
        self.style = style
        self.button = button
        self.background = background
        self.animation = animation
        self.action = action
    }
}
