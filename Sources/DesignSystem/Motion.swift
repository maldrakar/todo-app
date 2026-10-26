// Sources/DesignSystem/Motion.swift

extension DesignSystem {
    /// How a change moves, with its duration in seconds: a spring, an ease-in, or the cubic Bézier curve with the
    /// control points (x1, y1) and (x2, y2), as CSS's `cubic-bezier` writes it. A platform renders it as its own
    /// animation.
    public enum Animation: Sendable {
        case spring(duration: Double)
        case easeIn(duration: Double)
        case curve(x1: Double, y1: Double, x2: Double, y2: Double, duration: Double)
    }

    /// The canvas's motion (`Main.dc.html`). Reduce Motion is the views' to honour: where the setting is on, a view
    /// draws the change without its animation.
    public struct Motion: Sendable {
        public let check = Animation.spring(duration: 0.45)

        /// A done row leaves over 0.32 s ease-in, `rowLeavesAfter` after it was checked.
        public let rowLeaves = Animation.easeIn(duration: 0.32)
        public let rowLeavesAfter = Duration.milliseconds(700)

        /// Push and pop, on the curve (.2, .8, .2, 1).
        public let pushPop = Animation.curve(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1, duration: 0.32)
        public let popover = Animation.spring(duration: 0.2)
        public let quickEntry = Animation.spring(duration: 0.42)
    }
}
