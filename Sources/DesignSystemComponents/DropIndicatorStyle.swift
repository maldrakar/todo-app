// Sources/DesignSystemComponents/DropIndicatorStyle.swift
import DesignSystem

/// The Finder's mark of the place where a lifted row would land, between two rows or into a parent alike: it opens a
/// gap `height` high between the rows, in which, centred in its height, run a line of `line`, from `lineOffset` from
/// the edge the mark is placed from to `trailingGap` short of the right edge of the rows on screen, its ends rounded by
/// `lineCornerRadius`, and a circle `circleDiameter` across, its leading edge `circleOffset` from that edge, ringed
/// with `circleRing` and filled with `circleFill`. An offset is after the edge where it is positive and before it where
/// it is negative, all in points. The edge is its view's: the tile of the drop's depth in a tree (`DragStyle`, the
/// sidebar's drag in `Mac.dc.html`), the rows' leading edge in a list of tasks (`TaskLiftStyle`, the drop's slot in
/// `Phone.dc.html`).
public struct DropIndicatorStyle: Equatable, Sendable {
    public let height: Double
    public let line: LineStyle
    public let lineOffset: Double
    public let lineCornerRadius: Double
    public let trailingGap: Double
    public let circleDiameter: Double
    public let circleOffset: Double
    public let circleRing: LineStyle
    public let circleFill: DesignSystem.Color

    public init(
        height: Double,
        line: LineStyle,
        lineOffset: Double,
        lineCornerRadius: Double,
        trailingGap: Double,
        circleDiameter: Double,
        circleOffset: Double,
        circleRing: LineStyle,
        circleFill: DesignSystem.Color
    ) {
        self.height = height
        self.line = line
        self.lineOffset = lineOffset
        self.lineCornerRadius = lineCornerRadius
        self.trailingGap = trailingGap
        self.circleDiameter = circleDiameter
        self.circleOffset = circleOffset
        self.circleRing = circleRing
        self.circleFill = circleFill
    }
}
