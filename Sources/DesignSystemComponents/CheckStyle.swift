// Sources/DesignSystemComponents/CheckStyle.swift
import DesignSystem

/// The numbers a `CheckModel` is drawn with, in points, its colours and its animation, which a builder hands over as
/// one value. The colours are the list's, so a check in another list's colour is another instance.
public struct CheckStyle: Equatable, Sendable {
    public let diameter: Double
    public let ringWidth: Double
    public let markSize: Double

    /// The canvas strokes the tick 2.8 thick in the 24-unit box it draws it in, which it scales to the mark's size, so
    /// this is that stroke at the mark's size: 1.75 pt for the row's 15 pt mark.
    public let markStrokeWidth: Double

    public let hitWidth: Double
    public let hitHeight: Double
    public let animation: DesignSystem.Animation

    /// The ring, the fill and the mark in the colour of the list the task is drawn in.
    public let colors: DesignSystem.Color.Components.Check

    public init(
        diameter: Double,
        ringWidth: Double,
        markSize: Double,
        markStrokeWidth: Double,
        hitWidth: Double,
        hitHeight: Double,
        animation: DesignSystem.Animation,
        colors: DesignSystem.Color.Components.Check
    ) {
        self.diameter = diameter
        self.ringWidth = ringWidth
        self.markSize = markSize
        self.markStrokeWidth = markStrokeWidth
        self.hitWidth = hitWidth
        self.hitHeight = hitHeight
        self.animation = animation
        self.colors = colors
    }
}
