// Sources/DesignSystemComponents/MenuModel.swift
import DesignSystem

/// A menu as every platform puts it up: its items in sections, in the order given, with a divider between two sections,
/// and a `heading` over them where it has one. How it opens is the platform's, a long press on what it belongs to, a
/// secondary click, or a press of the button that holds it.
public struct MenuModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// An item of the menu: its title, the line under it where it has one, its icon, whether it destroys something,
    /// which a platform draws as such, whether it can be chosen, whether it is the one a choice among them stands on
    /// now, the keys that choose it, and the action choosing it sends.
    public struct Item: Equatable, Sendable {
        /// The keys of an item on a platform with a keyboard, which shows them beside the item: a key pressed with the
        /// modifiers held, ⇧⌘N as `n` with the shift and command keys. They choose the item where the platform answers
        /// them, as an app's menu bar answers its items' keys with the menu closed; the items of a closed menu in a
        /// window answer none on the Mac, so a platform that should answer them there draws the same menu in its menu
        /// bar (#149's hand check, 2026-10-31). The key is the one its cap names, in lower case, whatever modifier
        /// the shortcut holds.
        public struct Shortcut: Equatable, Sendable {
            /// A key held while the shortcut's key is pressed.
            public enum Modifier: Equatable, Sendable {
                case command, shift
            }

            public let key: Character
            public let modifiers: [Modifier]

            public init(key: Character, modifiers: [Modifier]) {
                self.key = key
                self.modifiers = modifiers
            }
        }

        public let title: String

        /// The line under the title, finished, such as why the item cannot be chosen, and nil for an item with none.
        public let subtitle: String?

        public let icon: DesignSystem.Icon
        public let isDestructive: Bool

        /// Whether the item is shown but cannot be chosen, as Show as's Columns is for a list with one block and no
        /// grouping, which has no columns to show (list screen spec, section 5).
        public let isDisabled: Bool

        /// Whether the item is the choice the menu stands on now, which a platform marks with a check, as Show as's
        /// current layout is (list screen spec, section 5).
        public let isChecked: Bool

        /// The keys that choose the item, and nil for an item with none.
        public let shortcut: Shortcut?

        public let action: Action

        /// An item with no line under its title can be chosen, and is no current choice, unless it says otherwise, so
        /// that the menus that have none of these build their items without naming them.
        public init(
            title: String, subtitle: String? = nil, icon: DesignSystem.Icon, isDestructive: Bool,
            isDisabled: Bool = false, isChecked: Bool = false, shortcut: Shortcut?, action: Action
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.isDestructive = isDestructive
            self.isDisabled = isDisabled
            self.isChecked = isChecked
            self.shortcut = shortcut
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

    /// The words over the items, finished, such as "Show as", and nil for a menu with none: a menu is headed only
    /// where its items stand for one choice among several.
    public let heading: String?

    public let sections: [Section]

    public init(heading: String? = nil, sections: [Section]) {
        self.heading = heading
        self.sections = sections
    }
}
