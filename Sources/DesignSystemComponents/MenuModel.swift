// Sources/DesignSystemComponents/MenuModel.swift
import DesignSystem

/// A menu as every platform puts it up: its items in sections, in the order given, with a divider between two sections.
/// How it opens is the platform's, a long press on what it belongs to, a secondary click, or a press of the button that
/// holds it.
public struct MenuModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// An item of the menu: its title, its icon, whether it destroys something, which a platform draws as such, the
    /// keys that choose it, and the action choosing it sends.
    public struct Item: Equatable, Sendable {
        /// The keys that choose an item from anywhere in its window on a platform with a keyboard, which shows them
        /// beside the item: a key pressed with the modifiers held, ⇧⌘N as `n` with the shift and command keys. The key
        /// is the one its cap names, in lower case, whatever modifier the shortcut holds.
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
        public let icon: DesignSystem.Icon
        public let isDestructive: Bool

        /// The keys that choose the item, and nil for an item with none.
        public let shortcut: Shortcut?

        public let action: Action

        public init(title: String, icon: DesignSystem.Icon, isDestructive: Bool, shortcut: Shortcut?, action: Action) {
            self.title = title
            self.icon = icon
            self.isDestructive = isDestructive
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

    public let sections: [Section]

    public init(sections: [Section]) {
        self.sections = sections
    }
}
