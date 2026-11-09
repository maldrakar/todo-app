// Sources/DesignSystemComponents/CheckStyle.swift
import DesignSystem

/// The numbers a `CheckModel` is drawn with, in points, its colours and its motions, which a builder hands over as one
/// value. The colours are the list's, so a check in another list's colour is another instance.
public struct CheckStyle: Equatable, Sendable {
    /// How a check pops as it is checked, the scale it passes through over its `animation` (`Phone.dc.html`, `cbPop`):
    /// from 1 down to `dipScale` by the fraction `dipAt` of the motion, up to `peakScale` by `peakAt`, and back to 1.
    /// SwiftUI's spring goes straight to its end and has no dip, so the shape is the look's.
    public struct Pop: Equatable, Sendable {
        public let dipScale: Double
        public let dipAt: Double
        public let peakScale: Double
        public let peakAt: Double

        public init(dipScale: Double, dipAt: Double, peakScale: Double, peakAt: Double) {
            self.dipScale = dipScale
            self.dipAt = dipAt
            self.peakScale = peakScale
            self.peakAt = peakAt
        }
    }

    /// The tick a check draws, a line through `points` in a box `box` units on a side, which a platform scales to the
    /// style's `markSize`, its ends and its corner round where `isRound` says so: the canvas's own stroke and no glyph,
    /// so that it can draw itself in.
    public struct Mark: Equatable, Sendable {
        public struct Point: Equatable, Sendable {
            public let x: Double
            public let y: Double

            public init(x: Double, y: Double) {
                self.x = x
                self.y = y
            }
        }

        public let box: Double
        public let points: [Point]
        public let isRound: Bool

        public init(box: Double, points: [Point], isRound: Bool) {
            self.box = box
            self.points = points
            self.isRound = isRound
        }
    }

    public let diameter: Double
    public let ringWidth: Double
    public let markSize: Double

    /// The canvas strokes the tick 2.8 thick in the 24-unit box it draws it in, which it scales to the mark's size, so
    /// this is that stroke at the mark's size: 1.75 pt for the row's 15 pt mark.
    public let markStrokeWidth: Double

    public let hitWidth: Double
    public let hitHeight: Double

    /// The motion the check pops on as it is checked.
    public let animation: DesignSystem.Animation

    /// The motion its ring and its fill change colour on, as it fills and as it empties.
    public let fillAnimation: DesignSystem.Animation

    /// The motion its mark draws itself on, in and out.
    public let markAnimation: DesignSystem.Animation

    public let pop: Pop
    public let mark: Mark

    /// The ring, the fill and the mark in the colour of the list the task is drawn in.
    public let colors: DesignSystem.Color.Components.Check

    public init(
        diameter: Double,
        ringWidth: Double,
        markSize: Double,
        markStrokeWidth: Double,
        hitWidth: Double,
        hitHeight: Double,
        animation: DesignSystem.Animation,
        fillAnimation: DesignSystem.Animation,
        markAnimation: DesignSystem.Animation,
        pop: Pop,
        mark: Mark,
        colors: DesignSystem.Color.Components.Check
    ) {
        self.diameter = diameter
        self.ringWidth = ringWidth
        self.markSize = markSize
        self.markStrokeWidth = markStrokeWidth
        self.hitWidth = hitWidth
        self.hitHeight = hitHeight
        self.animation = animation
        self.fillAnimation = fillAnimation
        self.markAnimation = markAnimation
        self.pop = pop
        self.mark = mark
        self.colors = colors
    }
}
