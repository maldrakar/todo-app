// Sources/DesignSystemComponents/BarStyle.swift
import DesignSystem

/// The numbers a `BarModel` is drawn with, in points, and its rules and shadow, which a builder hands over as one
/// value.
public struct BarStyle: Equatable, Sendable {
    public let height: Double

    /// The rule along the bar's top edge, across its width, and nil for a bar with none.
    public let rule: LineStyle?

    public let controlHeight: Double
    public let spacing: Double
    public let padding: Double
    public let groupButtonHeight: Double
    public let groupButtonSpacing: Double
    public let groupPadding: Double
    public let groupDividerHeight: Double

    /// The divider between two buttons of a group, whose width is how thick it is.
    public let groupDivider: LineStyle

    public let buttonShadow: DesignSystem.Shadow

    public init(
        height: Double,
        rule: LineStyle?,
        controlHeight: Double,
        spacing: Double,
        padding: Double,
        groupButtonHeight: Double,
        groupButtonSpacing: Double,
        groupPadding: Double,
        groupDividerHeight: Double,
        groupDivider: LineStyle,
        buttonShadow: DesignSystem.Shadow
    ) {
        self.height = height
        self.rule = rule
        self.controlHeight = controlHeight
        self.spacing = spacing
        self.padding = padding
        self.groupButtonHeight = groupButtonHeight
        self.groupButtonSpacing = groupButtonSpacing
        self.groupPadding = groupPadding
        self.groupDividerHeight = groupDividerHeight
        self.groupDivider = groupDivider
        self.buttonShadow = buttonShadow
    }
}
