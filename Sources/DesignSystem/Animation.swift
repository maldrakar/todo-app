// Sources/DesignSystem/Animation.swift

extension DesignSystem {
    /// How a change moves: its curve, how long it runs and how long it waits before it starts, both in seconds. A
    /// platform renders it as its own animation.
    ///
    /// The look's motions are its static members, the canvas's (`Main.dc.html`, `Phone.dc.html`). Reduce Motion is the
    /// views' to honour: where the setting is on, a view draws the change without its animation.
    public struct Animation: Equatable, Sendable {
        /// A spring, an ease-in, or the cubic Bézier curve with the control points (x1, y1) and (x2, y2), as CSS's
        /// `cubic-bezier` writes it.
        public enum Curve: Equatable, Sendable {
            case spring, easeIn, bezier(x1: Double, y1: Double, x2: Double, y2: Double)
        }

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

        /// A done row leaving where a person asked for less motion: after the same wait, over a time too short to see.
        /// A motion of no length took the task away at the tap, the wait and all (the iOS 26.3 simulator, 2026-11-07).
        public static let rowLeavesWithNoMotion = Animation(curve: .easeIn, duration: 0.001, delay: 0.7)

        /// A deleted row leaves as a done row does and at once: the done row's wait is for its check to be read.
        public static let rowDeleted = Animation(curve: .easeIn, duration: 0.32)

        /// Push and pop, on the curve (.2, .8, .2, 1).
        public static let pushPop = Animation(curve: settle, duration: 0.32)
        public static let popover = Animation(curve: .spring, duration: 0.2)
        public static let quickEntry = Animation(curve: .spring, duration: 0.42)

        /// A task's card opening in place of its row, over 0.26 s (`Phone.dc.html`, `xIn`).
        public static let cardOpens = Animation(curve: settle, duration: 0.26)

        /// A card landing where it was dropped, over 0.32 s on the spring the check pops on (`Phone.dc.html`,
        /// `cardDrop`).
        public static let drop = Animation(curve: .spring, duration: 0.32)

        /// A dragged task's slot moving, over 0.3 s on a spring: the mark going from place to place, the rows opening
        /// and closing its gap, and the copy settling into it where the platform's drag does not move it itself, as
        /// the owner's reference moves them (#211).
        public static let slotMoves = Animation(curve: .spring, duration: 0.3)

        /// A row sliding aside for its Delete and back, over 0.25 s (`Phone.dc.html`, the row's `translateX`).
        public static let swipe = Animation(curve: settle, duration: 0.25)

        /// A chevron turning as a block or the Done strip folds or opens, over 0.22 s (`Phone.dc.html`, the chevrons'
        /// `transition`).
        public static let fold = Animation(curve: ease, duration: 0.22)

        /// A dropped row's highlight fading from the fresh colour, over 1.6 s (`Phone.dc.html`, `.row-fresh`).
        public static let fresh = Animation(curve: ease, duration: 1.6)

        /// A check's ring and fill changing colour, over 0.22 s (`Phone.dc.html`, `.cb`'s `transition`).
        public static let checkFills = Animation(curve: ease, duration: 0.22)

        /// A check's mark drawing itself in and out, over 0.26 s, 0.08 s after its colours start (`Phone.dc.html`,
        /// `.cb path`).
        public static let checkMarkDraws = Animation(curve: ease, duration: 0.26, delay: 0.08)

        /// A title changing colour as its task is checked, over 0.25 s (`Phone.dc.html`, `.tt`).
        public static let titleFades = Animation(curve: ease, duration: 0.25)

        /// A tag's chip lighting and going out, over 0.18 s (`Phone.dc.html`, `.tchip .chip`).
        public static let chipToggles = Animation(curve: ease, duration: 0.18)

        /// A dragged card dimming, and a column tinting and ringing under a drag, over 0.15 s (`Phone.dc.html`, `.card`
        /// and `.bcol`).
        public static let dropHighlights = Animation(curve: ease, duration: 0.15)

        /// A control's tint coming and going under the pointer, over 0.12 s (`Mac.dc.html`, `.mc-tap` and `.mc-trow`).
        public static let hoverTints = Animation(curve: ease, duration: 0.12)

        /// A column's card casting its deeper shadow under the pointer and back, over 0.15 s (`Mac.dc.html`, `.card`).
        public static let hoverShadows = Animation(curve: ease, duration: 0.15)

        /// The curve a screen, a card and a row settle on, (.2, .8, .2, 1), quick and then slow.
        private static let settle = Curve.bezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1)

        /// CSS's `ease`, (.25, .1, .25, 1), on which the canvas turns its chevrons, fades a dropped row and runs the
        /// small fades of its colours.
        private static let ease = Curve.bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
    }
}
