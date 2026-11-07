// Sources/DesignSystemComponents/SwipeStyle.swift
import DesignSystem

/// The numbers a `SwipeModel` is drawn with, in points, the button's background and the slide's animation, which a
/// layout holds whole and a builder hands over as one value.
public struct SwipeStyle: Equatable, Sendable {
    public let threshold: Double
    public let shift: Double
    public let buttonWidth: Double
    public let buttonVerticalInset: Double
    public let buttonTrailingInset: Double
    public let buttonCornerRadius: Double
    public let background: DesignSystem.Color
    public let animation: DesignSystem.Animation

    public init(
        threshold: Double,
        shift: Double,
        buttonWidth: Double,
        buttonVerticalInset: Double,
        buttonTrailingInset: Double,
        buttonCornerRadius: Double,
        background: DesignSystem.Color,
        animation: DesignSystem.Animation
    ) {
        self.threshold = threshold
        self.shift = shift
        self.buttonWidth = buttonWidth
        self.buttonVerticalInset = buttonVerticalInset
        self.buttonTrailingInset = buttonTrailingInset
        self.buttonCornerRadius = buttonCornerRadius
        self.background = background
        self.animation = animation
    }
}
