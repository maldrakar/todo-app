// Sources/DesignSystemComponents/TaskRowStyle.swift
import DesignSystem

/// The numbers a `TaskRowModel` is drawn with, in points, the line through its title, how it lifts and a fresh row's
/// colour and fade, which a builder hands over as one value. The line goes with whether the task is open, so a done row
/// is another instance.
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
    public let freshAnimation: DesignSystem.Animation

    /// The colour of the line through the title, the canvas's ink 3 through a done task's (`.tt-done`), and nil for a
    /// title with no line through it.
    public let strike: DesignSystem.Color?

    /// How the row looks while it is lifted to be moved, and nil for a row that cannot be.
    public let lift: TaskLiftModel?

    /// The colour under the row where it was just dropped, which fades out over `freshAnimation` from the moment it
    /// lands, and nil under any other row. The motion is held while the colour is nil too, so the fade does not stop
    /// when the colour goes.
    public let fresh: DesignSystem.Color?

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
        lift: TaskLiftModel?,
        fresh: DesignSystem.Color?
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
    }
}
