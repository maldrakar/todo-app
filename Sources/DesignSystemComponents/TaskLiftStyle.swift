// Sources/DesignSystemComponents/TaskLiftStyle.swift
import DesignSystem

/// How a task looks while it is lifted to be moved (`Phone.dc.html`, `.tlift`): grown to `scale` and on `background`
/// with corners of `cornerRadius`, casting `shadow`, and dimmed to `opacity` where it is dragged from; how its slot moves,
/// and the impact felt as it is lifted and as it lands, on a device that plays one (#211). The lift itself,
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

    /// The motion its slot moves on: the mark going from place to place, the rows opening and closing its gap and
    /// closing up where it is let go, and its copy settling into its place where the platform's drag does not move the
    /// copy itself.
    public let slotAnimation: DesignSystem.Animation

    /// What is felt as it is lifted and as it lands, where a drag lands it.
    public let impact: DesignSystem.Impact

    public init(
        scale: Double,
        opacity: Double,
        cornerRadius: Double,
        background: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        dimAnimation: DesignSystem.Animation,
        slotAnimation: DesignSystem.Animation,
        impact: DesignSystem.Impact
    ) {
        self.scale = scale
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.background = background
        self.shadow = shadow
        self.dimAnimation = dimAnimation
        self.slotAnimation = slotAnimation
        self.impact = impact
    }
}
