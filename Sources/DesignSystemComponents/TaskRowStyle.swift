// Sources/DesignSystemComponents/TaskRowStyle.swift
import DesignSystem

/// The numbers a `TaskRowModel` is drawn with, in points, the line through its title, how it lifts and a fresh row's
/// colour and fade or its landing spring, and how it leaves, which a builder hands over as one value. The line goes
/// with whether the task is open, so a done row is another instance.
public struct TaskRowStyle: Equatable, Sendable {
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

    /// The colour of the line through the title, the canvas's ink 3 through a done task's (`.tt-done`), and nil for a
    /// title with no line through it.
    public let strike: DesignSystem.Color?

    /// How the row looks while it is lifted to be moved, and nil for a row that cannot be.
    public let lift: TaskLiftStyle?

    /// The colour under the row where it was just dropped, which fades out over `landingAnimation` from the moment it
    /// lands, and nil under any other row.
    public let fresh: DesignSystem.Color?

    /// The scale a task lands from after a drop, springing to 1 over `landingAnimation`, and nil under any other
    /// task and under a list's row, which lands by fading `fresh` instead (`Phone.dc.html`, `.card-drop` and its
    /// `cardDrop`, a column's card; `.row-fresh`, a row). A view plays whichever of the two is not nil.
    public let landingScale: Double?

    /// The motion of the landing, a list's row's fade or a column's card's spring, held while `fresh` and
    /// `landingScale` are nil too, so that it does not stop when they go.
    public let landingAnimation: DesignSystem.Animation

    /// The motion the title changes colour on, a checked row's that stays where it is.
    public let titleAnimation: DesignSystem.Animation

    public let leaving: TaskLeavingStyle

    /// What the row stands on, which the system's menu lifts with it and which a swipe slides off what stands behind
    /// it, and nil where it stands on something else: a column's card has its surface.
    public let ground: DesignSystem.Color?

    /// Whether the meta line stands on the title's line, after the title, `titleToMeta` from it, the title keeping to
    /// one line and the items not wrapping (`Mac.dc.html`, the row), and not under it, where it wraps
    /// (`Phone.dc.html`).
    public let metaTrailing: Bool

    /// The tint over the row while the pointer is over it, and nil where there is no pointer to be, the phone's, and
    /// for a column's card, which casts a shadow instead (`ColumnStyle.cardHover`).
    public let hover: HoverStyle?

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
        strike: DesignSystem.Color?,
        lift: TaskLiftStyle?,
        fresh: DesignSystem.Color?,
        landingScale: Double?,
        landingAnimation: DesignSystem.Animation,
        titleAnimation: DesignSystem.Animation,
        leaving: TaskLeavingStyle,
        ground: DesignSystem.Color?,
        metaTrailing: Bool,
        hover: HoverStyle?
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
        self.strike = strike
        self.lift = lift
        self.fresh = fresh
        self.landingScale = landingScale
        self.landingAnimation = landingAnimation
        self.titleAnimation = titleAnimation
        self.leaving = leaving
        self.ground = ground
        self.metaTrailing = metaTrailing
        self.hover = hover
    }
}
