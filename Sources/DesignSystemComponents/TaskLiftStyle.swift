// Sources/DesignSystemComponents/TaskLiftStyle.swift
import DesignSystem

/// How a task looks while it is lifted to be moved (`Phone.dc.html`, `.tlift`): grown to `scale` and on `background`
/// with corners of `cornerRadius`, casting `shadow`, and dimmed to `opacity` where it is dragged from. The lift itself,
/// which task is lifted and where it would land, is the platform's, since only the platform has the finger or the
/// pointer; this is its look, as `DragStyle` is a tree's. The mark of where it would land is its block's
/// (`TaskList.Model.Block`).
public struct TaskLiftStyle: Equatable, Sendable {
    public let scale: Double

    /// How opaque the task stands where it is dragged from, from 0 to 1, as the system's copy of it moves: 0.35, a row
    /// and a column's card alike (`Phone.dc.html`, the dragged card's `opacity`; the controller's ruling on #177,
    /// 2026-11-07, since a row at full strength under its copy reads as two rows).
    public let opacity: Double

    public let cornerRadius: Double
    public let background: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    /// The motion `opacity` comes and goes on where the task is dragged from.
    public let dimAnimation: DesignSystem.Animation

    public init(
        scale: Double,
        opacity: Double,
        cornerRadius: Double,
        background: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        dimAnimation: DesignSystem.Animation
    ) {
        self.scale = scale
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.background = background
        self.shadow = shadow
        self.dimAnimation = dimAnimation
    }
}
