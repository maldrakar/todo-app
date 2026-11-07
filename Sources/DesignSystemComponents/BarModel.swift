// Sources/DesignSystemComponents/BarModel.swift

/// A bar of controls as every platform draws it (`Phone.dc.html`, the bar; `Mac.dc.html`, the bottom of the column):
/// `height` high, under its rule where it has one, its items in a row, centred in its height, `spacing` apart and
/// `padding` in from either edge, each `controlHeight` high, in points. A button or a menu button alone is as wide as
/// it is high and round, and casts `buttonShadow` where it stands on a fill of its own; the search field and a group
/// take the room the buttons leave. A group is buttons on one container, `groupPadding` in from its ends, each
/// `groupButtonHeight` high with its glyph `groupButtonSpacing` before its word, sharing the group's width, and between
/// two of them `groupDivider`, `groupDividerHeight` high, which alone separates them. A view switches over `Item`,
/// every case drawn and no `default` (`docs/style.md`, "Views"). Its numbers, its rules and its shadow are the fields
/// of its `BarStyle`.
public struct BarModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// What stands on the bar: a button, a button that puts a menu up, the search field, or buttons grouped on one
    /// container.
    public enum Item: Equatable, Sendable {
        case button(ButtonModel<Action>)
        case menuButton(MenuButtonModel<Action>)
        case search(SearchFieldModel)
        case group([ButtonModel<Action>])
    }

    public let items: [Item]
    public let style: BarStyle

    public init(items: [Item], style: BarStyle) {
        self.items = items
        self.style = style
    }
}
