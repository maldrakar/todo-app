// Apps/Apple/Sources/TodoAppleUI/DesignSystem/UIMenu+DesignSystemComponents.swift
// iOS alone: a menu UIKit puts up, a row's on the list screen (`RowSystemDrag`), which the Mac and the watch do not
// have.
#if os(iOS)
import DesignSystemComponents
import SwiftUI
import UIKit

extension UIMenu {
    /// A menu as its model describes it (`MenuModel`), as `MenuItems` draws one in SwiftUI: under its heading where it
    /// has one, its items in order, each section set off from the next, each item with its title, the line under it
    /// where the model gives one and its icon's symbol, destructive where the model says so, shown but not to be chosen
    /// where it is disabled, marked with the menu's check where the choice stands on it, and sending its action. A
    /// context menu shows no keys, so an item's shortcut is left to the menus that do.
    convenience init<Action>(_ model: MenuModel<Action>, send: @escaping (Action) -> Void) {
        let sections = model.sections.map { section in
            UIMenu(options: .displayInline, children: section.items.map { item in
                var attributes: UIMenuElement.Attributes = []
                if item.isDestructive { attributes.insert(.destructive) }
                if item.isDisabled { attributes.insert(.disabled) }
                return UIAction(
                    title: item.title, subtitle: item.subtitle,
                    image: UIImage(systemName: Image.systemName(for: item.icon)), attributes: attributes,
                    state: item.isChecked ? .on : .off
                ) { _ in send(item.action) }
            })
        }
        self.init(title: model.heading ?? "", children: sections)
    }
}
#endif
