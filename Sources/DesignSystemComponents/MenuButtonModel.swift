// Sources/DesignSystemComponents/MenuButtonModel.swift

/// A pull-down button as every platform draws it: its label, and the menu a press puts up, as UIKit's `UIButton.menu`
/// and SwiftUI's `Menu` put one up. It knows no screen: which of a screen's controls is one is the screen's to say.
public struct MenuButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let label: ButtonLabelModel
    public let menu: MenuModel<Action>

    public init(label: ButtonLabelModel, menu: MenuModel<Action>) {
        self.label = label
        self.menu = menu
    }
}
