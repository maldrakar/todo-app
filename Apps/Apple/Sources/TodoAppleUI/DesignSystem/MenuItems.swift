// Apps/Apple/Sources/TodoAppleUI/DesignSystem/MenuItems.swift
import DesignSystemComponents
import SwiftUI

/// A menu's items as its model describes them (`MenuModel`), under its heading where it has one: each a button with its
/// title, the line under it where the model gives one, and its icon's symbol, destructive where the model says so,
/// shown but not to be chosen where it is disabled, with the keys that choose it where the model gives them, sending
/// its action, in the order given, with a divider between two sections, so the view adds no item, word, glyph or key of
/// its own. The item the choice stands on is a toggle, which is what a menu marks with its own check, and choosing it
/// sends its action as a button's does. The line under the title is the button's second view after its label, which a
/// menu draws under the title. What holds the menu puts it up, a row's context menu or a button's `Menu`, and how it
/// opens is the platform's, as are how the keys show beside an item and whether they choose it while its menu is
/// closed.
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
        if let heading = model.heading {
            Section(heading) { sections }
        } else {
            sections
        }
    }

    private var sections: some View {
        ForEach(model.sections.indices, id: \.self) { section in
            if section > 0 {
                Divider()
            }
            ForEach(model.sections[section].items.indices, id: \.self) { index in
                let item = model.sections[section].items[index]
                #if os(watchOS)
                // The watch has no keyboard, and `keyboardShortcut` is unavailable there (Xcode 27.1's watchOS SDK).
                control(item)
                #else
                control(item).keyboardShortcut(item.shortcut.map(KeyboardShortcut.init))
                #endif
            }
        }
    }

    /// An item as a button, or as a toggle where the choice stands on it.
    @ViewBuilder private func control(_ item: MenuModel<Action>.Item) -> some View {
        if item.isChecked {
            Toggle(isOn: Binding(get: { true }, set: { _ in send(item.action) })) { label(item) }
                .disabled(item.isDisabled)
        } else {
            Button(role: item.isDestructive ? .destructive : nil) {
                send(item.action)
            } label: {
                label(item)
            }
            .disabled(item.isDisabled)
        }
    }

    @ViewBuilder private func label(_ item: MenuModel<Action>.Item) -> some View {
        Label {
            Text(item.title)
        } icon: {
            Image(item.icon)
        }
        if let subtitle = item.subtitle {
            Text(subtitle)
        }
    }
}
