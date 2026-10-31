// Sources/DesignSystemComponents/ButtonModel.swift

/// A button as every platform draws it: its label, and the action a press sends. A button that puts a menu up is a
/// `MenuButtonModel`.
public struct ButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let label: ButtonLabelModel
    public let action: Action

    public init(label: ButtonLabelModel, action: Action) {
        self.label = label
        self.action = action
    }
}
