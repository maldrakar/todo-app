// Apps/Apple/Sources/TodoAppleUI/Foundations/Motion.swift
import SwiftUI

/// The canvas's motion (`Main.dc.html`). Reduce Motion is the views' to honour: a view reads
/// `accessibilityReduceMotion` and passes `nil` for the animation.
enum Motion {
    static let check = Animation.spring(duration: 0.45)

    /// A done row leaves over 0.32 s ease-in, `rowLeavesAfter` after it was checked.
    static let rowLeaves = Animation.easeIn(duration: 0.32)
    static let rowLeavesAfter = Duration.milliseconds(700)

    /// Push and pop, on the curve (.2, .8, .2, 1).
    static let pushPop = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32)
    static let popover = Animation.spring(duration: 0.2)
    static let quickEntry = Animation.spring(duration: 0.42)
}
