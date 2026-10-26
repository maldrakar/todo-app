// Sources/DesignSystem/Animation.swift

extension DesignSystem {
    /// How a change moves: its curve, how long it runs and how long it waits before it starts, both in seconds. A
    /// platform renders it as its own animation.
    ///
    /// The look's motions are its static members, the canvas's (`Main.dc.html`). Reduce Motion is the views' to
    /// honour: where the setting is on, a view draws the change without its animation.
    public struct Animation: Sendable {
        /// A spring, an ease-in, or the cubic Bézier curve with the control points (x1, y1) and (x2, y2), as CSS's
        /// `cubic-bezier` writes it.
        public enum Curve: Sendable { case spring, easeIn, bezier(x1: Double, y1: Double, x2: Double, y2: Double) }

        public let curve: Curve
        public let duration: Double
        public let delay: Double

        /// A motion starts at once unless it is given a delay.
        private init(curve: Curve, duration: Double, delay: Double = 0) {
            self.curve = curve
            self.duration = duration
            self.delay = delay
        }

        public static let check = Animation(curve: .spring, duration: 0.45)

        /// A done row leaves over 0.32 s ease-in, 0.7 s after it was checked.
        public static let rowLeaves = Animation(curve: .easeIn, duration: 0.32, delay: 0.7)

        /// Push and pop, on the curve (.2, .8, .2, 1).
        public static let pushPop = Animation(curve: .bezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1), duration: 0.32)
        public static let popover = Animation(curve: .spring, duration: 0.2)
        public static let quickEntry = Animation(curve: .spring, duration: 0.42)
    }
}
