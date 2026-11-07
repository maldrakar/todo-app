// Sources/DesignSystemComponents/TaskRowStyle.swift
import DesignSystem

/// The numbers a `TaskRowModel` is drawn with, in points, the line through its title, how it lifts and a fresh row's
/// colour and fade or its landing spring, and how it leaves, which a builder hands over as one value. The line goes
/// with whether the task is open, so a done row is another instance.
public struct TaskRowStyle: Equatable, Sendable {
    /// How a row looks and moves as its check takes it out of its block (`Phone.dc.html`, `.tt-done` and `.row-leave`):
    /// its title in `titleColor`, struck in `strike`, while its check fills, and then, on `animation`, which holds it
    /// there a moment first, it fades out and sinks `offset`, the rows under it closing up on the same motion. The
    /// module has no done task among its rows by then, so the row keeps this for its last moments on screen itself
    /// (list screen spec, section 3).
    public struct Leaving: Equatable, Sendable {
        public let titleColor: DesignSystem.Color
        public let strike: DesignSystem.Color
        public let offset: Double
        public let animation: DesignSystem.Animation

        public init(
            titleColor: DesignSystem.Color, strike: DesignSystem.Color, offset: Double,
            animation: DesignSystem.Animation
        ) {
            self.titleColor = titleColor
            self.strike = strike
            self.offset = offset
            self.animation = animation
        }
    }

    public let titleToMeta: Double
    public let metaSpacing: Double
    public let metaLineSpacing: Double
    public let verticalPadding: Double
    public let titleLeading: Double
    public let titleTrailing: Double
    public let leading: Double
    public let trailing: Double

    /// The least the row is high: a title on more lines makes it higher.
    public let minimumHeight: Double

    /// The radius of the corners of what the row draws under itself, its fresh colour and the pointer's tint.
    public let cornerRadius: Double
    public let freshAnimation: DesignSystem.Animation

    /// The colour of the line through the title, the canvas's ink 3 through a done task's (`.tt-done`), and nil for a
    /// title with no line through it.
    public let strike: DesignSystem.Color?

    /// How the row looks while it is lifted to be moved, and nil for a row that cannot be.
    public let lift: TaskLiftStyle?

    /// The colour under the row where it was just dropped, which fades out over `freshAnimation` from the moment it
    /// lands, and nil under any other row. The motion is held while the colour is nil too, so the fade does not stop
    /// when the colour goes.
    public let fresh: DesignSystem.Color?

    /// The scale a task lands from after a drop, springing to 1 over `landingAnimation`, and nil under any other
    /// task and under a list's row, which lands by fading `fresh` instead (`Phone.dc.html`, `.card-drop` and its
    /// `cardDrop`, a column's card; `.row-fresh`, a row). A view plays whichever of the two is not nil.
    public let landingScale: Double?

    /// The motion of the landing, held while `landingScale` is nil too, so it does not stop when the scale goes.
    public let landingAnimation: DesignSystem.Animation

    /// The motion the title changes colour on, a checked row's that stays where it is.
    public let titleAnimation: DesignSystem.Animation

    public let leaving: Leaving

    public init(
        titleToMeta: Double,
        metaSpacing: Double,
        metaLineSpacing: Double,
        verticalPadding: Double,
        titleLeading: Double,
        titleTrailing: Double,
        leading: Double,
        trailing: Double,
        minimumHeight: Double,
        cornerRadius: Double,
        freshAnimation: DesignSystem.Animation,
        strike: DesignSystem.Color?,
        lift: TaskLiftStyle?,
        fresh: DesignSystem.Color?,
        landingScale: Double?,
        landingAnimation: DesignSystem.Animation,
        titleAnimation: DesignSystem.Animation,
        leaving: Leaving
    ) {
        self.titleToMeta = titleToMeta
        self.metaSpacing = metaSpacing
        self.metaLineSpacing = metaLineSpacing
        self.verticalPadding = verticalPadding
        self.titleLeading = titleLeading
        self.titleTrailing = titleTrailing
        self.leading = leading
        self.trailing = trailing
        self.minimumHeight = minimumHeight
        self.cornerRadius = cornerRadius
        self.freshAnimation = freshAnimation
        self.strike = strike
        self.lift = lift
        self.fresh = fresh
        self.landingScale = landingScale
        self.landingAnimation = landingAnimation
        self.titleAnimation = titleAnimation
        self.leaving = leaving
    }
}
