// Apps/Apple/Sources/TodoAppleUI/DesignSystem/KeyboardShortcut+DesignSystemComponents.swift
#if !os(watchOS)
// The watch has no keyboard, and `KeyboardShortcut` is unavailable there (Xcode 27.1's watchOS SDK).
import DesignSystemComponents
import SwiftUI

extension KeyboardShortcut {
    /// The keys that choose a menu's item as its model gives them (`MenuModel.Item.Shortcut`): the key its cap names
    /// with the modifiers held.
    init<Action>(_ shortcut: MenuModel<Action>.Item.Shortcut) {
        self.init(
            KeyEquivalent(shortcut.key),
            modifiers: shortcut.modifiers.reduce(into: EventModifiers()) { $0.insert(EventModifiers($1)) }
        )
    }
}

extension EventModifiers {
    /// A modifier of a menu item's keys as SwiftUI's. The `switch` names every case with no `default`, so a modifier
    /// added to the model stops this compiling until it is drawn.
    fileprivate init<Action>(_ modifier: MenuModel<Action>.Item.Shortcut.Modifier) {
        self = switch modifier {
        case .command: .command
        case .shift: .shift
        }
    }
}
#endif
