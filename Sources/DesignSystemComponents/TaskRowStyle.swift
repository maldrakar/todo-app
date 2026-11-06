// Sources/DesignSystemComponents/TaskRowStyle.swift
import DesignSystem

/// The numbers a `TaskRowModel` is drawn with, in points, and the fade of its fresh colour, which a layout holds whole
/// and a builder hands over as one value.
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
        freshAnimation: DesignSystem.Animation
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
    }
}
