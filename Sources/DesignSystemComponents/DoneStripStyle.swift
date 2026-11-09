// Sources/DesignSystemComponents/DoneStripStyle.swift
import DesignSystem

/// The numbers a `DoneStripModel` is drawn with, in points, and its background, which a layout holds whole and a
/// builder hands over as one value.
public struct DoneStripStyle: Equatable, Sendable {
    /// How the capsule's words bump as they change, a task done or undone (`Phone.dc.html`, `bumpA`): from 1 up to
    /// `scale` by the fraction `peakAt` of `animation`, and back to 1. The canvas plays it as the row has left, and it
    /// plays at the write here, since the module writes on the tap and holds no pause (the controller's ruling on #177,
    /// 2026-11-07).
    public struct Bump: Equatable, Sendable {
        public let scale: Double
        public let peakAt: Double
        public let animation: DesignSystem.Animation

        public init(scale: Double, peakAt: Double, animation: DesignSystem.Animation) {
            self.scale = scale
            self.peakAt = peakAt
            self.animation = animation
        }
    }

    public let height: Double
    public let cornerRadius: Double
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let topMargin: Double
    public let leadingMargin: Double
    public let trailingMargin: Double
    public let background: DesignSystem.Color

    /// How far the rows under the capsule stand below it while the strip is open.
    public let capsuleToRows: Double

    /// How the rows under the capsule come in as the strip opens.
    public let rowsEntrance: EntranceStyle

    public let bump: Bump

    /// The tint over the capsule's fill while the pointer is over it, and nil where there is no pointer to be, the
    /// phone's.
    public let hover: HoverStyle?

    public init(
        height: Double,
        cornerRadius: Double,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        topMargin: Double,
        leadingMargin: Double,
        trailingMargin: Double,
        background: DesignSystem.Color,
        capsuleToRows: Double,
        rowsEntrance: EntranceStyle,
        bump: Bump,
        hover: HoverStyle?
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topMargin = topMargin
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
        self.background = background
        self.capsuleToRows = capsuleToRows
        self.rowsEntrance = rowsEntrance
        self.bump = bump
        self.hover = hover
    }
}
