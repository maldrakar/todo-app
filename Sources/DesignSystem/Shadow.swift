// Sources/DesignSystem/Shadow.swift

extension DesignSystem {
    /// A shadow as the look casts it: black at an opacity, blurred over a radius and dropped by `y`, both in points. A
    /// platform renders it as its own shadow.
    ///
    /// The look's shadows are its static members. The glass under a bar's controls is the platform's, its shadow with
    /// it, so that shadow is not among them (Lists screen plan, Task 8).
    public struct Shadow: Equatable, Sendable {
        public let opacity: Double
        public let radius: Double
        public let y: Double

        private init(opacity: Double, radius: Double, y: Double) {
            self.opacity = opacity
            self.radius = radius
            self.y = y
        }

        /// What a row casts while the drag carries it: 22 %, 18 and 10, the large soft shadow under the canvas's card
        /// (`Phone.dc.html`, the drag's card) as Task 7 drew it.
        public static let lifted = Shadow(opacity: 0.22, radius: 18, y: 10)

        /// What a control raised off what it stands on casts: 12 %, 12 and 5, the canvas's small shadow (`Mac.dc.html`
        /// and `Phone.dc.html`, `--shadow`) as Task 7 drew it under the bar's controls.
        public static let raised = Shadow(opacity: 0.12, radius: 12, y: 5)
    }
}
