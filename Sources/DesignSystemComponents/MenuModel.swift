// Sources/DesignSystemComponents/MenuModel.swift
import DesignSystem

/// A menu as every platform puts it up: its items in sections, in the order given, with a divider between two sections.
/// How it opens is the platform's, a long press on what it belongs to, a secondary click, or a press of the button that
/// holds it.
public struct MenuModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// An item of the menu: its title, its icon, whether it destroys something, which a platform draws as such, and the
    /// action choosing it sends.
    public struct Item: Equatable, Sendable {
        public let title: String
        public let icon: DesignSystem.Icon
        public let isDestructive: Bool
        public let action: Action

        public init(title: String, icon: DesignSystem.Icon, isDestructive: Bool, action: Action) {
            self.title = title
            self.icon = icon
            self.isDestructive = isDestructive
            self.action = action
        }
    }

    /// Items that stand together, set off from the next section by a divider.
    public struct Section: Equatable, Sendable {
        public let items: [Item]

        public init(items: [Item]) {
            self.items = items
        }
    }

    public let sections: [Section]

    public init(sections: [Section]) {
        self.sections = sections
    }
}
