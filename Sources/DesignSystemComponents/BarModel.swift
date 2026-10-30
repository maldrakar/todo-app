// Sources/DesignSystemComponents/BarModel.swift
import DesignSystem

/// A bar of controls as every platform draws it (`Phone.dc.html`, the bar): its items in a row, `spacing` apart and
/// `padding` in from either edge, each `controlHeight` high, in points. A button alone is as wide as it is high and
/// round, and the search field and a group take the room the buttons leave. A group is buttons on one container,
/// `groupPadding` in from its ends, each `groupButtonHeight` high with its glyph `groupButtonSpacing` before its word,
/// sharing the group's width, and between two of them `groupDivider`, `groupDividerHeight` high, which alone separates
/// them. A view switches over `Item`, every case drawn and no `default` (`docs/style.md`, "Views").
public struct BarModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// What stands on the bar: a button, the search field, or buttons grouped on one container.
    public enum Item: Equatable, Sendable {
        case button(ButtonModel<Action>)
        case search(SearchFieldModel)
        case group([ButtonModel<Action>])
    }

    public let items: [Item]
    public let controlHeight: Double
    public let spacing: Double
    public let padding: Double
    public let groupButtonHeight: Double
    public let groupButtonSpacing: Double
    public let groupPadding: Double
    public let groupDividerHeight: Double

    /// The divider between two buttons of a group, whose width is how thick it is.
    public let groupDivider: StrokeModel

    public init(
        items: [Item],
        controlHeight: Double,
        spacing: Double,
        padding: Double,
        groupButtonHeight: Double,
        groupButtonSpacing: Double,
        groupPadding: Double,
        groupDividerHeight: Double,
        groupDivider: StrokeModel
    ) {
        self.items = items
        self.controlHeight = controlHeight
        self.spacing = spacing
        self.padding = padding
        self.groupButtonHeight = groupButtonHeight
        self.groupButtonSpacing = groupButtonSpacing
        self.groupPadding = groupPadding
        self.groupDividerHeight = groupDividerHeight
        self.groupDivider = groupDivider
    }
}
