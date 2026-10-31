// Apps/Apple/Sources/TodoAppleUI/DesignSystem/MenuItems.swift
import DesignSystemComponents
import SwiftUI

/// A menu's items as its model describes them (`MenuModel`): each a button with its title and its icon's symbol,
/// destructive where the model says so, with the keys that choose it where the model gives them, sending its action, in
/// the order given, with a divider between two sections, so the view adds no item, word, glyph or key of its own. What
/// holds the menu puts it up, a row's context menu or a button's `Menu`, and how it opens is the platform's, as are how
/// the keys show beside an item and whether they choose it while its menu is closed.
///
/// `MenuItems` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-30).
struct MenuItems<Action: Equatable & Sendable>: View {
    private let model: MenuModel<Action>
    private let send: (Action) -> Void

    init(_ model: MenuModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        ForEach(model.sections.indices, id: \.self) { section in
            if section > 0 {
                Divider()
            }
            ForEach(model.sections[section].items.indices, id: \.self) { index in
                let item = model.sections[section].items[index]
                let button = Button(
                    item.title, systemImage: Image.systemName(for: item.icon),
                    role: item.isDestructive ? .destructive : nil
                ) {
                    send(item.action)
                }
                #if os(watchOS)
                // The watch has no keyboard, and `keyboardShortcut` is unavailable there (Xcode 27.1's watchOS SDK).
                button
                #else
                button.keyboardShortcut(item.shortcut.map(KeyboardShortcut.init))
                #endif
            }
        }
    }
}
