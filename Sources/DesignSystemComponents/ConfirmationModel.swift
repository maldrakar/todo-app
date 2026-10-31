// Sources/DesignSystemComponents/ConfirmationModel.swift

/// The question a platform puts up before something that cannot be undone, as an alert on Apple's: its title and its
/// message, finished, and its two choices, the one that does it and the one that does not. Every way the platform has
/// of dismissing it is its `cancel`.
public struct ConfirmationModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirm: ChoiceModel<Action>
    public let cancel: ChoiceModel<Action>

    public init(title: String, message: String, confirm: ChoiceModel<Action>, cancel: ChoiceModel<Action>) {
        self.title = title
        self.message = message
        self.confirm = confirm
        self.cancel = cancel
    }
}
