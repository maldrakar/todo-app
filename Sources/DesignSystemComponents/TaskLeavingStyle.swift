// Sources/DesignSystemComponents/TaskLeavingStyle.swift
import DesignSystem

/// How a task's row or its open card looks and moves as its check takes it out of its block (`Phone.dc.html`,
/// `.tt-done` and `.row-leave`, off one `complete`): its title in `titleColor`, struck in `strike`, while its check
/// fills, and then, on `animation`, which holds it there a moment first, it fades out and sinks `offset`, in points,
/// what stands under it closing up on the same motion. The module has no done task among its rows by then, so the view
/// keeps this for its last moments on screen itself (list screen spec, section 3). A deleted task leaves the same way
/// on `deleteAnimation`, which holds it nowhere, having no check to read (spec section 6). Where a person asked for less
/// motion it leaves on `reducedAnimation` instead, which holds it as long and shows no fade or sinking.
///
/// `TaskLeavingStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
public struct TaskLeavingStyle: Equatable, Sendable {
    public let titleColor: DesignSystem.Color
    public let strike: DesignSystem.Color
    public let offset: Double
    public let animation: DesignSystem.Animation
    public let reducedAnimation: DesignSystem.Animation
    public let deleteAnimation: DesignSystem.Animation

    public init(
        titleColor: DesignSystem.Color, strike: DesignSystem.Color, offset: Double, animation: DesignSystem.Animation,
        reducedAnimation: DesignSystem.Animation, deleteAnimation: DesignSystem.Animation
    ) {
        self.titleColor = titleColor
        self.strike = strike
        self.offset = offset
        self.animation = animation
        self.reducedAnimation = reducedAnimation
        self.deleteAnimation = deleteAnimation
    }
}
