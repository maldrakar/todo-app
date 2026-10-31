// Sources/DesignSystemComponents/IndentModel.swift

/// How far in each level of a tree stands, from the tree's leading edge: a row of the top level at `start`, and each
/// level below it a `step` further, both in points. A row's tile, the guides down its branch and the slot and the card
/// of a drag are all placed by one indent, so that they line up at every depth (`Phone.dc.html`, `tileLeft`).
public struct IndentModel: Equatable, Sendable {
    public let start: Double
    public let step: Double

    public init(start: Double, step: Double) {
        self.start = start
        self.step = step
    }

    /// Where a row of the depth starts: `start`, and a `step` for each level below the top.
    public func leading(atDepth depth: Int) -> Double {
        start + step * Double(depth)
    }
}
