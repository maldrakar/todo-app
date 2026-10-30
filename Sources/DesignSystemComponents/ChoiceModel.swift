// Sources/DesignSystemComponents/ChoiceModel.swift

/// One choice of a dialog, a button its platform draws in it: its title, whether it destroys something, which a
/// platform draws as such, and the action choosing it sends.
public struct ChoiceModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let title: String
    public let isDestructive: Bool
    public let action: Action

    public init(title: String, isDestructive: Bool, action: Action) {
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}
